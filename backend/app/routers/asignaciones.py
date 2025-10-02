# app/routers/asignaciones.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime

from ..deps import get_db
from ..auth_deps import get_current_claims, require_role
from .. import models, schemas

router = APIRouter(prefix="/asignaciones", tags=["asignaciones"])


@router.get("/", response_model=list[schemas.AsignacionOut])
def listar_asignaciones(
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Lista todas las asignaciones.
    - Admin/Supervisor: todas de su hotel
    - Conductor: solo las suyas
    """
    user_id = int(claims["sub"])
    role = int(claims.get("role", 0))
    me = db.query(models.Usuario).get(user_id)
    
    if not me:
        raise HTTPException(404, "Usuario no encontrado")
    
    q = db.query(models.AsignacionViajes)
    
    if role in (3, 4):  # Supervisor/Admin
        if not me.id_hotel:
            raise HTTPException(403, "Sin hotel asignado")
        # Filtrar por hotel a través del viaje
        q = q.join(models.Viaje).filter(models.Viaje.id_hotel == me.id_hotel)
    elif role == 2:  # Conductor
        q = q.filter(models.AsignacionViajes.id_conductor == user_id)
    else:
        raise HTTPException(403, "Sin permisos para ver asignaciones")
    
    return q.order_by(models.AsignacionViajes.hora_asignacion.desc()).all()


@router.get("/{id_asignacion}", response_model=schemas.AsignacionOut)
def obtener_asignacion(
    id_asignacion: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Obtiene una asignación específica.
    Valida permisos según rol.
    """
    user_id = int(claims["sub"])
    role = int(claims.get("role", 0))
    me = db.query(models.Usuario).get(user_id)
    
    asig = db.query(models.AsignacionViajes).get(id_asignacion)
    if not asig:
        raise HTTPException(404, "Asignación no encontrada")
    
    # Validar acceso
    if role in (3, 4):  # Supervisor/Admin
        viaje = db.query(models.Viaje).get(asig.id_viaje)
        if viaje.id_hotel != me.id_hotel:
            raise HTTPException(403, "Sin acceso a esta asignación")
    elif role == 2:  # Conductor
        if asig.id_conductor != user_id:
            raise HTTPException(403, "No es tu asignación")
    else:
        raise HTTPException(403, "Sin permisos")
    
    return asig


@router.patch("/{id_asignacion}", response_model=schemas.AsignacionOut, dependencies=[Depends(require_role(3))])
def actualizar_asignacion(
    id_asignacion: int,
    id_conductor: int,
    id_vehiculo: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Actualiza (reasigna) un conductor/vehículo a una asignación existente.
    Solo Supervisores y Admins.
    """
    user_id = int(claims["sub"])
    me = db.query(models.Usuario).get(user_id)
    
    if not me or not me.id_hotel:
        raise HTTPException(403, "Sin hotel asignado")
    
    asig = db.query(models.AsignacionViajes).get(id_asignacion)
    if not asig:
        raise HTTPException(404, "Asignación no encontrada")
    
    viaje = db.query(models.Viaje).get(asig.id_viaje)
    if viaje.id_hotel != me.id_hotel:
        raise HTTPException(403, "Sin acceso a esta asignación")
    
    # No permitir reasignar si ya está en curso o completado
    if viaje.id_estado_viaje >= 4:  # EN_CURSO o COMPLETADO
        raise HTTPException(400, "No se puede reasignar un viaje en curso o completado")
    
    # Validar nuevo conductor
    conductor = db.query(models.Usuario).get(id_conductor)
    if not conductor or conductor.id_hotel != me.id_hotel or conductor.id_tipo_usuario != 2:
        raise HTTPException(400, "Conductor no válido")
    
    if conductor.id_estado_actividad != 1 or conductor.is_suspended:
        raise HTTPException(400, "Conductor no disponible")
    
    # Validar nuevo vehículo
    vehiculo = db.query(models.Vehiculo).get(id_vehiculo)
    if not vehiculo or vehiculo.id_hotel != me.id_hotel:
        raise HTTPException(400, "Vehículo no válido")
    
    if vehiculo.id_estado_vehiculo != 1:
        raise HTTPException(400, "Vehículo no disponible")
    
    # Actualizar
    asig.id_conductor = id_conductor
    asig.id_vehiculo = id_vehiculo
    asig.asignado_a_id_usuario = user_id
    asig.hora_asignacion = datetime.utcnow()
    asig.hora_aceptacion = None  # Resetear aceptación si hubo cambio
    
    # Volver a estado ASIGNADO si estaba ACEPTADO
    if viaje.id_estado_viaje == 3:
        viaje.id_estado_viaje = 2
    
    db.commit()
    db.refresh(asig)
    
    # Notificar al nuevo conductor
    from .notificaciones import notificar_viaje_asignado
    notificar_viaje_asignado(db, viaje.id_viaje, id_conductor)
    
    return asig


@router.delete("/{id_asignacion}", dependencies=[Depends(require_role(3))])
def eliminar_asignacion(
    id_asignacion: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Elimina una asignación (desasigna el viaje).
    El viaje vuelve a estado PENDIENTE.
    Solo Supervisores y Admins.
    """
    user_id = int(claims["sub"])
    me = db.query(models.Usuario).get(user_id)
    
    if not me or not me.id_hotel:
        raise HTTPException(403, "Sin hotel asignado")
    
    asig = db.query(models.AsignacionViajes).get(id_asignacion)
    if not asig:
        raise HTTPException(404, "Asignación no encontrada")
    
    viaje = db.query(models.Viaje).get(asig.id_viaje)
    if viaje.id_hotel != me.id_hotel:
        raise HTTPException(403, "Sin acceso a esta asignación")
    
    # No permitir desasignar si ya está en curso o completado
    if viaje.id_estado_viaje >= 4:
        raise HTTPException(400, "No se puede desasignar un viaje en curso o completado")
    
    # Volver a PENDIENTE
    viaje.id_estado_viaje = 1
    
    db.delete(asig)
    db.commit()
    
    return {"ok": True, "message": "Asignación eliminada, viaje vuelve a PENDIENTE"}