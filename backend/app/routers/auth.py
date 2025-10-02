# app/routers/auth.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app import models, security
from app.deps import get_db
from app.auth_deps import get_current_claims
from app.schemas import LoginIn, TokenOutWithFlags, ChangePasswordIn

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenOutWithFlags)
def login(payload: LoginIn, db: Session = Depends(get_db)):
    """
    Autentica por correo + contraseña y devuelve JWT + flags.
    """
    try:
        # 1) Buscar usuario por correo
        user = (
            db.query(models.Usuario)
            .filter(models.Usuario.correo_usuario == payload.correo)
            .first()
        )
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credenciales inválidas",
            )

        # 2) Verificar contraseña (texto -> hash en DB)
        if not security.verify_password(payload.password, user.contrasena_usuario):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credenciales inválidas",
            )

        # 2.1) Si manejas suspensión suave en DB
        if bool(getattr(user, "is_suspended", False)):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Usuario suspendido",
            )

        # 3) Claims para el token
        super_flag = False
        for attr in ("es_superadmin", "is_superadmin"):
            if hasattr(user, attr):
                v = getattr(user, attr)
                super_flag = bool(v == 1 or v is True or (isinstance(v, str) and v.lower() in ("1", "true", "t", "yes")))
                break

        full_name = " ".join([
            (user.nombre_usuario or "").strip(),
            (user.apellido1_usuario or "").strip(),
            (user.apellido2_usuario or "").strip(),
        ]).strip()

        ROLE_NAMES = {1: "USUARIO", 2: "CONDUCTOR", 3: "SUPERVISOR", 4: "ADMINISTRADOR"}
        role_id = int(user.id_tipo_usuario or 0)
        role_name = ROLE_NAMES.get(role_id, "DESCONOCIDO")

        claims = {
            "sub": str(user.id_usuario),
            "role": role_id,               # clave: úsalo en el cliente
            "role_name": role_name,        # útil en el cliente
            "name": full_name,             # nombre completo para mostrar
            "mustChange": bool(
                getattr(user, "must_change_password", False)
                or getattr(user, "primer_login", False)
            ),
        }

        token = security.create_access_token(claims)

        return {
            "access_token": token,
            "token_type": "bearer",
            "must_change_password": claims["mustChange"],
            # opcional, por comodidad:
            "role": role_id,
            "role_name": role_name,
            "name": full_name,
        }

    except HTTPException:
        raise
    except Exception as e:
        print("[/auth/login] ERROR:", repr(e))
        raise HTTPException(status_code=500, detail="Error interno")


@router.post("/change-password", status_code=204)
def change_password(
    body: ChangePasswordIn,
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims),
):
    """
    Cambia la contraseña del usuario autenticado.
    """
    try:
        user_id = int(claims.get("sub", 0) or 0)
        user = db.query(models.Usuario).get(user_id)
        if not user:
            raise HTTPException(status_code=404, detail="Usuario no encontrado")

        # validar contraseña actual
        if not security.verify_password(body.old_password, user.contrasena_usuario):
            raise HTTPException(status_code=401, detail="Contraseña actual incorrecta")

        # longitud mínima de la nueva contraseña
        if not body.new_password or len(body.new_password) < 8:
            raise HTTPException(status_code=422, detail="Nueva contraseña inválida")

        # actualizar hash y limpiar flag de primer login si corresponde
        user.contrasena_usuario = security.get_password_hash(body.new_password)
        if hasattr(user, "must_change_password"):
            user.must_change_password = False
        if hasattr(user, "primer_login"):
            user.primer_login = False

        db.commit()
        return  # 204 No Content

    except HTTPException:
        raise
    except Exception as e:
        print("[/auth/change-password] ERROR:", repr(e))
        raise HTTPException(status_code=500, detail="Error interno")
