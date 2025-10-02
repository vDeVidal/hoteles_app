# app/routers/notificaciones.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, date, time as time_type

from .. import models, schemas
from ..deps import get_db
from ..auth_deps import get_current_claims

router = APIRouter(prefix="/notificaciones", tags=["notificaciones"])


@router.get("", response_model=List[schemas.NotificacionOut])
def listar_notificaciones(
    solo_no_leidas: bool = False,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Lista notificaciones del usuario actual.
    Opcionalmente solo las no leídas.
    """
    user_id = int(claims["sub"])
    
    q = db.query(models.Notificacion).filter(
        models.Notificacion.id_usuario == user_id
    )
    
    if solo_no_leidas:
        q = q.filter(models.Notificacion.id_estado_mensaje == 1)  # 1 = NO_LEIDO
    
    return q.order_by(models.Notificacion.fecha_envio.desc()).all()


@router.post("", response_model=schemas.NotificacionOut, status_code=status.HTTP_201_CREATED)
def crear_notificacion(
    body: schemas.NotificacionCreate,
    db: Session = Depends(get_db),
    _: dict = Depends(get_current_claims)
):
    """
    Crea una notificación para un usuario.
    Solo supervisores y admins pueden crear notificaciones.
    """
    # Validar que el usuario destino existe
    usuario = db.query(models.Usuario).get(body.id_usuario)
    if not usuario:
        raise HTTPException(404, "Usuario no encontrado")
    
    ahora = datetime.utcnow()
    notif = models.Notificacion(
        id_usuario=body.id_usuario,
        contenido_notificacion=body.contenido_notificacion,
        hora_envio=ahora.time(),
        fecha_envio=ahora.date(),
        id_estado_mensaje=1  # NO_LEIDO por defecto
    )
    
    db.add(notif)
    db.commit()
    db.refresh(notif)
    return notif


@router.patch("/{id_notificacion}/marcar-leida")
def marcar_como_leida(
    id_notificacion: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Marca una notificación como leída.
    Solo el dueño de la notificación puede marcarla.
    """
    user_id = int(claims["sub"])
    
    notif = db.query(models.Notificacion).get(id_notificacion)
    if not notif:
        raise HTTPException(404, "Notificación no encontrada")
    
    if notif.id_usuario != user_id:
        raise HTTPException(403, "No es tu notificación")
    
    notif.id_estado_mensaje = 2  # LEIDO
    db.commit()
    
    return {"ok": True}


@router.patch("/marcar-todas-leidas")
def marcar_todas_leidas(
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Marca todas las notificaciones del usuario como leídas.
    """
    user_id = int(claims["sub"])
    
    db.query(models.Notificacion).filter(
        models.Notificacion.id_usuario == user_id,
        models.Notificacion.id_estado_mensaje == 1
    ).update({"id_estado_mensaje": 2})
    
    db.commit()
    return {"ok": True}


@router.delete("/{id_notificacion}")
def eliminar_notificacion(
    id_notificacion: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Elimina una notificación.
    Solo el dueño puede eliminarla.
    """
    user_id = int(claims["sub"])
    
    notif = db.query(models.Notificacion).get(id_notificacion)
    if not notif:
        raise HTTPException(404, "Notificación no encontrada")
    
    if notif.id_usuario != user_id:
        raise HTTPException(403, "No es tu notificación")
    
    db.delete(notif)
    db.commit()
    
    return {"ok": True}


# ========================================
#  Helper: Notificar automáticamente
# ========================================

def notificar_viaje_asignado(db: Session, viaje_id: int, conductor_id: int):
    """
    Crea una notificación cuando se asigna un viaje a un conductor.
    Llamar desde viajes.py cuando se asigna.
    """
    viaje = db.query(models.Viaje).get(viaje_id)
    if not viaje:
        return
    
    ruta = db.query(models.Ruta).get(viaje.id_ruta)
    mensaje = f"Nuevo viaje asignado: {ruta.nombre_ruta if ruta else 'ruta'} para {viaje.agendada_para.strftime('%d/%m/%Y %H:%M')}"
    
    ahora = datetime.utcnow()
    notif = models.Notificacion(
        id_usuario=conductor_id,
        contenido_notificacion=mensaje,
        hora_envio=ahora.time(),
        fecha_envio=ahora.date(),
        id_estado_mensaje=1
    )
    db.add(notif)
    db.commit()


def notificar_viaje_aceptado(db: Session, viaje_id: int, usuario_id: int):
    """
    Notifica al usuario que su viaje fue aceptado por el conductor.
    """
    viaje = db.query(models.Viaje).get(viaje_id)
    if not viaje:
        return
    
    mensaje = f"Tu viaje ha sido aceptado por el conductor. Salida: {viaje.agendada_para.strftime('%d/%m/%Y %H:%M')}"
    
    ahora = datetime.utcnow()
    notif = models.Notificacion(
        id_usuario=usuario_id,
        contenido_notificacion=mensaje,
        hora_envio=ahora.time(),
        fecha_envio=ahora.date(),
        id_estado_mensaje=1
    )
    db.add(notif)
    db.commit()