import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/hotel_session.dart';
import '../services/api_client.dart';
import 'dashboard_page.dart';
import 'users_page.dart';
import 'vehicles_page.dart';
import 'routes_page.dart';
import 'assignments_page.dart';
import 'conductor_trips_page.dart';
import 'conductor_vehiculo_page.dart';
import 'profile_page.dart';
import 'vehicles_page.dart';
import 'routes_page.dart';
import 'assignments_page.dart';
import 'conductor_trips_page.dart';
import 'profile_page.dart';




class HomePage extends StatefulWidget {
  final int role;
  const HomePage({super.key, required this.role});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _ensureHotelForNonAdmin();
  }

  Future<void> _ensureHotelForNonAdmin() async {
    // Para supervisor/conductor: si no tenemos hotel en memoria, lo pedimos 1 vez.
    if (!AuthService.isAdmin && HotelSession.hotelId == null) {
      try {
        final h = await _api.miHotel();
        final hid = (h['id_hotel'] as num?)?.toInt();
        final hname = h['nombre_hotel']?.toString();
        if (hid != null) {
          HotelSession.set(hid, hname);
          if (mounted) setState(() {});
        }
      } catch (_) {
        // si falla, simplemente dejamos el título por defecto
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabsFor(widget.role);
    final hotelTitle = HotelSession.hotelName ?? 'Hoteles App';

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Bienvenido(a) a $hotelTitle'),
          actions: [
            // Botón cambiar hotel solo para admin
            if (AuthService.isAdmin)
              IconButton(
                tooltip: 'Cambiar hotel',
                onPressed: () {
                  HotelSession.clear();
                  Navigator.of(context).pushNamedAndRemoveUntil('/select_hotel', (_) => false);
                },
                icon: const Icon(Icons.swap_horiz),
              ),
          ],
        ),
        body: TabBarView(children: tabs.map((t) => t.page).toList()),
        bottomNavigationBar: TabBar(
          tabs: tabs.map((t) => Tab(icon: Icon(t.icon), text: t.label)).toList(),
        ),
      ),
    );
  }

  List<_TabDef> _tabsFor(int r) {
    switch (r) {
      case 4: // Administrador - SOLO gestión global
        return [
          _TabDef('Dashboard', Icons.dashboard, const DashboardPage()),
          _TabDef('Usuarios', Icons.people, const UsersPage(soloPersonal: true)),
          _TabDef('Reportes', Icons.bar_chart, const Center(child: Text('Reportes (próximamente)'))),
          _TabDef('Perfil', Icons.person, const ProfilePage()),
        ];
      case 3: // Supervisor - Gestión completa del hotel
        return [
          _TabDef('Dashboard', Icons.dashboard, const DashboardPage()),
          _TabDef('Asignar Viajes', Icons.assignment, const AssignmentsPage()),
          _TabDef('Usuarios', Icons.people, const UsersPage()), // Solo usuarios huéspedes
          ///_TabDef('Personal', Icons.badge, const UsersPage(soloPersonal: true)), // Conductores/Supervisores
          _TabDef('Cond-Veh', Icons.car_rental, const ConductorVehiculoPage()), // Asignar vehículos a conductores
          _TabDef('Vehículos', Icons.local_taxi, const VehiclesPage()),
          _TabDef('Rutas', Icons.alt_route, const RoutesPage()),
          _TabDef('Perfil', Icons.person, const ProfilePage()),
        ];
      case 2: // Conductor
        return [
          _TabDef('Mis Viajes', Icons.local_taxi, const ConductorTripsPage()),
          _TabDef('Perfil', Icons.person, const ProfilePage()),
        ];
      default: // Usuario
        return [
          _TabDef('Inicio', Icons.home, const Center(child: Text('Solicitar Viajes (próximamente)'))),
          _TabDef('Perfil', Icons.person, const ProfilePage()),
        ];
    }
  }
}

class _TabDef {
  final String label;
  final IconData icon;
  final Widget page;
  _TabDef(this.label, this.icon, this.page);
}