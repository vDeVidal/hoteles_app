from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from .. import models, schemas
from ..deps import get_db
from ..auth_deps import get_current_claims, require_role

router = APIRouter(prefix="/marcas-vehiculos", tags=["marcas-vehiculos"])

@router.get("", response_model=List[schemas.MarcaVehiculoOut])
def listar_marcas(db: Session = Depends(get_db)):
    rows = db.query(models.MarcaVehiculo).order_by(models.MarcaVehiculo.nombre_marca_vehiculo.asc()).all()
    return rows

@router.post("", response_model=schemas.MarcaVehiculoOut, status_code=status.HTTP_201_CREATED,
             dependencies=[Depends(require_role(3))])  # supervisor o admin
def crear_marca(body: schemas.MarcaVehiculoCreateIn, db: Session = Depends(get_db)):
    nombre = body.nombre_marca_vehiculo.strip()
    if not nombre:
        raise HTTPException(400, "Nombre requerido")
    if db.query(models.MarcaVehiculo).filter(models.MarcaVehiculo.nombre_marca_vehiculo == nombre).first():
        raise HTTPException(409, "La marca ya existe")
    m = models.MarcaVehiculo(nombre_marca_vehiculo=nombre)
    db.add(m); db.commit(); db.refresh(m)
    return m

@router.put("/{id_marca}", response_model=schemas.MarcaVehiculoOut,
            dependencies=[Depends(require_role(3))])
def actualizar_marca(id_marca: int, body: schemas.MarcaVehiculoUpdate, db: Session = Depends(get_db)):
    m = db.query(models.MarcaVehiculo).get(id_marca)
    if not m: raise HTTPException(404, "No encontrada")
    data = body.model_dump(exclude_unset=True)
    if "nombre_marca_vehiculo" in data:
        nuevo = (data["nombre_marca_vehiculo"] or "").strip()
        if not nuevo:
            raise HTTPException(400, "Nombre requerido")
        dup = (db.query(models.MarcaVehiculo)
                 .filter(models.MarcaVehiculo.nombre_marca_vehiculo == nuevo,
                         models.MarcaVehiculo.id_marca_vehiculo != id_marca)
                 .first())
        if dup: raise HTTPException(409, "Ya existe otra marca con ese nombre")
        m.nombre_marca_vehiculo = nuevo
    db.commit(); db.refresh(m)
    return m
