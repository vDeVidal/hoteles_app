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
    """
    Asigna automáticamente un conductor y vehículo disponibles al viaje.
    """
    # ✅ Buscar conductores CON vehículo asignado y disponibles
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
        .join(
            models.DisponibilidadConductores,
            models.Conductor.id_conductor == models.DisponibilidadConductores.id_conductor
        )
        .filter(
            models.Usuario.id_hotel == hotel_id,
            models.Usuario.id_tipo_usuario == 2,
            models.Usuario.id_estado_actividad == 1,
            models.Usuario.is_suspended == False,
            models.ConductorVehiculo.hora_fin_asignacion.is_(None),  # Vehículo actualmente asignado
            models.DisponibilidadConductores.dias_disponibles_semanales > 0  # Tiene disponibilidad
        )
        .all()
    )
    
    if not conductores_con_vehiculo:
        print(f"⚠️ No hay conductores con vehículo asignado disponibles")
        return None
    
    # Verificar conflictos de horario
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
            # Crear asignación
            asignacion = models.AsignacionViajes(
                id_viaje=viaje.id_viaje,
                id_conductor=id_conductor,
                id_vehiculo=id_vehiculo,
                asignado_a_id_usuario=None,
                hora_asignacion=datetime.utcnow()
            )
            
            viaje.id_estado_viaje = 2  # ASIGNADO
            db.add(asignacion)
            db.flush()
            
            print(f"✅ Viaje {viaje.id_viaje} asignado a conductor {id_conductor} con vehículo {patente}")
            
            return {
                'id_conductor': id_conductor,
                'id_vehiculo': id_vehiculo,
                'conductor_nombre': f"{nombre} {apellido}".strip(),
                'vehiculo_patente': patente
            }
    
    print(f"⚠️ Todos los conductores tienen conflictos de horario")
    return None
    
    # Seleccionar vehículo (elegir el primero disponible o aleatorio)
    vehiculo_seleccionado = choice(vehiculos_disponibles)
    
    # Crear asignación
    asignacion = models.AsignacionViajes(
        id_viaje=viaje.id_viaje,
        id_conductor=conductor_seleccionado.id_conductor,
        id_vehiculo=vehiculo_seleccionado.id_vehiculo,
        asignado_a_id_usuario=None,  # Sistema automático
        hora_asignacion=datetime.utcnow()
    )
    
    # Cambiar estado del viaje a ASIGNADO
    viaje.id_estado_viaje = 2
    
    db.add(asignacion)
    db.flush()
    
    print(f"✅ Viaje {viaje.id_viaje} asignado automáticamente a conductor {conductor_seleccionado.id_conductor}")

    usuario_conductor = conductor_seleccionado.usuario
    nombre_conductor = None
    if usuario_conductor:
        nombre_conductor = f"{usuario_conductor.nombre_usuario} {usuario_conductor.apellido1_usuario or ''}".strip()
    
    return {
        'conductor_usuario_id': usuario_conductor.id_usuario if usuario_conductor else None,
        'id_vehiculo': vehiculo_seleccionado.id_vehiculo,
        'conductor_nombre': nombre_conductor,
        'vehiculo_info': f"{vehiculo_seleccionado.patente}"
    }


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
            models.AsignacionViajes.id_conductor == me.id_usuario
        )
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