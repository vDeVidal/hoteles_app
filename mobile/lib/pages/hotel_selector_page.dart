import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/hotel_session.dart';
import 'admin_shell.dart'; // lo creamos en el paso 3
import 'home_page.dart';   // para no-admin, por si quieres reusar

class HotelSelectorPage extends StatefulWidget {
  const HotelSelectorPage({super.key});

  @override
  State<HotelSelectorPage> createState() => _HotelSelectorPageState();
}

class _HotelSelectorPageState extends State<HotelSelectorPage> {
  final _api = ApiClient();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.listarHoteles();
  }

  void _goToAdminShell() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // si por cualquier motivo no es admin, mandamos a su home normal
    if (!AuthService.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('No autorizado (solo administrador).')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar hotel')),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final data = snap.data ?? [];
          if (data.isEmpty) {
            return const Center(child: Text('No hay hoteles disponibles'));
          }
          return ListView.separated(
            itemCount: data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final h = data[i] as Map<String, dynamic>;
              final id = h['id_hotel'] as int;
              final nombre = (h['nombre_hotel'] ?? '') as String;
              return ListTile(
                leading: const Icon(Icons.hotel),
                title: Text(nombre),
                onTap: () {
                  final id   = (h['id_hotel'] as num).toInt();
                  final name = (h['nombre_hotel'] ?? '').toString();

                  HotelSession.set(id, name);

                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => HomePage(role: AuthService.role)),
                        (_) => false,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
