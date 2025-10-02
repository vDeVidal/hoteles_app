# app/routers/conductor_vehiculo.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime
from typing import List, Optional

from .. import models, schemas
from ..deps import get_db
from ..auth_deps import get_current_claims, require_role

router = APIRouter(prefix="/conductor-vehiculo", tags=["conductor-vehiculo"])


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
    id_conductor: int,
    id_vehiculo: int,
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
    
    # Validar conductor
    conductor = db.query(models.Usuario).get(id_conductor)
    if not conductor or conductor.id_hotel != me.id_hotel or conductor.id_tipo_usuario != 2:
        raise HTTPException(400, "Conductor no válido")
    
    # Validar vehículo
    vehiculo = db.query(models.Vehiculo).get(id_vehiculo)
    if not vehiculo or vehiculo.id_hotel != me.id_hotel:
        raise HTTPException(400, "Vehículo no válido")
    
    # Finalizar asignaciones previas del conductor
    asignaciones_previas = (
        db.query(models.ConductorVehiculo)
        .filter(
            models.ConductorVehiculo.id_conductor == id_conductor,
            models.ConductorVehiculo.hora_fin_asignacion.is_(None)
        )
        .all()
    )
    
    ahora = datetime.utcnow()
    for asig in asignaciones_previas:
        asig.hora_fin_asignacion = ahora
    
    # Crear nueva asignación
    nueva = models.ConductorVehiculo(
        id_conductor=id_conductor,
        id_vehiculo=id_vehiculo,
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