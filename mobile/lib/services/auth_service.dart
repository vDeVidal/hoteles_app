// lib/services/auth_service.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'hotel_session.dart';

class AuthService {
  // ===== Persistencia =====
  static const _storage = FlutterSecureStorage();

  // ===== Sesión en memoria =====
  static String? _token;
  static Map<String, dynamic>? _claims;

  static String? get token => _token;

  /// rol desde el JWT (claim 'role'). Si viene string lo intento parsear.
  static int get role {
    final r = _claims?['role'];
    if (r is int) return r;
    return int.tryParse('$r') ?? 0;
  }

  /// "admin" si role == 4
  static bool get isAdmin => role == 4;

  /// bandera de forzar cambio de password (admite must_change_password o mustChange)
  static bool get mustChange =>
      (_claims?['mustChange'] == true) ||
          (_claims?['must_change_password'] == true);

  /// nombre (si lo enviaste en el JWT)
  static String get fullName => '${_claims?['name'] ?? ''}'.trim();

  /// Acceso a un claim arbitrario
  static dynamic claim(String key) {
    try {
      return _claims?[key];
    } catch (_) {
      return null;
    }
  }

  // ===== Guardar/Recuperar/Cerrar sesión =====
  static Future<void> _persistSession(String jwt) async {
    HotelSession.clear();
    _token = jwt;
    _claims = Jwt.parseJwt(jwt);
    await _storage.write(key: 'auth_token', value: jwt);
  }

  static Future<void> restoreSession() async {
    final saved = await _storage.read(key: 'auth_token');
    if (saved != null && saved.isNotEmpty) {
      _token = saved;
      _claims = Jwt.parseJwt(saved);
    }
  }

  static Future<void> logout() async {
    _token = null;
    _claims = null;
    HotelSession.clear();
    await _storage.delete(key: 'auth_token');
  }

  // ===== Dio con auth (para ApiClient) =====
  static Dio dioWithAuth() {
    final dio = Dio(
      BaseOptions(
        baseUrl: const String.fromEnvironment(
          'BASE_URL',
          defaultValue: 'http://10.0.2.2:8000',
        ),
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final t = _token;
          if (t != null && t.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $t';
          }
          return handler.next(options);
        },
      ),
    );
    return dio;
  }

  // ===== Login (sin auth previa) =====
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'BASE_URL',
        defaultValue: 'http://10.0.2.2:8000',
      ),
      headers: {'Content-Type': 'application/json'},
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  /// Devuelve {'role': int, 'mustChange': bool}
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'correo': email,
      'password': password,
    });

    if (res.statusCode == 200) {
      final data = Map<String, dynamic>.from(res.data);
      final jwt = (data['access_token'] ?? '') as String;
      if (jwt.isEmpty) throw Exception('Token vacío en respuesta de login');

      await _persistSession(jwt);

      final must = (data['must_change_password'] == true) ||
          (data['mustChange'] == true);

      return {'role': role, 'mustChange': must};
    }

    throw Exception('Login fallido (${res.statusCode})');
  }
}