// lib/pages/home_page.dart - ACTUALIZACIÓN COMPLETA
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/hotel_session.dart';
import '../services/api_client.dart';
import 'dashboard_page.dart';
import 'users_page.dart';
import 'guests_page.dart';
import 'vehicles_page.dart';
import 'routes_page.dart';
import 'assignments_page.dart';
import 'conductor_trips_page.dart';
import 'conductor_vehiculo_page.dart';
import 'guest_request_trip_page.dart';
import 'guest_my_trips_page.dart';
import 'profile_page.dart';
import 'conductor_vehicle_info_page.dart';

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
        // Ignorar error
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabsFor(widget.role);
    return ValueListenableBuilder<String?>(
      valueListenable: HotelSession.notifier,
      builder: (context, currentHotel, _) {
        final hotelTitle = _hotelTitleFor(currentHotel);

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text('Bienvenido(a) a $hotelTitle'),
              actions: [
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
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: tabs.map((t) {
                final icon = t.icon;
                if (icon is IconData) {
                  return Tab(icon: Icon(icon), text: t.label);
                }
                if (icon is Widget) {
                  return Tab(icon: icon, text: t.label);
                }
                return Tab(text: t.label);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  List<_TabDef> _tabsFor(int r) {
    switch (r) {
      case 4: // Administrador - Solo gestiona personal (conductores y supervisores)
        return [
          _TabDef('Dashboard', Icons.dashboard, const DashboardPage()),
          _TabDef('Personal', Icons.people, const UsersPage()), // Conductores y Supervisores
          _TabDef('Reportes', Icons.bar_chart, const Center(child: Text('Reportes (próximamente)'))),
          _TabDef('Perfil', Icons.person, const ProfilePage()),
        ];

      case 3: // Supervisor - Solo gestiona huéspedes y operaciones
        return [
          _TabDef('Dash', Icons.dashboard, const DashboardPage()),
          _TabDef('Asignar', Icons.assignment, const AssignmentsPage()),
          _TabDef('Huéspedes', Icons.people, const GuestsPage()), //  CAMBIAR ESTA LÍNEA
          _TabDef('Cond-Veh', Icons.car_rental, const ConductorVehiculoPage()),
          _TabDef('Vehículos', Icons.local_taxi, const VehiclesPage()),
          _TabDef('Rutas', Icons.alt_route, const RoutesPage()),
          _TabDef('Perfil', Icons.person, const ProfilePage()),
        ];

      case 2: // Conductor
        return [
          _TabDef('Mis Viajes', Icons.local_taxi, const ConductorTripsPage()),
          _TabDef('Mi Vehículo', Icons.directions_car, const ConductorVehicleInfoPage()), //  NUEVO
          _TabDef('Perfil', Icons.person, const ProfilePage()),
        ];

      default: // Usuario (Huésped) -  ACTUALIZAR ESTA SECCIÓN
        return [
          _TabDef('Solicitar', Icons.directions_car, const GuestRequestTripPage()), //  Nueva página
          _TabDef('Mis Viajes', Icons.list, const Center(child: Text('Mis viajes (próximamente)'))),
          _TabDef('Perfil', Icons.person, const ProfilePage()),
        ];
    }
  }
  String _hotelTitleFor(String? notifierValue) {
    final candidate = (notifierValue ?? HotelSession.hotelName)?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }

    final claim = AuthService.claim('nombre_hotel');
    if (claim is String && claim.trim().isNotEmpty) {
      return claim.trim();
    }

    if (claim != null) {
      final claimString = '${claim ?? ''}'.trim();
      if (claimString.isNotEmpty) {
        return claimString;
      }
    }

    return 'Hoteles App';
  }
}

class _TabDef {
  final String label;
  final Object icon;
  final Widget page;
  _TabDef(this.label, this.icon, this.page);
}