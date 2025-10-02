# app/deps.py
from typing import Generator, Dict, Any
import os

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from sqlalchemy.orm import Session

# ⬅️ importa tu SessionLocal desde donde lo tengas
from .database import SessionLocal  # ajusta si tu módulo se llama distinto

# Clave y algoritmo para validar el JWT
SECRET_KEY = os.getenv("JWT_SECRET", "changeme")  # ya lo tienes en .env, respeta el nombre
ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")

# Para Swagger; no tiene que existir un /token real, puede ser /auth/login
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

def get_db() -> Generator[Session, None, None]:
    """Entrega una sesión de DB por request."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_current_claims(token: str = Depends(oauth2_scheme)) -> Dict[str, Any]:
    """
    Decodifica el JWT del header Authorization y retorna los claims.
    Lanza 401 si el token es inválido/expirado.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="No autenticado",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        # por ejemplo, payload = {"sub":"2","role":4,"id_hotel":3,...}
        if not isinstance(payload, dict):
            raise credentials_exception
        return payload
    except JWTError:
        raise credentials_exception
