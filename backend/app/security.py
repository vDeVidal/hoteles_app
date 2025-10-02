# app/security.py
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext

from .config import settings

# Ruta de login que entrega el token (tu router la expone como POST /auth/login)
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

# Bcrypt para passwords
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(
    data: Dict[str, Any],
    expires_minutes: Optional[int] = None
) -> str:
    """
    Crea un JWT firmado con SECRET_KEY y ALGORITHM.
    `data` puede incluir: sub (user_id), role (int), hotel_id (opcional), etc.
    """
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=expires_minutes or settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt

def verify_token(token: str = Depends(oauth2_scheme)) -> Dict[str, Any]:
    """
    Dependencia para FastAPI. Decodifica y valida el JWT.
    Devuelve el payload (claims) si es válido, o lanza 401 si es inválido/expirado.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token inválido o expirado",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        # Puedes validar claims obligatorios si quieres:
        # user_id = payload.get("sub")
        # if user_id is None: raise credentials_exception
        return payload  # dict con claims: sub, role, hotel_id, exp, etc.
    except JWTError:
        raise credentials_exception
