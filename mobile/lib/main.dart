// lib/main.dart
import 'package:flutter/material.dart';

import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/hotel_selector_page.dart';
import 'pages/admin_shell.dart';
import 'services/hotel_session.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.restoreSession();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hoteles App',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: _getInitialPage(),
      routes: {
        '/login': (_) => const LoginPage(),
        '/select_hotel': (_) => const HotelSelectorPage(),
        '/admin': (_) => const AdminShell(),
      },
    );
  }

  Widget _getInitialPage() {
    // Si no hay token, ir a login
    if (AuthService.token == null) {
      return const LoginPage();
    }

    final role = AuthService.role;

    // Admin: necesita seleccionar hotel si no tiene uno
    if (role == 4) {
      return HotelSession.hasHotel
          ? const AdminShell()
          : const HotelSelectorPage();
    }

    // Otros roles: directamente a home
    return HomePage(role: role);
  }
}