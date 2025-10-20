# app/routers/viajes.py
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
from typing import List, Optional
from datetime import datetime

from .. import models, schemas
from ..deps import get_db
from ..auth_deps import get_current_claims, require_role
from random import choice

router = APIRouter(prefix="/viajes", tags=["viajes"])


@router.post("", response_model=schemas.ViajeOut, status_code=status.HTTP_201_CREATED)
def crear_viaje(
    body: schemas.ViajeCreateIn,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Crea un nuevo viaje y lo asigna automáticamente a un conductor disponible.
    - Supervisores (3) y Admins (4) pueden crear para cualquier usuario de su hotel
    - Usuarios (1) solo pueden crear para sí mismos
    """
    user_id = int(claims["sub"])
    role = int(claims.get("role", 0))
    me = db.query(models.Usuario).get(user_id)
    
    if not me or not me.id_hotel:
        raise HTTPException(403, "Usuario sin hotel asignado")
    
    hotel_id = me.id_hotel
    
    # Validar ruta
    ruta = db.query(models.Ruta).get(body.id_ruta)
    if not ruta or ruta.id_hotel != hotel_id:
        raise HTTPException(404, "Ruta no válida para este hotel")
    
    # Determinar quién pidió el viaje
    if role in (3, 4):  # Supervisor o Admin
        pedida_por = body.pedida_por_id_usuario or user_id
    else:  # Usuario normal
        pedida_por = user_id
    
    # Validar que el usuario existe y es del mismo hotel
    solicitante = db.query(models.Usuario).get(pedida_por)
    if not solicitante or solicitante.id_hotel != hotel_id:
        raise HTTPException(400, "Usuario solicitante no válido")
    
    # Crear el viaje
    viaje = models.Viaje(
        id_hotel=hotel_id,
        id_ruta=body.id_ruta,
        pedida_por_id_usuario=pedida_por,
        hora_pedida=datetime.utcnow(),
        agendada_para=body.agendada_para,
        id_estado_viaje=1  # 1 = PENDIENTE
    )
    
    db.add(viaje)
    db.flush()  # Para obtener el id_viaje
    
    # ✅ AUTO-ASIGNACIÓN: Buscar conductor disponible
    try:
        asignacion_info = _auto_asignar_viaje(db, viaje, hotel_id)
        if asignacion_info:
            # Crear notificación para el conductor
            from .notificaciones import notificar_viaje_asignado
            conductor_usuario_id = asignacion_info.get('conductor_usuario_id')
            if conductor_usuario_id:
                notificar_viaje_asignado(db, viaje.id_viaje, conductor_usuario_id)
    except Exception as e:
        # Si falla la auto-asignación, el viaje queda PENDIENTE
        print(f"⚠️ Auto-asignación falló: {e}")
    
    db.commit()
    db.refresh(viaje)
    return viaje


def _auto_asignar_viaje(db: Session, viaje: models.Viaje, hotel_id: int) -> dict | None:
    """Asigna automáticamente un conductor y vehículo disponibles al viaje."""
    
    # ✅ Simplificar la consulta - no exigir disponibilidad por ahora
    conductores_con_vehiculo = (
        db.query(
            models.Usuario.id_usuario,
            models.ConductorVehiculo.id_vehiculo,
            models.Usuario.nombre_usuario,
            models.Usuario.apellido1_usuario,
            models.Vehiculo.patente
        )
        .join(models.Conductor, models.Usuario.id_usuario == models.Conductor.id_usuario)
        .join(
            models.ConductorVehiculo, 
            models.Conductor.id_conductor == models.ConductorVehiculo.id_conductor
        )
        .join(models.Vehiculo, models.ConductorVehiculo.id_vehiculo == models.Vehiculo.id_vehiculo)
        .filter(
            models.Usuario.id_hotel == hotel_id,
            models.Usuario.id_tipo_usuario == 2,
            models.Usuario.id_estado_actividad == 1,
            models.Usuario.is_suspended == False,
            models.ConductorVehiculo.hora_fin_asignacion.is_(None)
        )
        .all()
    )
    
    if not conductores_con_vehiculo:
        print(f"⚠️ No hay conductores con vehículo asignado")
        return None
    
    # Verificar conflictos
    for id_conductor, id_vehiculo, nombre, apellido, patente in conductores_con_vehiculo:
        conflicto = (
            db.query(models.AsignacionViajes)
            .join(models.Viaje, models.AsignacionViajes.id_viaje == models.Viaje.id_viaje)
            .filter(
                models.AsignacionViajes.id_conductor == id_conductor,
                models.Viaje.agendada_para == viaje.agendada_para,
                models.Viaje.id_estado_viaje.in_([2, 3, 4])
            )
            .first()
        )
        
        if not conflicto:
            asignacion = models.AsignacionViajes(
                id_viaje=viaje.id_viaje,
                id_conductor=id_conductor,
                id_vehiculo=id_vehiculo,
                asignado_a_id_usuario=None,
                hora_asignacion=datetime.utcnow()
            )
            
            viaje.id_estado_viaje = 2
            db.add(asignacion)
            db.flush()
            
            print(f"✅ Viaje {viaje.id_viaje} asignado a {nombre} {apellido}")
            
            return {
                'id_conductor': id_conductor,
                'id_vehiculo': id_vehiculo,
                'conductor_nombre': f"{nombre} {apellido}".strip(),
                'vehiculo_patente': patente
            }
    
    print(f"⚠️ Todos los conductores tienen conflictos")
    return None
@router.post("/{id_viaje}/asignar", dependencies=[Depends(require_role(3))])
def asignar_viaje_manual(
    id_viaje: int,
    body: dict,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Asigna manualmente un conductor a un viaje.
    Solo usa el vehículo que ya tiene asignado el conductor.
    """
    user_id = int(claims["sub"])
    me = db.query(models.Usuario).get(user_id)
    
    if not me or not me.id_hotel:
        raise HTTPException(403, "Sin hotel asignado")
    
    hotel_id = me.id_hotel
    id_conductor = body.get('id_conductor')
    
    if not id_conductor:
        raise HTTPException(400, "Falta id_conductor")
    
    # Validar viaje
    viaje = db.query(models.Viaje).get(id_viaje)
    if not viaje or viaje.id_hotel != hotel_id:
        raise HTTPException(404, "Viaje no encontrado")
    
    if viaje.id_estado_viaje != 1:
        raise HTTPException(400, "El viaje ya fue asignado")
    
    # Validar conductor
    conductor_usuario = db.query(models.Usuario).get(id_conductor)
    if not conductor_usuario or conductor_usuario.id_hotel != hotel_id or conductor_usuario.id_tipo_usuario != 2:
        raise HTTPException(400, "Conductor no válido")
    
    if conductor_usuario.id_estado_actividad != 1 or conductor_usuario.is_suspended:
        raise HTTPException(400, "Conductor no disponible")
    
    # Buscar el registro de conductor
    conductor = db.query(models.Conductor).filter(
        models.Conductor.id_usuario == id_conductor
    ).first()
    
    if not conductor:
        raise HTTPException(400, "Conductor no encontrado en tabla conductores")
    
    # Buscar vehículo asignado al conductor
    conductor_vehiculo = (
        db.query(models.ConductorVehiculo)
        .filter(
            models.ConductorVehiculo.id_conductor == conductor.id_conductor,
            models.ConductorVehiculo.hora_fin_asignacion.is_(None)
        )
        .first()
    )
    
    if not conductor_vehiculo:
        raise HTTPException(400, "El conductor no tiene vehículo asignado")
    
    id_vehiculo = conductor_vehiculo.id_vehiculo
    
    # Validar conflictos de horario
    conflicto = (
        db.query(models.AsignacionViajes)
        .join(models.Viaje, models.AsignacionViajes.id_viaje == models.Viaje.id_viaje)
        .filter(
            models.Viaje.agendada_para == viaje.agendada_para,
            models.AsignacionViajes.id_conductor == id_conductor
        )
        .first()
    )
    
    if conflicto:
        raise HTTPException(409, "El conductor ya tiene un viaje asignado en ese horario")
    
    # Crear asignación
    asignacion = models.AsignacionViajes(
        id_viaje=id_viaje,
        id_conductor=id_conductor,
        id_vehiculo=id_vehiculo,
        asignado_a_id_usuario=user_id,
        hora_asignacion=datetime.utcnow()
    )
    
    # Cambiar estado del viaje
    viaje.id_estado_viaje = 2  # ASIGNADO
    
    db.add(asignacion)
    db.commit()
    db.refresh(asignacion)
    
    # Notificar al conductor
    from .notificaciones import notificar_viaje_asignado
    notificar_viaje_asignado(db, id_viaje, id_conductor)
    
    return {"ok": True, "message": "Viaje asignado correctamente"}

@router.get("")
def listar_viajes(
    estado: Optional[int] = Query(None, description="Filtrar por estado"),
    fecha_desde: Optional[datetime] = None,
    fecha_hasta: Optional[datetime] = None,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """Lista viajes según el rol del usuario"""
    user_id = int(claims["sub"])
    role = int(claims.get("role", 0))
    me = db.query(models.Usuario).get(user_id)
    
    if not me:
        raise HTTPException(404, "Usuario no encontrado")
    
    # Query base SIN JOINs primero
    q = db.query(models.Viaje)
    
    # Filtrar según rol
    if role in (3, 4):  # Supervisor/Admin
        if not me.id_hotel:
            raise HTTPException(403, "Sin hotel asignado")
        q = q.filter(models.Viaje.id_hotel == me.id_hotel)
    elif role == 2:  # Conductor
        # Solo viajes asignados a este conductor
        q = q.join(
            models.AsignacionViajes,
            models.Viaje.id_viaje == models.AsignacionViajes.id_viaje
        ).filter(
            models.AsignacionViajes.id_conductor == me.id_usuario)
    else:  # Usuario
        q = q.filter(models.Viaje.pedida_por_id_usuario == user_id)
    
    # Filtros opcionales
    if estado:
        q = q.filter(models.Viaje.id_estado_viaje == estado)
    if fecha_desde:
        q = q.filter(models.Viaje.agendada_para >= fecha_desde)
    if fecha_hasta:
        q = q.filter(models.Viaje.agendada_para <= fecha_hasta)
    
    viajes = q.order_by(models.Viaje.agendada_para.desc()).all()
    
    # Construir respuesta con info adicional
    resultado = []
    for viaje in viajes:
        # Obtener info del solicitante
        solicitante = db.query(models.Usuario).get(viaje.pedida_por_id_usuario)
        
        viaje_dict = {
            "id_viaje": viaje.id_viaje,
            "id_hotel": viaje.id_hotel,
            "id_ruta": viaje.id_ruta,
            "pedida_por_id_usuario": viaje.pedida_por_id_usuario,
            "hora_pedida": viaje.hora_pedida.isoformat() if viaje.hora_pedida else None,
            "agendada_para": viaje.agendada_para.isoformat() if viaje.agendada_para else None,
            "id_estado_viaje": viaje.id_estado_viaje,
            "solicitante_nombre": "",
            "solicitante_telefono": None,
        }
        
        if solicitante:
            nombre_completo = f"{solicitante.nombre_usuario} {solicitante.apellido1_usuario or ''}".strip()
            viaje_dict["solicitante_nombre"] = nombre_completo
            viaje_dict["solicitante_telefono"] = solicitante.telefono_usuario
        
        resultado.append(viaje_dict)
    
    return resultado


@router.get("/{id_viaje}")
def obtener_viaje(
    id_viaje: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Obtiene detalles de un viaje específico con info del conductor y vehículo.
    """
    user_id = int(claims["sub"])
    role = int(claims.get("role", 0))
    me = db.query(models.Usuario).get(user_id)
    
    # ✅ Query mejorada con JOINs
    result = (
        db.query(
            models.Viaje,
            models.Usuario.nombre_usuario.label("solicitante_nombre"),
            models.Usuario.apellido1_usuario.label("solicitante_apellido1"),
            models.Usuario.telefono_usuario.label("solicitante_telefono"),
            models.Ruta.nombre_ruta.label("ruta_nombre"),
            models.Ruta.origen_ruta.label("origen"),
            models.Ruta.destino_ruta.label("destino")
        )
        .join(models.Usuario, models.Viaje.pedida_por_id_usuario == models.Usuario.id_usuario)
        .join(models.Ruta, models.Viaje.id_ruta == models.Ruta.id_ruta)
        .filter(models.Viaje.id_viaje == id_viaje)
        .first()
    )
    
    if not result:
        raise HTTPException(404, "Viaje no encontrado")
    
    viaje, sol_nombre, sol_ap1, sol_tel, ruta_nombre, origen, destino = result
    
    # Validar acceso
    if role in (3, 4):  # Supervisor/Admin
        if viaje.id_hotel != me.id_hotel:
            raise HTTPException(403, "Sin acceso a este viaje")
    elif role == 2:  # Conductor
        asig = db.query(models.AsignacionViajes).filter(
            models.AsignacionViajes.id_viaje == id_viaje,
            models.AsignacionViajes.id_conductor == user_id
        ).first()
        if not asig:
            raise HTTPException(403, "Viaje no asignado a ti")
    else:  # Usuario
        if viaje.pedida_por_id_usuario != user_id:
            raise HTTPException(403, "No es tu viaje")
    
    # ✅ Buscar info del conductor y vehículo si está asignado
    conductor_info = None
    vehiculo_info = None
    
    if viaje.id_estado_viaje >= 2:  # ASIGNADO o posterior
        asignacion = (
            db.query(
                models.AsignacionViajes,
                models.Usuario.nombre_usuario.label("conductor_nombre"),
                models.Usuario.apellido1_usuario.label("conductor_apellido1"),
                models.Usuario.telefono_usuario.label("conductor_telefono"),
                models.Vehiculo.patente.label("vehiculo_patente"),
                models.MarcaVehiculo.nombre_marca_vehiculo.label("marca"),
                models.Vehiculo.modelo.label("modelo"),
                models.Vehiculo.capacidad.label("capacidad")
            )
            .join(models.Usuario, models.AsignacionViajes.id_conductor == models.Usuario.id_usuario)
            .outerjoin(models.Vehiculo, models.AsignacionViajes.id_vehiculo == models.Vehiculo.id_vehiculo)
            .outerjoin(models.MarcaVehiculo, models.Vehiculo.id_marca_vehiculo == models.MarcaVehiculo.id_marca_vehiculo)
            .filter(models.AsignacionViajes.id_viaje == id_viaje)
            .first()
        )
        
        if asignacion:
            asig, cond_nom, cond_ap1, cond_tel, patente, marca, modelo, cap = asignacion
            conductor_info = {
                "nombre": f"{cond_nom} {cond_ap1 or ''}".strip(),
                "telefono": cond_tel
            }
            if patente:
                vehiculo_info = {
                    "patente": patente,
                    "marca": marca,
                    "modelo": modelo,
                    "capacidad": cap,
                    "descripcion": f"{patente} - {marca} {modelo or ''}".strip()
                }
    
    return {
        "id_viaje": viaje.id_viaje,
        "id_hotel": viaje.id_hotel,
        "id_ruta": viaje.id_ruta,
        "pedida_por_id_usuario": viaje.pedida_por_id_usuario,
        "hora_pedida": viaje.hora_pedida,
        "agendada_para": viaje.agendada_para,
        "id_estado_viaje": viaje.id_estado_viaje,
        # Info del solicitante
        "solicitante_nombre": f"{sol_nombre} {sol_ap1 or ''}".strip(),
        "solicitante_telefono": sol_tel,
        # Info de la ruta
        "ruta_nombre": ruta_nombre,
        "origen_ruta": origen,
        "destino_ruta": destino,
        # Info del conductor (si aplica)
        "conductor": conductor_info,
        # Info del vehículo (si aplica)
        "vehiculo": vehiculo_info
    }