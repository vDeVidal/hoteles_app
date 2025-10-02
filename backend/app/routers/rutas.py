# app/routers/rutas.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from .. import models, schemas
from ..deps import get_db
from ..auth_deps import get_current_claims, require_role

router = APIRouter(prefix="/rutas", tags=["rutas"])


def _hotel_of_user(db: Session, claims: dict) -> int:
    """Helper: obtiene el hotel del usuario actual."""
    me = db.query(models.Usuario).get(int(claims["sub"]))
    if not me or not me.id_hotel:
        raise HTTPException(403, "Usuario sin hotel")
    return me.id_hotel


@router.get("", response_model=List[schemas.RutaOut], dependencies=[Depends(require_role(3))])
def listar_rutas(
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Lista todas las rutas del hotel del usuario actual.
    Solo rutas activas (id_estado_actividad = 1).
    Requiere rol mínimo: Supervisor (3).
    """
    hotel_id = _hotel_of_user(db, claims)
    return (
        db.query(models.Ruta)
        .filter(models.Ruta.id_hotel == hotel_id)
        .filter(models.Ruta.id_estado_actividad == 1)
        .order_by(models.Ruta.nombre_ruta.asc())
        .all()
    )


@router.get("/{id_ruta}", response_model=schemas.RutaOut, dependencies=[Depends(require_role(3))])
def obtener_ruta(
    id_ruta: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Obtiene una ruta específica por ID.
    Valida que pertenezca al hotel del usuario.
    """
    hotel_id = _hotel_of_user(db, claims)
    ruta = db.query(models.Ruta).get(id_ruta)
    
    if not ruta:
        raise HTTPException(404, "Ruta no encontrada")
    if ruta.id_hotel != hotel_id:
        raise HTTPException(403, "Sin acceso a esta ruta")
    
    return ruta


@router.post("", response_model=schemas.RutaOut, status_code=status.HTTP_201_CREATED, dependencies=[Depends(require_role(3))])
def crear_ruta(
    body: schemas.RutaCreateIn,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Crea una nueva ruta en el hotel del usuario actual.
    """
    hotel_id = _hotel_of_user(db, claims)
    
    # Validar que no exista otra ruta con el mismo nombre en este hotel
    existe = (
        db.query(models.Ruta)
        .filter(
            models.Ruta.id_hotel == hotel_id,
            models.Ruta.nombre_ruta == body.nombre_ruta
        )
        .first()
    )
    if existe:
        raise HTTPException(409, "Ya existe una ruta con ese nombre en este hotel")
    
    r = models.Ruta(
        id_hotel=hotel_id,
        nombre_ruta=body.nombre_ruta,
        origen_ruta=body.origen_ruta,
        destino_ruta=body.destino_ruta,
        precio_ruta=body.precio_ruta,
        duracion_aproximada=body.duracion_aproximada,
        id_estado_actividad=body.id_estado_actividad,
    )
    db.add(r)
    db.commit()
    db.refresh(r)
    return r


@router.put("/{id_ruta}", response_model=schemas.RutaOut, dependencies=[Depends(require_role(3))])
def actualizar_ruta(
    id_ruta: int,
    body: schemas.RutaUpdate,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Actualiza una ruta existente.
    """
    hotel_id = _hotel_of_user(db, claims)
    ruta = db.query(models.Ruta).get(id_ruta)
    
    if not ruta:
        raise HTTPException(404, "Ruta no encontrada")
    if ruta.id_hotel != hotel_id:
        raise HTTPException(403, "Sin acceso a esta ruta")
    
    # Si cambia el nombre, validar unicidad
    data = body.model_dump(exclude_unset=True)
    if "nombre_ruta" in data:
        existe = (
            db.query(models.Ruta)
            .filter(
                models.Ruta.id_hotel == hotel_id,
                models.Ruta.nombre_ruta == data["nombre_ruta"],
                models.Ruta.id_ruta != id_ruta
            )
            .first()
        )
        if existe:
            raise HTTPException(409, "Ya existe otra ruta con ese nombre")
    
    for k, v in data.items():
        setattr(ruta, k, v)
    
    db.commit()
    db.refresh(ruta)
    return ruta


@router.delete("/{id_ruta}", dependencies=[Depends(require_role(3))])
def eliminar_ruta(
    id_ruta: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Elimina una ruta (solo si no tiene viajes asociados).
    Recomendable usar inactivación en lugar de eliminar.
    """
    hotel_id = _hotel_of_user(db, claims)
    ruta = db.query(models.Ruta).get(id_ruta)
    
    if not ruta:
        raise HTTPException(404, "Ruta no encontrada")
    if ruta.id_hotel != hotel_id:
        raise HTTPException(403, "Sin acceso a esta ruta")
    
    # Verificar si tiene viajes asociados
    tiene_viajes = db.query(models.Viaje).filter(models.Viaje.id_ruta == id_ruta).first()
    if tiene_viajes:
        raise HTTPException(409, "No se puede eliminar: tiene viajes asociados. Inactívala en su lugar.")
    
    try:
        db.delete(ruta)
        db.commit()
        return {"ok": True}
    except Exception:
        db.rollback()
        raise HTTPException(500, "Error al eliminar la ruta")