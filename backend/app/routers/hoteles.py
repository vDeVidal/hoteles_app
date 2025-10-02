# app/routers/hoteles.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..deps import get_db
from .. import models, schemas
from ..auth_deps import get_current_claims

router = APIRouter(prefix="/hoteles", tags=["hoteles"])


@router.get("", response_model=list[schemas.HotelOut])
def listar_hoteles(
    _: dict = Depends(get_current_claims),
    db: Session = Depends(get_db),
):
    """
    Lista todos los hoteles disponibles (solo id + nombre).
    Requiere autenticación.
    """
    rows = (
        db.query(models.Hotel.id_hotel, models.Hotel.nombre_hotel)
        .filter(models.Hotel.id_estado_actividad == 1)  # solo activos
        .order_by(models.Hotel.nombre_hotel.asc())
        .all()
    )
    return [
        schemas.HotelOut(id_hotel=r.id_hotel, nombre_hotel=r.nombre_hotel)
        for r in rows
    ]


@router.get("/{id_hotel}", response_model=schemas.HotelOut)
def obtener_hotel(
    id_hotel: int,
    db: Session = Depends(get_db),
    _: dict = Depends(get_current_claims),
):
    """
    Obtiene un hotel específico por ID.
    """
    h = db.get(models.Hotel, id_hotel)
    if not h:
        raise HTTPException(404, "Hotel no encontrado")
    return h


@router.post("", response_model=schemas.HotelOut)
def crear_hotel(
    payload: schemas.HotelCreate,
    db: Session = Depends(get_db),
    _: dict = Depends(get_current_claims),
):
    """
    Crea un nuevo hotel (solo para super admin típicamente).
    """
    h = models.Hotel(**payload.model_dump())
    db.add(h)
    db.commit()
    db.refresh(h)
    return h


@router.patch("/{id_hotel}", response_model=schemas.HotelOut)
def actualizar_hotel(
    id_hotel: int,
    payload: schemas.HotelUpdate,
    db: Session = Depends(get_db),
    _: dict = Depends(get_current_claims),
):
    """
    Actualiza un hotel existente.
    """
    h = db.get(models.Hotel, id_hotel)
    if not h:
        raise HTTPException(404, "Hotel no encontrado")
    
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(h, k, v)
    
    db.commit()
    db.refresh(h)
    return h