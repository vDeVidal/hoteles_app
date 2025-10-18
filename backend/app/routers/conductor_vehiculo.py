# app/routers/conductor_vehiculo.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime
from typing import List, Optional

from .. import models, schemas
from ..deps import get_db
from ..auth_deps import get_current_claims, require_role

router = APIRouter(prefix="/conductor-vehiculo", tags=["conductor-vehiculo"])

@router.get("/mi-vehiculo")
def obtener_mi_vehiculo(
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Obtiene el vehículo actualmente asignado al conductor.
    """
    user_id = int(claims["sub"])
    
    # Buscar conductor
    conductor = (
        db.query(models.Conductor)
        .filter(models.Conductor.id_usuario == user_id)
        .first()
    )
    
    if not conductor:
        raise HTTPException(404, "No eres conductor")
    
    # Buscar asignación activa
    asignacion = (
        db.query(
            models.ConductorVehiculo,
            models.Vehiculo.patente,
            models.Vehiculo.modelo,
            models.Vehiculo.anio,
            models.Vehiculo.capacidad,
            models.MarcaVehiculo.nombre_marca_vehiculo
        )
        .join(models.Vehiculo, models.ConductorVehiculo.id_vehiculo == models.Vehiculo.id_vehiculo)
        .join(models.MarcaVehiculo, models.Vehiculo.id_marca_vehiculo == models.MarcaVehiculo.id_marca_vehiculo)
        .filter(
            models.ConductorVehiculo.id_conductor == conductor.id_conductor,
            models.ConductorVehiculo.hora_fin_asignacion.is_(None)
        )
        .first()
    )
    
    if not asignacion:
        return {"tiene_vehiculo": False}
    
    cv, patente, modelo, anio, capacidad, marca = asignacion
    
    return {
        "tiene_vehiculo": True,
        "id_conductor_vehiculo": cv.id_conductor_vehiculo,
        "patente": patente,
        "marca": marca,
        "modelo": modelo,
        "anio": anio,
        "capacidad": capacidad,
        "descripcion": f"{patente} - {marca} {modelo or ''}".strip(),
        "asignado_desde": cv.hora_asignacion.isoformat()
    }


@router.get("", response_model=List[dict], dependencies=[Depends(require_role(3))])
def listar_asignaciones_actuales(
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Lista asignaciones activas de conductor-vehículo (sin hora_fin_asignacion).
    Solo supervisores y admins.
    """
    me = db.query(models.Usuario).get(int(claims["sub"]))
    if not me or not me.id_hotel:
        raise HTTPException(403, "Usuario sin hotel")
    
    # Buscar asignaciones activas del hotel
    asignaciones = (
        db.query(
            models.ConductorVehiculo,
            models.Usuario.nombre_usuario,
            models.Usuario.apellido1_usuario,
            models.Vehiculo.patente,
            models.MarcaVehiculo.nombre_marca_vehiculo
        )
        .join(models.Conductor, models.ConductorVehiculo.id_conductor == models.Conductor.id_conductor)
        .join(models.Usuario, models.Conductor.id_usuario == models.Usuario.id_usuario)
        .join(models.Vehiculo, models.ConductorVehiculo.id_vehiculo == models.Vehiculo.id_vehiculo)
        .join(models.MarcaVehiculo, models.Vehiculo.id_marca_vehiculo == models.MarcaVehiculo.id_marca_vehiculo)
        .filter(
            models.Usuario.id_hotel == me.id_hotel,
            models.ConductorVehiculo.hora_fin_asignacion.is_(None)  # Solo activas
        )
        .all()
    )
    
    resultado = []
    for cv, nombre, apellido, patente, marca in asignaciones:
        resultado.append({
            "id_conductor_vehiculo": cv.id_conductor_vehiculo,
            "id_conductor": cv.id_conductor,
            "conductor_nombre": f"{nombre} {apellido}",
            "id_vehiculo": cv.id_vehiculo,
            "vehiculo_info": f"{patente} - {marca}",
            "hora_asignacion": cv.hora_asignacion.isoformat(),
        })
    
    return resultado


@router.post("", status_code=status.HTTP_201_CREATED, dependencies=[Depends(require_role(3))])
def asignar_vehiculo_a_conductor(
    body: schemas.ConductorVehiculoAssignIn,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Asigna un vehículo a un conductor.
    Finaliza cualquier asignación previa activa del conductor.
    """
    me = db.query(models.Usuario).get(int(claims["sub"]))
    if not me or not me.id_hotel:
        raise HTTPException(403, "Usuario sin hotel")
    
    # Validar que el usuario sea conductor del hotel
    usuario_conductor = db.query(models.Usuario).get(body.id_conductor)
    if not usuario_conductor or usuario_conductor.id_hotel != me.id_hotel or usuario_conductor.id_tipo_usuario != 2:
        raise HTTPException(400, "Conductor no válido")
    
    # Buscar el registro en la tabla conductores (o crearlo si no existe)
    conductor = db.query(models.Conductor).filter(models.Conductor.id_usuario == body.id_conductor).first()
    if not conductor:
        # Crear registro de conductor si no existe
        conductor = models.Conductor(
            id_usuario=body.id_conductor,
            id_estado_actividad=1,  # Activo
            fecha_contratacion=datetime.utcnow().date()
        )
        db.add(conductor)
        db.flush()  # Para obtener el id_conductor
    
    # Validar vehículo
    vehiculo = db.query(models.Vehiculo).get(body.id_vehiculo)
    if not vehiculo or vehiculo.id_hotel != me.id_hotel:
        raise HTTPException(400, "Vehículo no válido")
    
    # Finalizar asignaciones previas del conductor
    asignaciones_previas = (
        db.query(models.ConductorVehiculo)
        .filter(
            models.ConductorVehiculo.id_conductor == conductor.id_conductor,
            models.ConductorVehiculo.hora_fin_asignacion.is_(None)
        )
        .all()
    )
    
    ahora = datetime.utcnow()
    for asig in asignaciones_previas:
        asig.hora_fin_asignacion = ahora
    
    # Crear nueva asignación
    nueva = models.ConductorVehiculo(
        id_conductor=conductor.id_conductor,  # Usar id_conductor, NO id_usuario
        id_vehiculo=body.id_vehiculo,
        hora_asignacion=ahora
    )
    db.add(nueva)
    db.commit()
    db.refresh(nueva)
    
    return {
        "ok": True,
        "id_conductor_vehiculo": nueva.id_conductor_vehiculo,
        "message": "Vehículo asignado correctamente"
    }

@router.post("/iniciar-turno")
def iniciar_turno(
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """Conductor inicia su turno (marca como disponible)."""
    user_id = int(claims["sub"])
    
    conductor = db.query(models.Conductor).filter(
        models.Conductor.id_usuario == user_id
    ).first()
    
    if not conductor:
        raise HTTPException(404, "No eres conductor")
    
    # Buscar o crear disponibilidad
    disponibilidad = (
        db.query(models.DisponibilidadConductores)
        .filter(models.DisponibilidadConductores.id_conductor == conductor.id_conductor)
        .first()
    )
    
    if not disponibilidad:
        disponibilidad = models.DisponibilidadConductores(
            id_conductor=conductor.id_conductor,
            dias_disponibles_semanales=7,
            inicio_turno=datetime.utcnow().time(),
            fin_turno=None
        )
        db.add(disponibilidad)
    else:
        disponibilidad.dias_disponibles_semanales = 7
        disponibilidad.inicio_turno = datetime.utcnow().time()
        disponibilidad.fin_turno = None
    
    # Marcar usuario como disponible
    usuario = db.query(models.Usuario).get(user_id)
    usuario.id_estado_actividad = 1  # Activo
    
    db.commit()
    return {"ok": True, "message": "Turno iniciado", "disponible": True}


@router.post("/finalizar-turno")
def finalizar_turno(
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """Conductor finaliza su turno (marca como no disponible)."""
    user_id = int(claims["sub"])
    
    conductor = db.query(models.Conductor).filter(
        models.Conductor.id_usuario == user_id
    ).first()
    
    if not conductor:
        raise HTTPException(404, "No eres conductor")
    
    # Actualizar disponibilidad
    disponibilidad = (
        db.query(models.DisponibilidadConductores)
        .filter(models.DisponibilidadConductores.id_conductor == conductor.id_conductor)
        .first()
    )
    
    if disponibilidad:
        disponibilidad.dias_disponibles_semanales = 0
        disponibilidad.fin_turno = datetime.utcnow().time()
    
    # Marcar usuario como no disponible
    usuario = db.query(models.Usuario).get(user_id)
    usuario.id_estado_actividad = 2  # Inactivo
    
    db.commit()
    return {"ok": True, "message": "Turno finalizado", "disponible": False}


@router.get("/estado-turno")
def obtener_estado_turno(
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """Obtiene el estado actual del turno del conductor."""
    user_id = int(claims["sub"])
    
    conductor = db.query(models.Conductor).filter(
        models.Conductor.id_usuario == user_id
    ).first()
    
    if not conductor:
        raise HTTPException(404, "No eres conductor")
    
    usuario = db.query(models.Usuario).get(user_id)
    disponibilidad = (
        db.query(models.DisponibilidadConductores)
        .filter(models.DisponibilidadConductores.id_conductor == conductor.id_conductor)
        .first()
    )
    
    esta_disponible = (
        usuario.id_estado_actividad == 1 and
        disponibilidad and
        disponibilidad.dias_disponibles_semanales > 0
    )
    
    return {
        "disponible": esta_disponible,
        "inicio_turno": disponibilidad.inicio_turno.isoformat() if disponibilidad and disponibilidad.inicio_turno else None,
        "fin_turno": disponibilidad.fin_turno.isoformat() if disponibilidad and disponibilidad.fin_turno else None
    }

@router.patch("/{id_conductor_vehiculo}/finalizar", dependencies=[Depends(require_role(3))])
def finalizar_asignacion(
    id_conductor_vehiculo: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Finaliza una asignación conductor-vehículo.
    """
    me = db.query(models.Usuario).get(int(claims["sub"]))
    if not me or not me.id_hotel:
        raise HTTPException(403, "Usuario sin hotel")
    
    asig = db.query(models.ConductorVehiculo).get(id_conductor_vehiculo)
    if not asig:
        raise HTTPException(404, "Asignación no encontrada")
    
    # Validar que el conductor sea del mismo hotel
    conductor = db.query(models.Conductor).get(asig.id_conductor)
    usuario = db.query(models.Usuario).get(conductor.id_usuario)
    if usuario.id_hotel != me.id_hotel:
        raise HTTPException(403, "Sin acceso a esta asignación")
    
    if asig.hora_fin_asignacion:
        raise HTTPException(400, "La asignación ya fue finalizada")
    
    asig.hora_fin_asignacion = datetime.utcnow()
    db.commit()
    
    return {"ok": True, "message": "Asignación finalizada"}