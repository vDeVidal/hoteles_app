# app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .config import settings

# Importar routers
from .routers import (
    auth,
    hoteles,
    usuarios,
    vehiculos,
    rutas,
    viajes,
    asignaciones,
    conductor_vehiculo,
    kpis,
    notificaciones,
)

app = FastAPI(
    title="Hotel Transport API",
    description="API para gestión de transporte en hoteles",
    version="1.0.0"
)

# Configurar CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list or ["*"],  # '*' en .env -> ["*"] aquí
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Registrar routers
app.include_router(auth.router)
app.include_router(hoteles.router)
app.include_router(usuarios.router)
app.include_router(vehiculos.router)
app.include_router(rutas.router)
app.include_router(viajes.router)
app.include_router(asignaciones.router)
app.include_router(conductor_vehiculo.router)
app.include_router(kpis.router)
app.include_router(notificaciones.router)

@app.get("/")
def root():
    return {"message": "Hotel Transport API - OK"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}