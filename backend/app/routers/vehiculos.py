# app/routers/vehiculos.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from .. import models, schemas
from ..deps import get_db
from ..auth_deps import get_current_claims, require_role

router = APIRouter(prefix="/vehiculos", tags=["vehiculos"])


def _hotel_of_user(db: Session, claims: dict) -> int:
    """Helper: obtiene el hotel del usuario actual."""
    me = db.query(models.Usuario).get(int(claims["sub"]))
    if not me or not me.id_hotel:
        raise HTTPException(403, "Usuario sin hotel")
    return me.id_hotel


@router.get("", response_model=List[schemas.VehiculoOut], dependencies=[Depends(require_role(3))])
def listar_vehiculos(
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Lista vehículos del hotel del usuario actual.
    Requiere rol mínimo: Supervisor (3) o Admin (4).
    """
    hotel_id = _hotel_of_user(db, claims)
    
    q = (
        db.query(
            models.Vehiculo,
            models.MarcaVehiculo.nombre_marca_vehiculo.label("marca_nombre"),
            models.EstadoVehiculo.nombre_estado_vehiculo.label("estado_nombre")
        )
        .join(models.MarcaVehiculo, models.Vehiculo.id_marca_vehiculo == models.MarcaVehiculo.id_marca_vehiculo)
        .join(models.EstadoVehiculo, models.Vehiculo.id_estado_vehiculo == models.EstadoVehiculo.id_estado_vehiculo)
        .filter(models.Vehiculo.id_hotel == hotel_id)
        .order_by(models.Vehiculo.patente.asc())
    )
    rows = q.all()

    out = []
    for v, marca_nombre, estado_nombre in rows:
        out.append(schemas.VehiculoOut(
            id_vehiculo=v.id_vehiculo,
            id_hotel=v.id_hotel,
            patente=v.patente,
            id_marca_vehiculo=v.id_marca_vehiculo,
            modelo=v.modelo,
            anio=v.anio,
            capacidad=v.capacidad,
            id_estado_vehiculo=v.id_estado_vehiculo,
            marca_nombre=marca_nombre,
            estado_nombre=estado_nombre
        ))
    return out


@router.post("", response_model=schemas.VehiculoOut, status_code=status.HTTP_201_CREATED, dependencies=[Depends(require_role(3))])
def crear_vehiculo(
    body: schemas.VehiculoCreateIn,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Crea un nuevo vehículo en el hotel del usuario actual.
    """
    hotel_id = _hotel_of_user(db, claims)

    # Validaciones
    if db.query(models.Vehiculo).filter(models.Vehiculo.patente == body.patente).first():
        raise HTTPException(409, "Patente ya registrada")
    if not db.query(models.MarcaVehiculo).get(body.id_marca_vehiculo):
        raise HTTPException(400, "Marca inválida")
    if not db.query(models.EstadoVehiculo).get(body.id_estado_vehiculo):
        raise HTTPException(400, "Estado inválido")

    v = models.Vehiculo(
        id_hotel=hotel_id,
        patente=body.patente.upper().strip(),
        id_marca_vehiculo=body.id_marca_vehiculo,
        modelo=body.modelo,
        anio=body.anio,
        capacidad=body.capacidad,
        id_estado_vehiculo=body.id_estado_vehiculo
    )
    db.add(v)
    db.commit()
    db.refresh(v)
    
    # Devolver con nombres resueltos
    marca = db.query(models.MarcaVehiculo).get(v.id_marca_vehiculo)
    est = db.query(models.EstadoVehiculo).get(v.id_estado_vehiculo)
    return schemas.VehiculoOut(
        **v.__dict__,
        marca_nombre=marca.nombre_marca_vehiculo if marca else None,
        estado_nombre=est.nombre_estado_vehiculo if est else None
    )


@router.put("/{id_vehiculo}", response_model=schemas.VehiculoOut, dependencies=[Depends(require_role(3))])
def actualizar_vehiculo(
    id_vehiculo: int,
    body: schemas.VehiculoUpdate,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Actualiza un vehículo existente del hotel del usuario.
    """
    hotel_id = _hotel_of_user(db, claims)
    v = db.query(models.Vehiculo).get(id_vehiculo)
    if not v or v.id_hotel != hotel_id:
        raise HTTPException(404, "No encontrado")

    data = body.model_dump(exclude_unset=True)
    
    if "patente" in data and data["patente"]:
        data["patente"] = data["patente"].upper().strip()
        dup = (
            db.query(models.Vehiculo)
            .filter(
                models.Vehiculo.patente == data["patente"],
                models.Vehiculo.id_vehiculo != id_vehiculo
            )
            .first()
        )
        if dup:
            raise HTTPException(409, "Patente duplicada")

    if "id_marca_vehiculo" in data and data["id_marca_vehiculo"]:
        if not db.query(models.MarcaVehiculo).get(data["id_marca_vehiculo"]):
            raise HTTPException(400, "Marca inválida")

    if "id_estado_vehiculo" in data and data["id_estado_vehiculo"]:
        if not db.query(models.EstadoVehiculo).get(data["id_estado_vehiculo"]):
            raise HTTPException(400, "Estado inválido")

    for k, val in data.items():
        setattr(v, k, val)
    
    db.commit()
    db.refresh(v)

    marca = db.query(models.MarcaVehiculo).get(v.id_marca_vehiculo)
    est = db.query(models.EstadoVehiculo).get(v.id_estado_vehiculo)
    return schemas.VehiculoOut(
        **v.__dict__,
        marca_nombre=marca.nombre_marca_vehiculo if marca else None,
        estado_nombre=est.nombre_estado_vehiculo if est else None
    )


@router.delete("/{id_vehiculo}", dependencies=[Depends(require_role(3))])
def eliminar_vehiculo(
    id_vehiculo: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Elimina un vehículo (solo si no tiene asignaciones activas).
    """
    hotel_id = _hotel_of_user(db, claims)
    v = db.query(models.Vehiculo).get(id_vehiculo)
    if not v or v.id_hotel != hotel_id:
        raise HTTPException(404, "No encontrado")

    try:
        db.delete(v)
        db.commit()
        return {"ok": True}
    except Exception:
        db.rollback()
        raise HTTPException(409, "No se puede eliminar: tiene asignaciones asociadas")


# ===========================
#    SUB-ROUTER: MARCAS
# ===========================

@router.get("/marcas", response_model=List[schemas.MarcaVehiculoOut])
def listar_marcas(db: Session = Depends(get_db)):
    """Lista todas las marcas de vehículos disponibles."""
    rows = db.query(models.MarcaVehiculo).order_by(models.MarcaVehiculo.nombre_marca_vehiculo.asc()).all()
    return rows


@router.post("/marcas", response_model=schemas.MarcaVehiculoOut, status_code=status.HTTP_201_CREATED, dependencies=[Depends(require_role(3))])
def crear_marca(
    body: schemas.MarcaVehiculoCreateIn,
    db: Session = Depends(get_db)
):
    """Crea una nueva marca de vehículo."""
    nombre = body.nombre_marca_vehiculo.strip()
    if not nombre:
        raise HTTPException(400, "Nombre requerido")
    if db.query(models.MarcaVehiculo).filter(models.MarcaVehiculo.nombre_marca_vehiculo == nombre).first():
        raise HTTPException(409, "La marca ya existe")
    
    m = models.MarcaVehiculo(nombre_marca_vehiculo=nombre)
    db.add(m)
    db.commit()
    db.refresh(m)
    return m


@router.put("/marcas/{id_marca}", response_model=schemas.MarcaVehiculoOut, dependencies=[Depends(require_role(3))])
def actualizar_marca(
    id_marca: int,
    body: schemas.MarcaVehiculoUpdate,
    db: Session = Depends(get_db)
):
    """Actualiza una marca de vehículo existente."""
    m = db.query(models.MarcaVehiculo).get(id_marca)
    if not m:
        raise HTTPException(404, "No encontrada")
    
    data = body.model_dump(exclude_unset=True)
    if "nombre_marca_vehiculo" in data:
        nuevo = (data["nombre_marca_vehiculo"] or "").strip()
        if not nuevo:
            raise HTTPException(400, "Nombre requerido")
        dup = (
            db.query(models.MarcaVehiculo)
            .filter(
                models.MarcaVehiculo.nombre_marca_vehiculo == nuevo,
                models.MarcaVehiculo.id_marca_vehiculo != id_marca
            )
            .first()
        )
        if dup:
            raise HTTPException(409, "Ya existe otra marca con ese nombre")
        m.nombre_marca_vehiculo = nuevo
    
    db.commit()
    db.refresh(m)
    return m