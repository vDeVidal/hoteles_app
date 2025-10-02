// lib/services/api_client.dart
import 'package:dio/dio.dart';
import 'auth_service.dart';

class ApiClient {
  ApiClient() : _dio = AuthService.dioWithAuth();

  final Dio _dio;

  // ---------------------- Utils ----------------------
  Never _throw(DioException e) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    throw Exception('HTTP $code: $data');
  }

  // ---------------------- Hoteles ----------------------
  Future<List<dynamic>> listarHoteles() async {
    try {
      final res = await _dio.get('/hoteles');
      return (res.data as List).cast<dynamic>();
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<Map<String, dynamic>> miHotel() async {
    try {
      final res = await _dio.get('/hoteles/mi');
      if (res.statusCode == 200 && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      throw Exception('No se pudo obtener mi hotel');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  // ---------------------- Auth ----------------------
  Future<void> cambiarPassword(String oldPw, String newPw) async {
    try {
      await _dio.post('/auth/change-password', data: {
        'old_password': oldPw,
        'new_password': newPw,
      });
    } on DioException catch (e) {
      _throw(e);
    }
  }

  // ---------------------- Usuarios ----------------------
  Future<List<dynamic>> listarUsuariosDeMiHotel(int? hotelId) async {
    try {
      final res = await _dio.get(
        '/usuarios/mios',
        queryParameters: hotelId != null ? {'hotelId': hotelId} : null,
      );
      return (res.data as List).cast<dynamic>();
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<Map<String, dynamic>> crearUsuario(Map<String, dynamic> body) async {
    try {
      final res = await _dio.post('/usuarios', data: body);
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<void> actualizarUsuario(int id, Map<String, dynamic> body) async {
    try {
      await _dio.put('/usuarios/$id', data: body);
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<void> suspenderUsuario(int id, String motivo) async {
    try {
      await _dio.patch('/usuarios/$id/suspender', data: {'motivo': motivo});
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<void> reactivarUsuario(int id) async {
    try {
      await _dio.patch('/usuarios/$id/reactivar');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  // ---------------------- Vehículos ----------------------
  Future<List<dynamic>> listarVehiculos() async {
    try {
      final res = await _dio.get('/vehiculos');
      return (res.data as List).cast<dynamic>();
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<Map<String, dynamic>> crearVehiculo(Map<String, dynamic> body) async {
    try {
      final res = await _dio.post('/vehiculos', data: body);
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<void> actualizarVehiculo(int id, Map<String, dynamic> body) async {
    try {
      await _dio.put('/vehiculos/$id', data: body);
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<void> eliminarVehiculo(int id) async {
    try {
      await _dio.delete('/vehiculos/$id');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  // ----- Marcas de vehículo -----
  Future<List<dynamic>> listarMarcasVehiculo() async {
    try {
      final res = await _dio.get('/vehiculos/marcas');
      return (res.data as List).cast<dynamic>();
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<Map<String, dynamic>> crearMarcaVehiculo(String nombre) async {
    try {
      final res = await _dio.post('/vehiculos/marcas', data: {
        'nombre_marca_vehiculo': nombre.trim(),
      });
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      _throw(e);
    }
  }

  // ---------------------- Rutas ----------------------
  Future<List<dynamic>> listarRutas(int? hotelId) async {
    try {
      final res = await _dio.get('/rutas');
      return (res.data as List).cast<dynamic>();
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<Map<String, dynamic>> crearRuta(Map<String, dynamic> body) async {
    try {
      final res = await _dio.post('/rutas', data: body);
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<void> actualizarRuta(int id, Map<String, dynamic> body) async {
    try {
      await _dio.put('/rutas/$id', data: body);
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<void> eliminarRuta(int id) async {
    try {
      await _dio.delete('/rutas/$id');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  // ---------------------- Viajes ----------------------
  Future<List<dynamic>> listarViajes({int? estado, String? fechaDesde, String? fechaHasta}) async {
    try {
      final params = <String, dynamic>{};
      if (estado != null) params['estado'] = estado;
      if (fechaDesde != null) params['fecha_desde'] = fechaDesde;
      if (fechaHasta != null) params['fecha_hasta'] = fechaHasta;

      final res = await _dio.get('/viajes', queryParameters: params.isNotEmpty ? params : null);
      return (res.data as List).cast<dynamic>();
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<Map<String, dynamic>> crearViaje(Map<String, dynamic> body) async {
    try {
      final res = await _dio.post('/viajes', data: body);
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<void> asignarViaje(int idViaje, int idConductor, int idVehiculo) async {
    try {
      await _dio.post('/viajes/$idViaje/asignar', data: {
        'id_conductor': idConductor,
        'id_vehiculo': idVehiculo,
      });
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<void> aceptarViaje(int idViaje) async {
    try {
      await _dio.patch('/viajes/$idViaje/aceptar');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<void> rechazarViaje(int idViaje) async {
    try {
      await _dio.patch('/viajes/$idViaje/rechazar');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<void> iniciarViaje(int idViaje) async {
    try {
      await _dio.patch('/viajes/$idViaje/iniciar');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<void> finalizarViaje(int idViaje) async {
    try {
      await _dio.patch('/viajes/$idViaje/finalizar');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<void> cancelarViaje(int idViaje) async {
    try {
      await _dio.delete('/viajes/$idViaje');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  // ---------------------- KPIs ----------------------
  Future<Map<String, dynamic>> getDashboardKpis({String? fechaDesde, String? fechaHasta, int? hotelId}) async {
    try {
      final params = <String, dynamic>{};
      if (fechaDesde != null) params['fecha_desde'] = fechaDesde;
      if (fechaHasta != null) params['fecha_hasta'] = fechaHasta;
      if (hotelId != null) params['hotelId'] = hotelId;

      final res = await _dio.get('/kpis/dashboard', queryParameters: params.isNotEmpty ? params : null);
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<Map<String, dynamic>> getConductoresStats({String? fechaDesde, String? fechaHasta}) async {
    try {
      final params = <String, dynamic>{};
      if (fechaDesde != null) params['fecha_desde'] = fechaDesde;
      if (fechaHasta != null) params['fecha_hasta'] = fechaHasta;

      final res = await _dio.get('/kpis/conductores', queryParameters: params.isNotEmpty ? params : null);
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<Map<String, dynamic>> getViajesPorDia(int dias) async {
    try {
      final res = await _dio.get('/kpis/viajes-por-dia', queryParameters: {'dias': dias});
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      _throw(e);
    }
  }

  // ---------------------- Notificaciones ----------------------
  Future<List<dynamic>> listarNotificaciones({bool soloNoLeidas = false}) async {
    try {
      final res = await _dio.get(
        '/notificaciones',
        queryParameters: soloNoLeidas ? {'solo_no_leidas': true} : null,
      );
      return (res.data as List).cast<dynamic>();
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<void> marcarNotificacionLeida(int idNotif) async {
    try {
      await _dio.patch('/notificaciones/$idNotif/marcar-leida');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<void> marcarTodasLeidas() async {
    try {
      await _dio.patch('/notificaciones/marcar-todas-leidas');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  // ---------------------- Conductor-Vehículo ----------------------
  Future<List<dynamic>> listarAsignacionesConductorVehiculo() async {
    try {
      final res = await _dio.get('/conductor-vehiculo');
      return (res.data as List).cast<dynamic>();
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<void> asignarVehiculoAConductor(int idConductor, int idVehiculo) async {
    try {
      await _dio.post('/conductor-vehiculo', data: {
        'id_conductor': idConductor,
        'id_vehiculo': idVehiculo,
      });
    } on DioException catch (e) {
      _throw(e);
    }
  }

  Future<void> finalizarAsignacionConductorVehiculo(int idAsignacion) async {
    try {
      await _dio.patch('/conductor-vehiculo/$idAsignacion/finalizar');
    } on DioException catch (e) {
      _throw(e);
    }
  }
}