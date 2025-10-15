# app/schemas.py
from __future__ import annotations
from typing import Optional, List
from decimal import Decimal  # ← AGREGADO
from pydantic import BaseModel, EmailStr, field_validator
from datetime import date, datetime, time

# =========================
#      Auth / Sesión
# =========================

class LoginIn(BaseModel):
    correo: str
    password: str

class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"

class TokenOutWithFlags(TokenOut):
    role: int
    role_name: str = ""
    name: str = ""
    must_change_password: bool = False

class ChangePasswordIn(BaseModel):
    old_password: str
    new_password: str

# =========================
#   Catálogos / Estados
# =========================

class EstadoActividadOut(BaseModel):
    id_estado_actividad: int
    nombre_estado: str
    class Config: 
        from_attributes = True

class EstadoVehiculoOut(BaseModel):
    id_estado_vehiculo: int
    nombre_estado_vehiculo: str
    class Config: 
        from_attributes = True

class EstadoViajeOut(BaseModel):
    id_estado_viaje: int
    nombre_estado_viaje: str
    class Config: 
        from_attributes = True

class EstadoMensajeOut(BaseModel):
    id_estado_mensaje: int
    nombre_estado_mensaje: str
    class Config: 
        from_attributes = True

class TipoUsuarioOut(BaseModel):
    id_tipo_usuario: int
    nombre_tipo_usuario: str
    class Config: 
        from_attributes = True

class CiudadOut(BaseModel):
    id_ciudad: int
    nombre_ciudad: str
    class Config: 
        from_attributes = True

class MarcaVehiculoOut(BaseModel):
    id_marca_vehiculo: int
    nombre_marca_vehiculo: str
    class Config: 
        from_attributes = True

# =========================
#          Hoteles
# =========================

class HotelCreate(BaseModel):
    nombre_hotel: str
    direccion_hotel: Optional[str] = None
    email_hotel: Optional[EmailStr] = None
    contacto_telefonico_hotel: Optional[str] = None
    id_ciudad: int
    id_estado_actividad: int

class HotelUpdate(BaseModel):
    nombre_hotel: Optional[str] = None
    direccion_hotel: Optional[str] = None
    email_hotel: Optional[EmailStr] = None
    contacto_telefonico_hotel: Optional[str] = None
    id_ciudad: Optional[int] = None
    id_estado_actividad: Optional[int] = None

class HotelOut(BaseModel):
    id_hotel: int
    nombre_hotel: str
    class Config: 
        from_attributes = True

# =========================
#         Usuarios
# =========================

class UsuarioCreateIn(BaseModel):
    nombre_usuario: str
    apellido1_usuario: str
    apellido2_usuario: Optional[str] = None
    telefono_usuario: Optional[str] = None
    correo_usuario: EmailStr
    id_tipo_usuario: int  # 2=Conductor, 3=Supervisor
    id_estado_actividad: int = 1  # 1=Activo
    id_hotel: Optional[int] = None
    contrasena_usuario: Optional[str] = None
    must_change_password: Optional[bool] = True

    @field_validator("id_tipo_usuario")
    @classmethod
    def valida_tipo(cls, v):
        if v not in (1, 2, 3):
            raise ValueError(
                "id_tipo_usuario debe ser 1 (Huésped), 2 (Conductor) o 3 (Supervisor)"
            )
        return v

    @field_validator("id_estado_actividad")
    @classmethod
    def valida_estado(cls, v):
        if v not in (1, 2):
            raise ValueError("id_estado_actividad debe ser 1 (Activo) o 2 (Inactivo)")
        return v

class UsuarioUpdate(BaseModel):
    nombre_usuario: Optional[str] = None
    apellido1_usuario: Optional[str] = None
    apellido2_usuario: Optional[str] = None
    telefono_usuario: Optional[str] = None
    correo_usuario: Optional[EmailStr] = None
    id_tipo_usuario: Optional[int] = None
    id_estado_actividad: Optional[int] = None

class UsuarioSuspendIn(BaseModel):
    motivo: Optional[str] = None

class UsuarioOut(BaseModel):
    id_usuario: int
    nombre_usuario: str
    apellido1_usuario: str
    apellido2_usuario: Optional[str]
    telefono_usuario: Optional[str]
    correo_usuario: Optional[str]
    id_estado_actividad: int
    id_hotel: Optional[int]
    id_tipo_usuario: int
    class Config: 
        from_attributes = True

class UsuarioListOut(BaseModel):
    id_usuario: int
    nombre_usuario: str
    correo_usuario: str
    id_tipo_usuario: int
    tipo_usuario_nombre: str
    id_estado_actividad: int
    disponible: bool
    inicio_turno: Optional[datetime] = None
    fin_turno: Optional[datetime] = None
    is_suspended: bool = False
    suspended_at: Optional[datetime] = None
    suspended_reason: Optional[str] = None
    apellido1_usuario: Optional[str] = None
    apellido2_usuario: Optional[str] = None
    telefono_usuario: Optional[str] = None

# =========================
#        Conductores
# =========================

class ConductorCreate(BaseModel):
    id_usuario: int
    fecha_expiracion_licencia: Optional[date] = None
    id_estado_actividad: int
    fecha_contratacion: Optional[date] = None
    numero_viajes_mensuales: Optional[int] = 0

class ConductorOut(BaseModel):
    id_conductor: int
    id_usuario: int
    fecha_expiracion_licencia: Optional[date]
    id_estado_actividad: int
    fecha_contratacion: Optional[date]
    numero_viajes_mensuales: Optional[int]
    class Config: 
        from_attributes = True

# =========================
#    Marcas de Vehículos
# =========================

class MarcaVehiculoCreateIn(BaseModel):
    nombre_marca_vehiculo: str

class MarcaVehiculoUpdate(BaseModel):
    nombre_marca_vehiculo: Optional[str] = None

# =========================
#        Vehículos
# =========================

class VehiculoCreateIn(BaseModel):
    patente: str
    id_marca_vehiculo: int
    modelo: Optional[str] = None
    anio: Optional[int] = None
    capacidad: Optional[int] = None
    id_estado_vehiculo: int = 1

class VehiculoUpdate(BaseModel):
    patente: Optional[str] = None
    id_marca_vehiculo: Optional[int] = None
    modelo: Optional[str] = None
    anio: Optional[int] = None
    capacidad: Optional[int] = None
    id_estado_vehiculo: Optional[int] = None

class VehiculoOut(BaseModel):
    id_vehiculo: int
    id_hotel: int
    patente: str
    id_marca_vehiculo: int
    modelo: Optional[str]
    anio: Optional[int]
    capacidad: Optional[int]
    id_estado_vehiculo: int
    marca_nombre: Optional[str] = None
    estado_nombre: Optional[str] = None
    class Config: 
        from_attributes = True

# =========================
#          Rutas
# =========================

class RutaCreateIn(BaseModel):
    nombre_ruta: str
    origen_ruta: str
    destino_ruta: str
    precio_ruta: Optional[float] = None
    duracion_aproximada: Optional[int] = None
    id_estado_actividad: int = 1

class RutaUpdate(BaseModel):
    nombre_ruta: Optional[str] = None
    origen_ruta: Optional[str] = None
    destino_ruta: Optional[str] = None
    precio_ruta: Optional[float] = None
    duracion_aproximada: Optional[int] = None
    id_estado_actividad: Optional[int] = None

class RutaOut(BaseModel):
    id_ruta: int
    id_hotel: int
    nombre_ruta: str
    origen_ruta: str
    destino_ruta: str
    precio_ruta: Optional[float]
    duracion_aproximada: Optional[int]
    id_estado_actividad: int
    class Config: 
        from_attributes = True

# =========================
#      Disponibilidad
# =========================

class DisponibilidadCreate(BaseModel):
    id_conductor: int
    dias_disponibles_semanales: Optional[int] = None
    inicio_turno: Optional[time] = None
    fin_turno: Optional[time] = None

class DisponibilidadOut(BaseModel):
    id_disponibilidad: int
    id_conductor: int
    dias_disponibles_semanales: Optional[int]
    inicio_turno: Optional[time]
    fin_turno: Optional[time]
    class Config: 
        from_attributes = True

# =========================
#   Conductor—Vehículo
# =========================

class ConductorVehiculoCreate(BaseModel):
    id_conductor: int
    id_vehiculo: int
    hora_asignacion: datetime
    hora_fin_asignacion: Optional[datetime] = None

class ConductorVehiculoOut(BaseModel):
    id_conductor_vehiculo: int
    id_conductor: int
    id_vehiculo: int
    hora_asignacion: datetime
    hora_fin_asignacion: Optional[datetime]
    class Config: 
        from_attributes = True

# =========================
#          Viajes
# =========================

class ViajeCreateIn(BaseModel):
    id_ruta: int
    pedida_por_id_usuario: Optional[int] = None  # puede venir del token
    agendada_para: datetime

class ViajeOut(BaseModel):
    id_viaje: int
    id_hotel: int
    id_ruta: int
    pedida_por_id_usuario: int
    hora_pedida: datetime
    agendada_para: datetime
    id_estado_viaje: int
    
    # ✅ Información adicional del solicitante
    solicitante_nombre: Optional[str] = None
    solicitante_telefono: Optional[str] = None
    
    # ✅ Información de la ruta
    ruta_nombre: Optional[str] = None
    origen_ruta: Optional[str] = None
    destino_ruta: Optional[str] = None
    
    # ✅ Información del conductor (si está asignado)
    conductor: Optional[dict] = None
    
    # ✅ Información del vehículo (si está asignado)
    vehiculo: Optional[dict] = None
    
    class Config: 
        from_attributes = True

# =========================
#   Asignaciones de Viaje
# =========================

class AsignacionCreate(BaseModel):
    id_viaje: int
    id_conductor: int
    id_vehiculo: Optional[int] = None
    asignado_a_id_usuario: Optional[int] = None
    hora_asignacion: datetime
    hora_aceptacion: Optional[datetime] = None
    inicio_viaje: Optional[datetime] = None
    fin_viaje: Optional[datetime] = None

class AsignacionOut(BaseModel):
    id_asignacion: int
    id_viaje: int
    id_conductor: int
    id_vehiculo: Optional[int]
    asignado_a_id_usuario: Optional[int]
    hora_asignacion: datetime
    hora_aceptacion: Optional[datetime]
    inicio_viaje: Optional[datetime]
    fin_viaje: Optional[datetime]
    class Config: 
        from_attributes = True

# =========================
#      Notificaciones
# =========================

class NotificacionCreate(BaseModel):
    id_usuario: int
    contenido_notificacion: str
    hora_envio: Optional[time] = None
    fecha_envio: Optional[date] = None
    id_estado_mensaje: int

class NotificacionOut(BaseModel):
    id_notificacion: int
    id_usuario: int
    contenido_notificacion: str
    hora_envio: Optional[time]
    fecha_envio: Optional[date]
    id_estado_mensaje: int
    class Config: 
        from_attributes = True

# =========================
#    Conductor-Vehículo
# =========================

class ConductorVehiculoAssignIn(BaseModel):
    id_conductor: int
    id_vehiculo: int