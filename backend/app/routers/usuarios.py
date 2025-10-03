# app/routers/usuarios.py
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from typing import Optional
from datetime import datetime

from .. import models, schemas
from ..deps import get_db
from ..auth_deps import get_current_claims, require_role
from ..security import get_password_hash  

router = APIRouter(prefix="/usuarios", tags=["usuarios"])


# ===========================
#    CREAR USUARIO (POST)
# ===========================
@router.post("", response_model=schemas.UsuarioOut, status_code=status.HTTP_201_CREATED)
def crear_usuario(
    payload: schemas.UsuarioCreateIn,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims),
):
    """
    Crea un nuevo usuario (conductor o supervisor).
    Solo administradores pueden crear usuarios.
    """
    # 1) Validar que quien llama sea admin
    actor_id = int(claims.get("sub", 0) or 0)
    actor = db.query(models.Usuario).get(actor_id)
    if not actor:
        raise HTTPException(status_code=401, detail="No autenticado")
    role = int(claims.get("role", getattr(actor, "id_tipo_usuario", 0)) or 0)
    if role not in (3, 4):
        raise HTTPException(status_code=403, detail="No tiene permisos para crear usuarios")

    target_tipo = payload.id_tipo_usuario
    if role == 3 and target_tipo != 1:
        raise HTTPException(status_code=403, detail="Un supervisor solo puede crear huéspedes")

    if role == 4:
        hotel_id = payload.id_hotel or getattr(actor, "id_hotel", None)
    else:
        hotel_id = getattr(actor, "id_hotel", None)
        if not hotel_id:
            raise HTTPException(status_code=403, detail="Supervisor sin hotel asignado")
    if not hotel_id:
        raise HTTPException(status_code=400, detail="Debe indicarse id_hotel")

    # 3) Contraseña por defecto
    raw_pw = payload.contrasena_usuario or "12345678"
    hashed = get_password_hash(raw_pw)

    # 4) Construir modelo
    user = models.Usuario(
        nombre_usuario=payload.nombre_usuario,
        apellido1_usuario=payload.apellido1_usuario,
        apellido2_usuario=payload.apellido2_usuario,
        telefono_usuario=payload.telefono_usuario,
        correo_usuario=payload.correo_usuario,
        id_tipo_usuario=payload.id_tipo_usuario,
        id_estado_actividad=payload.id_estado_actividad,
        id_hotel=hotel_id,
        contrasena_usuario=hashed,
        must_change_password=(
            True if payload.must_change_password is None else bool(payload.must_change_password)
        ),
        is_suspended=False,
    )

    # 5) Guardar
    db.add(user)
    try:
        db.commit()
        db.refresh(user)
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="El correo ya está registrado")
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"No se pudo crear el usuario: {e}")

    return user


# ===========================
#   LISTAR USUARIOS (GET)
# ===========================
@router.get("/mios", response_model=list[schemas.UsuarioListOut])
@router.get("/de-mi-hotel", response_model=list[schemas.UsuarioListOut])
def listar_usuarios_mios(
    hotelId: Optional[int] = Query(None, alias="hotelId"),
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims),
):
    """
    Lista usuarios (conductores y supervisores) del hotel.
    - Admin puede especificar hotelId; si no, usa su hotel
    - Otros roles usan su hotel automáticamente
    """
    me = db.query(models.Usuario).get(int(claims.get("sub", 0) or 0))
    role = int(claims.get("role", 0) or 0)

    if role == 4:  # Admin
        selected = hotelId or (me.id_hotel if me else None)
        if not selected:
            raise HTTPException(status_code=400, detail="hotelId es requerido para administrador")
    else:
        if not me or not me.id_hotel:
            raise HTTPException(status_code=403, detail="Usuario sin hotel asignado")
        selected = me.id_hotel

    return _build_listado(db, selected)


def _build_listado(db: Session, selected_hotel: int):
    """Construye el listado de usuarios con nombre completo concatenado."""
    name_expr = func.trim(
        func.concat(
            models.Usuario.nombre_usuario, ' ',
            models.Usuario.apellido1_usuario, ' ',
            func.coalesce(models.Usuario.apellido2_usuario, '')
        )
    ).label("nombre_usuario")

    rows = (
        db.query(
            models.Usuario.id_usuario,
            name_expr,
            models.Usuario.correo_usuario,
            models.Usuario.id_tipo_usuario,
            models.TipoUsuario.nombre_tipo_usuario.label("tipo_usuario_nombre"),
            models.Usuario.id_estado_actividad,
            models.Usuario.is_suspended,
            models.Usuario.suspended_at,
            models.Usuario.suspended_reason,
            models.Usuario.apellido1_usuario,
            models.Usuario.apellido2_usuario,
            models.Usuario.telefono_usuario,
        )
        .join(models.TipoUsuario, models.Usuario.id_tipo_usuario == models.TipoUsuario.id_tipo_usuario)
        .filter(models.Usuario.id_hotel == selected_hotel)
        .filter(models.Usuario.id_tipo_usuario.in_([2, 3]))
        .order_by(models.Usuario.nombre_usuario.asc())
        .all()
    )

    return [
        dict(
            id_usuario=r.id_usuario,
            nombre_usuario=r.nombre_usuario,
            correo_usuario=r.correo_usuario,
            id_tipo_usuario=r.id_tipo_usuario,
            tipo_usuario_nombre=r.tipo_usuario_nombre,
            id_estado_actividad=r.id_estado_actividad,
            disponible=(r.id_estado_actividad == 1) and (not bool(r.is_suspended)),
            inicio_turno=None,
            fin_turno=None,
            is_suspended=bool(r.is_suspended),
            suspended_at=r.suspended_at,
            suspended_reason=r.suspended_reason,
            apellido1_usuario=r.apellido1_usuario,
            apellido2_usuario=r.apellido2_usuario,
            telefono_usuario=r.telefono_usuario,
        )
        for r in rows
    ]


# ===========================
#   ACTUALIZAR USUARIO (PUT)
# ===========================
@router.put("/{id_usuario}", response_model=schemas.UsuarioListOut, dependencies=[Depends(require_role(4))])
def actualizar_usuario(
    id_usuario: int,
    body: schemas.UsuarioUpdate,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims),
):
    """
    Actualiza un usuario existente.
    Solo administradores.
    """
    admin = db.query(models.Usuario).get(int(claims["sub"]))
    role = int(claims.get("role", 0) or 0)

    user = db.query(models.Usuario).get(id_usuario)
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    # Si no es admin, exigir mismo hotel
    if role != 4:
        if not admin or admin.id_hotel is None or user.id_hotel != admin.id_hotel:
            raise HTTPException(status_code=403, detail="Sin permisos sobre este usuario")

    # Validar tipo si viene
    if body.id_tipo_usuario is not None and body.id_tipo_usuario not in (2, 3):
        raise HTTPException(status_code=400, detail="Tipo no permitido")

    # Aplicar cambios
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(user, field, value)

    db.commit()
    db.refresh(user)

    tipo = db.query(models.TipoUsuario).get(user.id_tipo_usuario)
    return schemas.UsuarioListOut(
        id_usuario=user.id_usuario,
        nombre_usuario=user.nombre_usuario,
        correo_usuario=user.correo_usuario,
        id_tipo_usuario=user.id_tipo_usuario,
        tipo_usuario_nombre=tipo.nombre_tipo_usuario if tipo else "",
        id_estado_actividad=user.id_estado_actividad,
        disponible=(user.id_estado_actividad == 1) and not bool(getattr(user, "is_suspended", False)),
        inicio_turno=None,
        fin_turno=None,
        is_suspended=bool(getattr(user, "is_suspended", False)),
        suspended_at=getattr(user, "suspended_at", None),
        suspended_reason=getattr(user, "suspended_reason", None),
        apellido1_usuario=user.apellido1_usuario,
        apellido2_usuario=user.apellido2_usuario,
        telefono_usuario=user.telefono_usuario,
    )


# ===========================
#      SUSPENDER USUARIO
# ===========================
@router.patch("/{id_usuario}/suspender", dependencies=[Depends(require_role(4))])
def suspender_usuario(
    id_usuario: int,
    body: schemas.UsuarioSuspendIn,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims),
):
    """
    Suspende un usuario (conductor o supervisor).
    """
    admin = db.query(models.Usuario).get(int(claims["sub"]))
    role = int(claims.get("role", 0) or 0)

    user = db.query(models.Usuario).get(id_usuario)
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    if role != 4:
        if not admin or admin.id_hotel is None or user.id_hotel != admin.id_hotel:
            raise HTTPException(status_code=403, detail="Sin permisos sobre este usuario")

    if user.id_tipo_usuario not in (2, 3):
        raise HTTPException(status_code=403, detail="Solo choferes y supervisores")

    user.id_estado_actividad = 2  # Inactivo
    user.is_suspended = True
    user.suspended_at = datetime.utcnow()
    user.suspended_reason = body.motivo
    user.suspended_by = admin.id_usuario if admin else None

    db.commit()
    return {"ok": True}


# ===========================
#     REACTIVAR USUARIO
# ===========================
@router.patch("/{id_usuario}/reactivar", dependencies=[Depends(require_role(4))])
def reactivar_usuario(
    id_usuario: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims),
):
    """
    Reactiva un usuario previamente suspendido.
    """
    admin = db.query(models.Usuario).get(int(claims["sub"]))
    role = int(claims.get("role", 0) or 0)

    user = db.query(models.Usuario).get(id_usuario)
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    if role != 4:
        if not admin or admin.id_hotel is None or user.id_hotel != admin.id_hotel:
            raise HTTPException(status_code=403, detail="Sin permisos sobre este usuario")

    user.is_suspended = False
    user.suspended_at = None
    user.suspended_reason = None
    user.suspended_by = None
    user.id_estado_actividad = 1  # Activo

    db.commit()
    return {"ok": True}


# ===========================
#     ELIMINAR USUARIO
# ===========================
@router.delete("/{id_usuario}", dependencies=[Depends(require_role(4))])
def eliminar_usuario(
    id_usuario: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims),
):
    """
    Elimina un usuario (solo si no tiene registros asociados).
    Se recomienda usar suspender en su lugar.
    """
    admin = db.query(models.Usuario).get(int(claims["sub"]))
    if not admin or admin.id_hotel is None:
        raise HTTPException(status_code=403, detail="Admin sin hotel asignado")

    user = db.query(models.Usuario).get(id_usuario)
    if not user or user.id_hotel != admin.id_hotel:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    
    if user.id_tipo_usuario not in (2, 3):
        raise HTTPException(status_code=403, detail="Solo choferes y supervisores")

    try:
        db.delete(user)
        db.commit()
        return {"ok": True}
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="No se puede eliminar: el usuario tiene registros asociados. Suspéndelo en su lugar."
        )