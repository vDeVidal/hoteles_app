// lib/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';       // +++
import '../services/hotel_session.dart';      // +++

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _api = ApiClient();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    // Si es admin, pasar hotelId seleccionado; si no, null (backend usa el del token)
    _future = _api.getDashboardKpis(
      hotelId: AuthService.isAdmin ? HotelSession.hotelId : null,
    );

    // Cuando el admin cambia de hotel desde el selector, refrescamos
    HotelSession.notifier.addListener(() {
      if (AuthService.isAdmin) {
        _reload();
      }
    });
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.getDashboardKpis(
        hotelId: AuthService.isAdmin ? HotelSession.hotelId : null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${snap.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _reload, child: const Text('Reintentar')),
                  ],
                ),
              );
            }

            final data = snap.data!;
            final viajes = data['viajes'] as Map<String, dynamic>;
            final recursos = data['recursos'] as Map<String, dynamic>;
            final desempeno = data['desempeño'] as Map<String, dynamic>;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Dashboard',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Viajes Hoy',
                        value: '${viajes['hoy'] ?? 0}',
                        icon: Icons.today,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Total Período',
                        value: '${viajes['total_periodo'] ?? 0}',
                        icon: Icons.local_taxi,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Conductores',
                        value: '${recursos['conductores_disponibles'] ?? 0}',
                        icon: Icons.person,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Vehículos',
                        value: '${recursos['vehiculos_disponibles'] ?? 0}',
                        icon: Icons.directions_car,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.pie_chart, size: 20),
                          const SizedBox(width: 8),
                          Text('Viajes por Estado',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ]),
                        const Divider(),
                        ...((viajes['por_estado'] as List?) ?? []).map((e) {
                          final estado = e['estado'] as String;
                          final total = e['total'] as int;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(estado),
                                Chip(
                                  label: Text('$total'),
                                  backgroundColor: _getColorForEstado(estado),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.timer, color: Colors.indigo),
                    title: const Text('Tiempo Promedio de Viaje'),
                    trailing: Text(
                      '${desempeno['tiempo_promedio_minutos'] ?? 0} min',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.trending_up, size: 20),
                          const SizedBox(width: 8),
                          Text('Rutas Más Utilizadas',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ]),
                        const Divider(),
                        ...((desempeno['rutas_mas_usadas'] as List?) ?? []).map((e) {
                          final ruta = e['ruta'] as String;
                          final total = e['viajes'] as int;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(ruta)),
                                Text('$total viajes',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Color _getColorForEstado(String estado) {
    switch (estado.toUpperCase()) {
      case 'PENDIENTE':
        return Colors.orange.shade100;
      case 'ASIGNADO':
        return Colors.blue.shade100;
      case 'ACEPTADO':
        return Colors.cyan.shade100;
      case 'EN_CURSO':
        return Colors.purple.shade100;
      case 'COMPLETADO':
        return Colors.green.shade100;
      case 'CANCELADO':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
