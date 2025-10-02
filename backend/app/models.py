# app/models.py
from __future__ import annotations
from typing import List, Optional
from datetime import date, datetime, time

from sqlalchemy import (
    String, Integer, Date, DateTime, Time, ForeignKey, DECIMAL,
    UniqueConstraint, Index, Boolean, text
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from .database import Base


# =========================
#   Catálogos / Estados
# =========================

class EstadoActividad(Base):
    __tablename__ = "estado_actividad"
    id_estado_actividad: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    nombre_estado: Mapped[str] = mapped_column(String(15), nullable=False)

    hoteles: Mapped[List["Hotel"]] = relationship(back_populates="estado_actividad")
    usuarios: Mapped[List["Usuario"]] = relationship(back_populates="estado_actividad")
    conductores: Mapped[List["Conductor"]] = relationship(back_populates="estado_actividad")
    rutas: Mapped[List["Ruta"]] = relationship(back_populates="estado_actividad")


class EstadoVehiculo(Base):
    __tablename__ = "estado_vehiculo"
    id_estado_vehiculo: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    nombre_estado_vehiculo: Mapped[str] = mapped_column(String(15), nullable=False)

    vehiculos: Mapped[List["Vehiculo"]] = relationship(back_populates="estado_vehiculo")


class EstadoViaje(Base):
    __tablename__ = "estado_viaje"
    id_estado_viaje: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    nombre_estado_viaje: Mapped[str] = mapped_column(String(15), nullable=False)

    viajes: Mapped[List["Viaje"]] = relationship(back_populates="estado_viaje")


class EstadosMensajes(Base):
    __tablename__ = "estados_mensajes"
    id_estado_mensaje: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    nombre_estado_mensaje: Mapped[str] = mapped_column(String(15), nullable=False)

    notificaciones: Mapped[List["Notificacion"]] = relationship(back_populates="estado_mensaje")


class TipoUsuario(Base):
    __tablename__ = "tipo_usuario"
    id_tipo_usuario: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    nombre_tipo_usuario: Mapped[str] = mapped_column(String(15), nullable=False)

    usuarios: Mapped[List["Usuario"]] = relationship(back_populates="tipo_usuario")


class Ciudad(Base):
    __tablename__ = "ciudad"
    id_ciudad: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    nombre_ciudad: Mapped[str] = mapped_column(String(20), nullable=False)

    hoteles: Mapped[List["Hotel"]] = relationship(back_populates="ciudad")


class MarcaVehiculo(Base):
    __tablename__ = "marcas_vehiculos"
    id_marca_vehiculo: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    nombre_marca_vehiculo: Mapped[str] = mapped_column(String(50), nullable=False)

    vehiculos: Mapped[List["Vehiculo"]] = relationship(back_populates="marca")


# =========================
#          Núcleo
# =========================

class Hotel(Base):
    __tablename__ = "hoteles"

    id_hotel: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    nombre_hotel: Mapped[str] = mapped_column(String(100), nullable=False)
    direccion_hotel: Mapped[Optional[str]] = mapped_column(String(200))
    email_hotel: Mapped[Optional[str]] = mapped_column(String(40))
    contacto_telefonico_hotel: Mapped[Optional[str]] = mapped_column(String(20))

    id_ciudad: Mapped[int] = mapped_column(ForeignKey("ciudad.id_ciudad"), nullable=False)
    id_estado_actividad: Mapped[int] = mapped_column(ForeignKey("estado_actividad.id_estado_actividad"), nullable=False)

    ciudad: Mapped[Ciudad] = relationship(back_populates="hoteles")
    estado_actividad: Mapped[EstadoActividad] = relationship(back_populates="hoteles")

    rutas: Mapped[List["Ruta"]] = relationship(back_populates="hotel")
    vehiculos: Mapped[List["Vehiculo"]] = relationship(back_populates="hotel")
    usuarios: Mapped[List["Usuario"]] = relationship(back_populates="hotel")
    viajes: Mapped[List["Viaje"]] = relationship(back_populates="hotel")


class Usuario(Base):
    __tablename__ = "usuarios"

    id_usuario: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    nombre_usuario: Mapped[str] = mapped_column(String(30), nullable=False)
    apellido1_usuario: Mapped[str] = mapped_column(String(30), nullable=False)
    apellido2_usuario: Mapped[Optional[str]] = mapped_column(String(30))
    telefono_usuario: Mapped[Optional[str]] = mapped_column(String(15))
    correo_usuario: Mapped[Optional[str]] = mapped_column(String(50), unique=True)
    contrasena_usuario: Mapped[str] = mapped_column(String(100), nullable=False)
    
    # Campos de seguridad y control
    must_change_password: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("0"))
    is_suspended: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("0"))
    suspended_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    suspended_reason: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    suspended_by: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    # Foreign Keys (solo una vez cada uno)
    id_estado_actividad: Mapped[int] = mapped_column(ForeignKey("estado_actividad.id_estado_actividad"), nullable=False)
    id_hotel: Mapped[Optional[int]] = mapped_column(ForeignKey("hoteles.id_hotel"))
    id_tipo_usuario: Mapped[int] = mapped_column(ForeignKey("tipo_usuario.id_tipo_usuario"), nullable=False)

    # Relationships
    estado_actividad: Mapped[EstadoActividad] = relationship(back_populates="usuarios")
    hotel: Mapped[Optional[Hotel]] = relationship(back_populates="usuarios")
    tipo_usuario: Mapped[TipoUsuario] = relationship(back_populates="usuarios")

    conductor: Mapped[Optional["Conductor"]] = relationship(back_populates="usuario", uselist=False)
    notificaciones: Mapped[List["Notificacion"]] = relationship(back_populates="usuario")
    viajes_pedidos: Mapped[List["Viaje"]] = relationship(back_populates="usuario_que_pide")
    asignaciones_realizadas: Mapped[List["AsignacionViajes"]] = relationship(
        back_populates="usuario_asignador", foreign_keys="AsignacionViajes.asignado_a_id_usuario"
    )


class Conductor(Base):
    __tablename__ = "conductores"

    id_conductor: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    id_usuario: Mapped[int] = mapped_column(ForeignKey("usuarios.id_usuario"), nullable=False, unique=True)
    fecha_expiracion_licencia: Mapped[Optional[date]] = mapped_column(Date)
    id_estado_actividad: Mapped[int] = mapped_column(ForeignKey("estado_actividad.id_estado_actividad"), nullable=False)
    fecha_contratacion: Mapped[Optional[date]] = mapped_column(Date)
    numero_viajes_mensuales: Mapped[Optional[int]] = mapped_column(Integer)

    usuario: Mapped[Usuario] = relationship(back_populates="conductor")
    estado_actividad: Mapped[EstadoActividad] = relationship(back_populates="conductores")

    conductor_vehiculo: Mapped[List["ConductorVehiculo"]] = relationship(back_populates="conductor")
    disponibilidades: Mapped[List["DisponibilidadConductores"]] = relationship(back_populates="conductor")
    asignaciones: Mapped[List["AsignacionViajes"]] = relationship(back_populates="conductor")


class Vehiculo(Base):
    __tablename__ = "vehiculos"

    id_vehiculo: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    id_hotel: Mapped[int] = mapped_column(ForeignKey("hoteles.id_hotel"), nullable=False)
    patente: Mapped[str] = mapped_column(String(10), nullable=False, unique=True)
    id_marca_vehiculo: Mapped[int] = mapped_column(ForeignKey("marcas_vehiculos.id_marca_vehiculo"), nullable=False)
    modelo: Mapped[Optional[str]] = mapped_column(String(20))
    anio: Mapped[Optional[int]] = mapped_column(Integer)
    capacidad: Mapped[Optional[int]] = mapped_column(Integer)
    id_estado_vehiculo: Mapped[int] = mapped_column(ForeignKey("estado_vehiculo.id_estado_vehiculo"), nullable=False)

    hotel: Mapped[Hotel] = relationship(back_populates="vehiculos")
    marca: Mapped[MarcaVehiculo] = relationship(back_populates="vehiculos")
    estado_vehiculo: Mapped[EstadoVehiculo] = relationship(back_populates="vehiculos")

    conductor_vehiculo: Mapped[List["ConductorVehiculo"]] = relationship(back_populates="vehiculo")
    asignaciones: Mapped[List["AsignacionViajes"]] = relationship(back_populates="vehiculo")


class Ruta(Base):
    __tablename__ = "rutas"
    __table_args__ = (UniqueConstraint("id_hotel", "nombre_ruta", name="uq_ruta"),)

    id_ruta: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    id_hotel: Mapped[int] = mapped_column(ForeignKey("hoteles.id_hotel"), nullable=False)
    nombre_ruta: Mapped[str] = mapped_column(String(40), nullable=False)
    origen_ruta: Mapped[str] = mapped_column(String(40), nullable=False)
    destino_ruta: Mapped[str] = mapped_column(String(40), nullable=False)
    precio_ruta: Mapped[Optional[float]] = mapped_column(DECIMAL(10, 0))
    duracion_aproximada: Mapped[Optional[int]] = mapped_column(Integer)
    id_estado_actividad: Mapped[int] = mapped_column(ForeignKey("estado_actividad.id_estado_actividad"), nullable=False)

    hotel: Mapped[Hotel] = relationship(back_populates="rutas")
    estado_actividad: Mapped[EstadoActividad] = relationship(back_populates="rutas")

    viajes: Mapped[List["Viaje"]] = relationship(back_populates="ruta")


# =========================
#        Operación
# =========================

class ConductorVehiculo(Base):
    __tablename__ = "conductor_vehiculo"
    __table_args__ = (
        Index("idx_cv_conductor", "id_conductor", "hora_asignacion"),
        Index("idx_cv_vehiculo", "id_vehiculo", "hora_asignacion"),
    )

    id_conductor_vehiculo: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    id_conductor: Mapped[int] = mapped_column(ForeignKey("conductores.id_conductor"), nullable=False)
    id_vehiculo: Mapped[int] = mapped_column(ForeignKey("vehiculos.id_vehiculo"), nullable=False)
    hora_asignacion: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    hora_fin_asignacion: Mapped[Optional[datetime]] = mapped_column(DateTime)

    conductor: Mapped[Conductor] = relationship(back_populates="conductor_vehiculo")
    vehiculo: Mapped[Vehiculo] = relationship(back_populates="conductor_vehiculo")


class DisponibilidadConductores(Base):
    __tablename__ = "disponibilidad_conductores"
    __table_args__ = (Index("idx_disp_conductor", "id_conductor"),)

    id_disponibilidad: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    id_conductor: Mapped[int] = mapped_column(ForeignKey("conductores.id_conductor"), nullable=False)
    dias_disponibles_semanales: Mapped[Optional[int]] = mapped_column(Integer)
    inicio_turno: Mapped[Optional[time]] = mapped_column(Time)
    fin_turno: Mapped[Optional[time]] = mapped_column(Time)

    conductor: Mapped[Conductor] = relationship(back_populates="disponibilidades")


class Viaje(Base):
    __tablename__ = "viajes"
    __table_args__ = (Index("idx_via_estado_fecha", "id_estado_viaje", "agendada_para"),)

    id_viaje: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    id_hotel: Mapped[int] = mapped_column(ForeignKey("hoteles.id_hotel"), nullable=False)
    id_ruta: Mapped[int] = mapped_column(ForeignKey("rutas.id_ruta"), nullable=False)
    pedida_por_id_usuario: Mapped[int] = mapped_column(ForeignKey("usuarios.id_usuario"), nullable=False)
    hora_pedida: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    agendada_para: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    id_estado_viaje: Mapped[int] = mapped_column(ForeignKey("estado_viaje.id_estado_viaje"), nullable=False)

    hotel: Mapped[Hotel] = relationship(back_populates="viajes")
    ruta: Mapped[Ruta] = relationship(back_populates="viajes")
    usuario_que_pide: Mapped[Usuario] = relationship(back_populates="viajes_pedidos", foreign_keys=[pedida_por_id_usuario])
    estado_viaje: Mapped[EstadoViaje] = relationship(back_populates="viajes")

    asignacion: Mapped[Optional["AsignacionViajes"]] = relationship(back_populates="viaje", uselist=False)


class AsignacionViajes(Base):
    __tablename__ = "asignacion_viajes"
    __table_args__ = (
        UniqueConstraint("id_viaje", name="uq_asg_viaje"),
        Index("idx_asg_conductor", "id_conductor", "hora_asignacion"),
    )

    id_asignacion: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    id_viaje: Mapped[int] = mapped_column(ForeignKey("viajes.id_viaje", ondelete="CASCADE"), nullable=False)
    id_conductor: Mapped[int] = mapped_column(ForeignKey("conductores.id_conductor"), nullable=False)
    id_vehiculo: Mapped[Optional[int]] = mapped_column(ForeignKey("vehiculos.id_vehiculo"))
    asignado_a_id_usuario: Mapped[Optional[int]] = mapped_column(ForeignKey("usuarios.id_usuario"))

    hora_asignacion: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    hora_aceptacion: Mapped[Optional[datetime]] = mapped_column(DateTime)
    inicio_viaje: Mapped[Optional[datetime]] = mapped_column(DateTime)
    fin_viaje: Mapped[Optional[datetime]] = mapped_column(DateTime)

    viaje: Mapped[Viaje] = relationship(back_populates="asignacion")
    conductor: Mapped[Conductor] = relationship(back_populates="asignaciones")
    vehiculo: Mapped[Optional[Vehiculo]] = relationship(back_populates="asignaciones")
    usuario_asignador: Mapped[Optional[Usuario]] = relationship(back_populates="asignaciones_realizadas")


class Notificacion(Base):
    __tablename__ = "notificaciones"
    __table_args__ = (Index("idx_not_user_fecha", "id_usuario", "fecha_envio"),)

    id_notificacion: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    id_usuario: Mapped[int] = mapped_column(ForeignKey("usuarios.id_usuario"), nullable=False)
    contenido_notificacion: Mapped[str] = mapped_column(String(500), nullable=False)
    hora_envio: Mapped[Optional[time]] = mapped_column(Time)
    fecha_envio: Mapped[Optional[date]] = mapped_column(Date)
    id_estado_mensaje: Mapped[int] = mapped_column(ForeignKey("estados_mensajes.id_estado_mensaje"), nullable=False)

    usuario: Mapped[Usuario] = relationship(back_populates="notificaciones")
    estado_mensaje: Mapped[EstadosMensajes] = relationship(back_populates="notificaciones")