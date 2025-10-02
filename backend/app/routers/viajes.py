# app/routers/viajes.py
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
from typing import List, Optional
from datetime import datetime

from .. import models, schemas
from ..deps import get_db
from ..auth_deps import get_current_claims, require_role

router = APIRouter(prefix="/viajes", tags=["viajes"])


def _hotel_of_user(db: Session, claims: dict) -> int:
    """Helper: obtiene el hotel del usuario actual."""
    me = db.query(models.Usuario).get(int(claims["sub"]))
    if not me or not me.id_hotel:
        raise HTTPException(403, "Usuario sin hotel")
    return me.id_hotel


# ========================================
#  SUPERVISOR: Crear viaje y asignar
# ========================================

@router.post("", response_model=schemas.ViajeOut, status_code=status.HTTP_201_CREATED)
def crear_viaje(
    body: schemas.ViajeCreateIn,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Crea un nuevo viaje.
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
    
    viaje = models.Viaje(
        id_hotel=hotel_id,
        id_ruta=body.id_ruta,
        pedida_por_id_usuario=pedida_por,
        hora_pedida=datetime.utcnow(),
        agendada_para=body.agendada_para,
        id_estado_viaje=1  # 1 = PENDIENTE
    )
    
    db.add(viaje)
    db.commit()
    db.refresh(viaje)
    return viaje


@router.get("", response_model=List[schemas.ViajeOut])
def listar_viajes(
    estado: Optional[int] = Query(None, description="Filtrar por estado (1=PENDIENTE, 2=ASIGNADO, etc)"),
    fecha_desde: Optional[datetime] = None,
    fecha_hasta: Optional[datetime] = None,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Lista viajes según el rol del usuario:
    - Admin/Supervisor: todos los viajes de su hotel
    - Conductor: viajes asignados a él
    - Usuario: solo sus propios viajes
    """
    user_id = int(claims["sub"])
    role = int(claims.get("role", 0))
    me = db.query(models.Usuario).get(user_id)
    
    if not me:
        raise HTTPException(404, "Usuario no encontrado")
    
    q = db.query(models.Viaje)
    
    if role in (3, 4):  # Supervisor/Admin
        if not me.id_hotel:
            raise HTTPException(403, "Sin hotel asignado")
        q = q.filter(models.Viaje.id_hotel == me.id_hotel)
    elif role == 2:  # Conductor
        # Solo viajes asignados a este conductor
        q = q.join(models.AsignacionViajes).filter(
            models.AsignacionViajes.id_conductor == me.id_usuario
        )
    else:  # Usuario normal
        q = q.filter(models.Viaje.pedida_por_id_usuario == user_id)
    
    # Filtros opcionales
    if estado:
        q = q.filter(models.Viaje.id_estado_viaje == estado)
    if fecha_desde:
        q = q.filter(models.Viaje.agendada_para >= fecha_desde)
    if fecha_hasta:
        q = q.filter(models.Viaje.agendada_para <= fecha_hasta)
    
    return q.order_by(models.Viaje.agendada_para.desc()).all()


@router.get("/{id_viaje}", response_model=schemas.ViajeOut)
def obtener_viaje(
    id_viaje: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Obtiene detalles de un viaje específico.
    Valida permisos según rol.
    """
    user_id = int(claims["sub"])
    role = int(claims.get("role", 0))
    me = db.query(models.Usuario).get(user_id)
    
    viaje = db.query(models.Viaje).get(id_viaje)
    if not viaje:
        raise HTTPException(404, "Viaje no encontrado")
    
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
    
    return viaje


# ========================================
#  SUPERVISOR: Asignar conductor/vehículo
# ========================================

@router.post("/{id_viaje}/asignar", response_model=schemas.AsignacionOut, dependencies=[Depends(require_role(3))])
def asignar_viaje(
    id_viaje: int,
    id_conductor: int,
    id_vehiculo: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Asigna un conductor y vehículo a un viaje.
    Solo Supervisores y Admins.
    """
    user_id = int(claims["sub"])
    me = db.query(models.Usuario).get(user_id)
    
    if not me or not me.id_hotel:
        raise HTTPException(403, "Sin hotel asignado")
    
    hotel_id = me.id_hotel
    
    # Validar viaje
    viaje = db.query(models.Viaje).get(id_viaje)
    if not viaje or viaje.id_hotel != hotel_id:
        raise HTTPException(404, "Viaje no encontrado")
    
    if viaje.id_estado_viaje != 1:  # Solo si está PENDIENTE
        raise HTTPException(400, "El viaje ya fue asignado o completado")
    
    # Validar conductor
    conductor = db.query(models.Usuario).get(id_conductor)
    if not conductor or conductor.id_hotel != hotel_id or conductor.id_tipo_usuario != 2:
        raise HTTPException(400, "Conductor no válido")
    
    if conductor.id_estado_actividad != 1 or conductor.is_suspended:
        raise HTTPException(400, "Conductor no disponible")
    
    # Validar vehículo
    vehiculo = db.query(models.Vehiculo).get(id_vehiculo)
    if not vehiculo or vehiculo.id_hotel != hotel_id:
        raise HTTPException(400, "Vehículo no válido")
    
    if vehiculo.id_estado_vehiculo != 1:
        raise HTTPException(400, "Vehículo no disponible")
    
    # Validar conflictos de horario (mismo día y hora)
    conflicto = (
        db.query(models.AsignacionViajes)
        .join(models.Viaje, models.AsignacionViajes.id_viaje == models.Viaje.id_viaje)
        .filter(
            models.Viaje.agendada_para == viaje.agendada_para,
            or_(
                models.AsignacionViajes.id_conductor == id_conductor,
                models.AsignacionViajes.id_vehiculo == id_vehiculo
            )
        )
        .first()
    )
    
    if conflicto:
        raise HTTPException(409, "Conductor o vehículo ya tienen asignación en ese horario")
    
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
    
    return asignacion


# ========================================
#  CONDUCTOR: Aceptar/Rechazar/Iniciar
# ========================================

@router.patch("/{id_viaje}/aceptar", dependencies=[Depends(require_role(2))])
def aceptar_viaje(
    id_viaje: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Conductor acepta un viaje asignado.
    Cambia estado a ACEPTADO (3).
    """
    user_id = int(claims["sub"])
    
    asig = (
        db.query(models.AsignacionViajes)
        .filter(
            models.AsignacionViajes.id_viaje == id_viaje,
            models.AsignacionViajes.id_conductor == user_id
        )
        .first()
    )
    
    if not asig:
        raise HTTPException(404, "No tienes asignado este viaje")
    
    if asig.hora_aceptacion:
        raise HTTPException(400, "Ya aceptaste este viaje")
    
    viaje = db.query(models.Viaje).get(id_viaje)
    if viaje.id_estado_viaje != 2:  # Debe estar ASIGNADO
        raise HTTPException(400, "El viaje no está en estado ASIGNADO")
    
    asig.hora_aceptacion = datetime.utcnow()
    viaje.id_estado_viaje = 3  # ACEPTADO
    
    db.commit()
    return {"ok": True, "message": "Viaje aceptado"}


@router.patch("/{id_viaje}/rechazar", dependencies=[Depends(require_role(2))])
def rechazar_viaje(
    id_viaje: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Conductor rechaza un viaje asignado.
    Vuelve a estado PENDIENTE y elimina la asignación.
    """
    user_id = int(claims["sub"])
    
    asig = (
        db.query(models.AsignacionViajes)
        .filter(
            models.AsignacionViajes.id_viaje == id_viaje,
            models.AsignacionViajes.id_conductor == user_id
        )
        .first()
    )
    
    if not asig:
        raise HTTPException(404, "No tienes asignado este viaje")
    
    if asig.inicio_viaje:
        raise HTTPException(400, "No puedes rechazar un viaje ya iniciado")
    
    viaje = db.query(models.Viaje).get(id_viaje)
    viaje.id_estado_viaje = 1  # Vuelve a PENDIENTE
    
    db.delete(asig)
    db.commit()
    
    return {"ok": True, "message": "Viaje rechazado"}


@router.patch("/{id_viaje}/iniciar", dependencies=[Depends(require_role(2))])
def iniciar_viaje(
    id_viaje: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Conductor inicia el viaje.
    Cambia estado a EN_CURSO (4).
    """
    user_id = int(claims["sub"])
    
    asig = (
        db.query(models.AsignacionViajes)
        .filter(
            models.AsignacionViajes.id_viaje == id_viaje,
            models.AsignacionViajes.id_conductor == user_id
        )
        .first()
    )
    
    if not asig:
        raise HTTPException(404, "No tienes asignado este viaje")
    
    if not asig.hora_aceptacion:
        raise HTTPException(400, "Debes aceptar el viaje primero")
    
    if asig.inicio_viaje:
        raise HTTPException(400, "El viaje ya fue iniciado")
    
    viaje = db.query(models.Viaje).get(id_viaje)
    
    asig.inicio_viaje = datetime.utcnow()
    viaje.id_estado_viaje = 4  # EN_CURSO
    
    db.commit()
    return {"ok": True, "message": "Viaje iniciado"}


@router.patch("/{id_viaje}/finalizar", dependencies=[Depends(require_role(2))])
def finalizar_viaje(
    id_viaje: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Conductor finaliza el viaje.
    Cambia estado a COMPLETADO (5).
    """
    user_id = int(claims["sub"])
    
    asig = (
        db.query(models.AsignacionViajes)
        .filter(
            models.AsignacionViajes.id_viaje == id_viaje,
            models.AsignacionViajes.id_conductor == user_id
        )
        .first()
    )
    
    if not asig:
        raise HTTPException(404, "No tienes asignado este viaje")
    
    if not asig.inicio_viaje:
        raise HTTPException(400, "Debes iniciar el viaje primero")
    
    if asig.fin_viaje:
        raise HTTPException(400, "El viaje ya fue finalizado")
    
    viaje = db.query(models.Viaje).get(id_viaje)
    
    asig.fin_viaje = datetime.utcnow()
    viaje.id_estado_viaje = 5  # COMPLETADO
    
    db.commit()
    return {"ok": True, "message": "Viaje completado"}


# ========================================
#  CANCELAR VIAJE
# ========================================

@router.delete("/{id_viaje}")
def cancelar_viaje(
    id_viaje: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Cancela un viaje.
    - Supervisor/Admin: puede cancelar cualquier viaje de su hotel
    - Usuario: solo sus propios viajes si aún están PENDIENTES
    """
    user_id = int(claims["sub"])
    role = int(claims.get("role", 0))
    me = db.query(models.Usuario).get(user_id)
    
    viaje = db.query(models.Viaje).get(id_viaje)
    if not viaje:
        raise HTTPException(404, "Viaje no encontrado")
    
    # Validar permisos
    if role in (3, 4):  # Supervisor/Admin
        if viaje.id_hotel != me.id_hotel:
            raise HTTPException(403, "Sin acceso a este viaje")
    else:  # Usuario
        if viaje.pedida_por_id_usuario != user_id:
            raise HTTPException(403, "No es tu viaje")
        if viaje.id_estado_viaje != 1:  # Solo PENDIENTES
            raise HTTPException(400, "Solo puedes cancelar viajes pendientes")
    
    # Si tiene asignación, eliminarla
    asig = db.query(models.AsignacionViajes).filter(
        models.AsignacionViajes.id_viaje == id_viaje
    ).first()
    if asig:
        db.delete(asig)
    
    viaje.id_estado_viaje = 6  # CANCELADO
    db.commit()
    
    return {"ok": True, "message": "Viaje cancelado"}