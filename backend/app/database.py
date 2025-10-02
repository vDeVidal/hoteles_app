# app/database.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from .config import settings
import urllib.parse

def _build_db_url() -> str:
    # Prioridad: DATABASE_URL si viene en .env
    if settings.DATABASE_URL:
        return settings.DATABASE_URL

    # Fallback: armar desde componentes (tus variables)
    user = settings.DB_USER
    pwd  = settings.DB_PASSWORD   # <- mappea DB_PASS
    host = settings.DB_HOST
    port = settings.DB_PORT
    name = settings.DB_NAME

    if not user or not name:
        raise RuntimeError(
            "Config DB incompleta: defina DATABASE_URL o bien DB_USER/DB_PASS(DB_PASSWORD)/DB_HOST/DB_PORT/DB_NAME en .env."
        )

    pwd_q = urllib.parse.quote_plus(pwd or "")
    return f"mysql+pymysql://{user}:{pwd_q}@{host}:{port}/{name}?charset=utf8mb4"

SQLALCHEMY_DATABASE_URL = _build_db_url()

# Declarative base para tus modelos
Base = declarative_base()

# Engine y Session
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    pool_pre_ping=True,
    pool_recycle=3600,
    future=True,
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Dependencia para FastAPI
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
