import 'package:flutter/material.dart';
import '../services/api_client.dart';

class ConductorVehicleInfoPage extends StatefulWidget {
  const ConductorVehicleInfoPage({super.key});

  @override
  State<ConductorVehicleInfoPage> createState() => _ConductorVehicleInfoPageState();
}

class _ConductorVehicleInfoPageState extends State<ConductorVehicleInfoPage> {
  final _api = ApiClient();
  late Future<Map<String, dynamic>> _futureVehiculo;
  late Future<Map<String, dynamic>> _futureEstadoTurno;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _futureVehiculo = _api.obtenerMiVehiculo();
      _futureEstadoTurno = _api.obtenerEstadoTurno();
    });
  }

  Future<void> _iniciarTurno() async {
    try {
      await _api.iniciarTurno();
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turno iniciado - Ahora estás disponible'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _finalizarTurno() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar Turno'),
        content: const Text('¿Seguro que deseas finalizar tu turno? No recibirás más asignaciones.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _api.finalizarTurno();
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turno finalizado - Ya no estás disponible'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: Future.wait([_futureVehiculo, _futureEstadoTurno]),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }

            final vehiculo = snap.data![0];
            final estadoTurno = snap.data![1];
            final tieneVehiculo = vehiculo['tiene_vehiculo'] == true;
            final disponible = estadoTurno['disponible'] == true;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Estado del turno
                Card(
                  color: disponible ? Colors.green.shade50 : Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              disponible ? Icons.check_circle : Icons.do_not_disturb,
                              color: disponible ? Colors.green : Colors.orange,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    disponible ? 'TURNO ACTIVO' : 'TURNO FINALIZADO',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: disponible ? Colors.green.shade900 : Colors.orange.shade900,
                                    ),
                                  ),
                                  Text(
                                    disponible
                                        ? 'Puedes recibir asignaciones'
                                        : 'No recibirás nuevas asignaciones',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: disponible ? _finalizarTurno : _iniciarTurno,
                            icon: Icon(disponible ? Icons.logout : Icons.login),
                            label: Text(disponible ? 'Finalizar Turno' : 'Iniciar Turno'),
                            style: FilledButton.styleFrom(
                              backgroundColor: disponible ? Colors.red : Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Información del vehículo
                const Text(
                  'Mi Vehículo Asignado',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                if (!tieneVehiculo)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text(
                            'No tienes vehículo asignado',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Contacta con tu supervisor para que te asigne un vehículo',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.directions_car,
                                  size: 32,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vehiculo['patente'] ?? 'N/A',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${vehiculo['marca'] ?? ''} ${vehiculo['modelo'] ?? ''}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          _InfoRow(
                            icon: Icons.calendar_today,
                            label: 'Año',
                            value: vehiculo['anio']?.toString() ?? 'N/A',
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.airline_seat_recline_normal,
                            label: 'Capacidad',
                            value: '${vehiculo['capacidad'] ?? 'N/A'} personas',
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.access_time,
                            label: 'Asignado desde',
                            value: _formatFecha(vehiculo['asignado_desde']),
                          ),
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

  String _formatFecha(String? fecha) {
    if (fecha == null) return 'N/A';
    try {
      final dt = DateTime.parse(fecha);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return fecha;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}