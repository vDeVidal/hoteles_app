# app/routers/kpis.py
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, case, extract, text
from datetime import datetime, timedelta
from typing import Optional

from .. import models
from ..deps import get_db
from ..auth_deps import get_current_claims, require_role, require_any_role


router = APIRouter(prefix="/kpis", tags=["kpis"])


def _hotel_of_user(db: Session, claims: dict) -> int:
    """Helper: obtiene el hotel del usuario actual."""
    me = db.query(models.Usuario).get(int(claims["sub"]))
    if not me or not me.id_hotel:
        raise HTTPException(403, "Usuario sin hotel")
    return me.id_hotel


@router.get("/dashboard", dependencies=[Depends(require_any_role([3, 4]))])
def get_dashboard_kpis(
    fecha_desde: Optional[datetime] = Query(None),
    fecha_hasta: Optional[datetime] = Query(None),
    hotelId: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)

):
    """
    Obtiene KPIs principales del dashboard para Supervisor y Admin.
    
    Métricas:
    - Total de viajes (por estado)
    - Viajes hoy
    - Conductores disponibles
    - Vehículos disponibles
    - Tiempo promedio de viaje
    - Rutas más utilizadas
    """
    role = int(claims.get("role", 0))
    if role == 4 and hotelId is not None:      # 4 = Admin
        hotel_id = int(hotelId)
    else:
        hotel_id = _hotel_of_user(db, claims)
    
    # Fechas por defecto: último mes
    if not fecha_desde:
        fecha_desde = datetime.utcnow() - timedelta(days=30)
    if not fecha_hasta:
        fecha_hasta = datetime.utcnow()
    
    # === VIAJES POR ESTADO ===
    viajes_por_estado = (
        db.query(
            models.EstadoViaje.nombre_estado_viaje,
            func.count(models.Viaje.id_viaje).label("total")
        )
        .join(models.EstadoViaje, models.Viaje.id_estado_viaje == models.EstadoViaje.id_estado_viaje)
        .filter(
            models.Viaje.id_hotel == hotel_id,
            models.Viaje.agendada_para.between(fecha_desde, fecha_hasta)
        )
        .group_by(models.EstadoViaje.nombre_estado_viaje)
        .all()
    )
    
    # === VIAJES HOY ===
    hoy_inicio = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    hoy_fin = hoy_inicio + timedelta(days=1)
    
    viajes_hoy = (
        db.query(func.count(models.Viaje.id_viaje))
        .filter(
            models.Viaje.id_hotel == hotel_id,
            models.Viaje.agendada_para.between(hoy_inicio, hoy_fin)
        )
        .scalar()
    )
    
    # === CONDUCTORES DISPONIBLES ===
    conductores_disponibles = (
        db.query(func.count(models.Usuario.id_usuario))
        .filter(
            models.Usuario.id_hotel == hotel_id,
            models.Usuario.id_tipo_usuario == 2,  # Conductor
            models.Usuario.id_estado_actividad == 1,  # Activo
            models.Usuario.is_suspended == False
        )
        .scalar()
    )
    
    # === VEHÍCULOS DISPONIBLES ===
    vehiculos_disponibles = (
        db.query(func.count(models.Vehiculo.id_vehiculo))
        .filter(
            models.Vehiculo.id_hotel == hotel_id,
            models.Vehiculo.id_estado_vehiculo == 1  # Activo
        )
        .scalar()
    )
    
    # === TIEMPO PROMEDIO DE VIAJE ===
    tiempo_promedio = (
        db.query(
            func.avg(
                func.timestampdiff(
                    text("MINUTE"),
                    models.AsignacionViajes.inicio_viaje,
                    models.AsignacionViajes.fin_viaje
                )
            )
        )
        .join(models.Viaje, models.AsignacionViajes.id_viaje == models.Viaje.id_viaje)
        .filter(
            models.Viaje.id_hotel == hotel_id,
            models.AsignacionViajes.inicio_viaje.isnot(None),
            models.AsignacionViajes.fin_viaje.isnot(None),
            models.Viaje.agendada_para.between(fecha_desde, fecha_hasta)
        )
        .scalar()
    )
    
    # === RUTAS MÁS UTILIZADAS (Top 5) ===
    rutas_top = (
        db.query(
            models.Ruta.nombre_ruta,
            func.count(models.Viaje.id_viaje).label("total_viajes")
        )
        .join(models.Viaje, models.Ruta.id_ruta == models.Viaje.id_ruta)
        .filter(
            models.Viaje.id_hotel == hotel_id,
            models.Viaje.agendada_para.between(fecha_desde, fecha_hasta)
        )
        .group_by(models.Ruta.nombre_ruta)
        .order_by(func.count(models.Viaje.id_viaje).desc())
        .limit(5)
        .all()
    )
    
    return {
        "periodo": {
            "desde": fecha_desde.isoformat(),
            "hasta": fecha_hasta.isoformat()
        },
        "viajes": {
            "por_estado": [
                {"estado": est, "total": total}
                for est, total in viajes_por_estado
            ],
            "hoy": viajes_hoy or 0,
            "total_periodo": sum(t for _, t in viajes_por_estado)
        },
        "recursos": {
            "conductores_disponibles": conductores_disponibles or 0,
            "vehiculos_disponibles": vehiculos_disponibles or 0
        },
        "desempeño": {
            "tiempo_promedio_minutos": round(tiempo_promedio, 2) if tiempo_promedio else 0,
            "rutas_mas_usadas": [
                {"ruta": nombre, "viajes": total}
                for nombre, total in rutas_top
            ]
        }
    }


@router.get("/conductores", dependencies=[Depends(require_any_role([3, 4]))])
def get_conductores_stats(
    hotelId: Optional[int] = Query(None),
    fecha_desde: Optional[datetime] = Query(None),
    fecha_hasta: Optional[datetime] = Query(None),
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Estadísticas de conductores:
    - Viajes completados por conductor
    - Tasa de aceptación
    - Tiempo promedio de viaje
    """
    role = int(claims.get("role", 0))
    if role == 4 and hotelId is not None:
        hotel_id = int(hotelId)
    else:
        hotel_id = _hotel_of_user(db, claims)
        
    if not fecha_desde:
        fecha_desde = datetime.utcnow() - timedelta(days=30)
    if not fecha_hasta:
        fecha_hasta = datetime.utcnow()
    
    stats = (
        db.query(
            models.Usuario.id_usuario,
            func.concat(
                models.Usuario.nombre_usuario, ' ',
                models.Usuario.apellido1_usuario
            ).label("nombre_completo"),
            func.count(models.AsignacionViajes.id_asignacion).label("viajes_asignados"),
            func.sum(
                case((models.AsignacionViajes.hora_aceptacion.isnot(None), 1), else_=0)
            ).label("viajes_aceptados"),
            func.sum(
                case((models.Viaje.id_estado_viaje == 5, 1), else_=0)
            ).label("viajes_completados"),
            func.avg(
                func.timestampdiff(
                    text("MINUTE"),
                    models.AsignacionViajes.inicio_viaje,
                    models.AsignacionViajes.fin_viaje
                )
            ).label("tiempo_promedio")
        )
        .join(models.AsignacionViajes, models.Usuario.id_usuario == models.AsignacionViajes.id_conductor)
        .join(models.Viaje, models.AsignacionViajes.id_viaje == models.Viaje.id_viaje)
        .filter(
            models.Usuario.id_hotel == hotel_id,
            models.Usuario.id_tipo_usuario == 2,
            models.Viaje.agendada_para.between(fecha_desde, fecha_hasta)
        )
        .group_by(models.Usuario.id_usuario, models.Usuario.nombre_usuario, models.Usuario.apellido1_usuario)
        .order_by(func.count(models.AsignacionViajes.id_asignacion).desc())
        .all()
    )
    
    return {
        "periodo": {
            "desde": fecha_desde.isoformat(),
            "hasta": fecha_hasta.isoformat()
        },
        "conductores": [
            {
                "id_conductor": row.id_usuario,
                "nombre": row.nombre_completo,
                "viajes_asignados": row.viajes_asignados or 0,
                "viajes_aceptados": row.viajes_aceptados or 0,
                "viajes_completados": row.viajes_completados or 0,
                "tasa_aceptacion": round(
                    (row.viajes_aceptados / row.viajes_asignados * 100)
                    if row.viajes_asignados > 0 else 0,
                    2
                ),
                "tiempo_promedio_minutos": round(row.tiempo_promedio, 2) if row.tiempo_promedio else 0
            }
            for row in stats
        ]
    }


@router.get("/viajes-por-dia", dependencies=[Depends(require_any_role([3, 4]))])
def get_viajes_por_dia(
    dias: int = Query(30, description="Número de días hacia atrás"),
    hotelId: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    claims: dict = Depends(get_current_claims)
):
    """
    Viajes por día (útil para gráficos).
    Devuelve array con fecha y cantidad de viajes.
    """
    role = int(claims.get("role", 0))
    if role == 4 and hotelId is not None:
        hotel_id = int(hotelId)
    else:
        hotel_id = _hotel_of_user(db, claims)


    fecha_desde = datetime.utcnow() - timedelta(days=dias)
    

    
    resultado = (
        db.query(
            func.date(models.Viaje.agendada_para).label("fecha"),
            func.count(models.Viaje.id_viaje).label("total")
        )
        .filter(
            models.Viaje.id_hotel == hotel_id,
            models.Viaje.agendada_para >= fecha_desde
        )
        .group_by(func.date(models.Viaje.agendada_para))
        .order_by(func.date(models.Viaje.agendada_para).asc())
        .all()
    )
    
    return {
        "datos": [
            {"fecha": fecha.strftime("%Y-%m-%d"), "total": total}
            for fecha, total in resultado
        ]
    }

