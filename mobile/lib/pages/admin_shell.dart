// lib/pages/admin_shell.dart
import 'package:flutter/material.dart';
import '../services/hotel_session.dart';
import 'dashboard_page.dart';
import 'users_page.dart';
import 'vehicles_page.dart';
import 'routes_page.dart';
import 'profile_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 4, vsync: this); // Solo 4 tabs para admin
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changeHotel() {
    HotelSession.clear();
    Navigator.of(context).pushNamedAndRemoveUntil('/select_hotel', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final hotel = HotelSession.hotelName ?? 'Sin hotel';
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin - $hotel'),
        actions: [
          // Botón para cambiar de hotel (solo admin)
          IconButton(
            tooltip: 'Cambiar hotel',
            onPressed: _changeHotel,
            icon: const Icon(Icons.swap_horiz),
          ),
        ],
        bottom: TabBar(
          controller: _controller,
          isScrollable: false,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.people), text: 'Usuarios'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Reportes'),
            Tab(icon: Icon(Icons.person), text: 'Perfil'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: const [
          DashboardPage(),
          UsersPage(),
          Center(child: Text('Reportes (próximamente)')),
          ProfilePage(),
        ],
      ),
    );
  }
}