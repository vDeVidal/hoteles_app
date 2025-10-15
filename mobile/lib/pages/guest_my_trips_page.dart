// lib/pages/guest_my_trips_page.dart
import 'package:flutter/material.dart';
import '../services/api_client.dart';

class GuestMyTripsPage extends StatefulWidget {
  const GuestMyTripsPage({super.key});

  @override
  State<GuestMyTripsPage> createState() => _GuestMyTripsPageState();
}

class _GuestMyTripsPageState extends State<GuestMyTripsPage> {
  final _api = ApiClient();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadTrips();
  }

  Future<List<dynamic>> _loadTrips() async {
    try {
      return await _api.listarViajes();
    } catch (e) {
      debugPrint('Error cargando viajes: $e');
      return [];
    }
  }

  Future<void> _reload() async {
    setState(() => _future = _loadTrips());
  }

  void _showTripDetails(Map<String, dynamic> viaje) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TripDetailsSheet(viaje: viaje, onUpdate: _reload),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<dynamic>>(
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
                    ElevatedButton(
                      onPressed: _reload,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }

            final viajes = snap.data ?? [];

            if (viajes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'No tienes viajes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Solicita tu primer viaje desde la pestaña Solicitar',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: viajes.length,
              itemBuilder: (_, i) {
                final viaje = viajes[i] as Map<String, dynamic>;
                return _ViajeCard(
                  viaje: viaje,
                  onTap: () => _showTripDetails(viaje),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ====================== Card de Viaje ======================
class _ViajeCard extends StatelessWidget {
  final Map<String, dynamic> viaje;
  final VoidCallback onTap;

  const _ViajeCard({required this.viaje, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final idViaje = viaje['id_viaje'] as int;
    final idEstado = viaje['id_estado_viaje'] as int;
    final agendadaPara = viaje['agendada_para'] as String?;

    final estadoInfo = _getEstadoInfo(idEstado);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: estadoInfo['color'] as Color, width: 4),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          estadoInfo['icon'] as IconData,
                          color: estadoInfo['color'] as Color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Viaje #$idViaje',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Chip(
                      label: Text(
                        estadoInfo['nombre'] as String,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: (estadoInfo['color'] as Color).withOpacity(0.2),
                      side: BorderSide.none,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Fecha
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      _formatFecha(agendadaPara),
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),

                // Mensaje según estado
                if (idEstado == 1) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hourglass_empty, size: 16, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Esperando asignación de conductor...',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (idEstado == 2) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Conductor asignado. Esperando confirmación...',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (idEstado == 3) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '¡Viaje confirmado! El conductor llegará a la hora indicada.',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (idEstado == 6) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.cancel, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'El conductor rechazó este viaje. Puedes solicitar uno nuevo.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getEstadoInfo(int estado) {
    switch (estado) {
      case 1:
        return {'nombre': 'PENDIENTE', 'icon': Icons.pending, 'color': Colors.orange};
      case 2:
        return {'nombre': 'ASIGNADO', 'icon': Icons.assignment, 'color': Colors.blue};
      case 3:
        return {'nombre': 'CONFIRMADO', 'icon': Icons.check_circle, 'color': Colors.green};
      case 4:
        return {'nombre': 'EN CURSO', 'icon': Icons.drive_eta, 'color': Colors.purple};
      case 5:
        return {'nombre': 'COMPLETADO', 'icon': Icons.done_all, 'color': Colors.teal};
      case 6:
        return {'nombre': 'RECHAZADO', 'icon': Icons.cancel, 'color': Colors.red};
      default:
        return {'nombre': 'DESCONOCIDO', 'icon': Icons.help, 'color': Colors.grey};
    }
  }

  String _formatFecha(String? fecha) {
    if (fecha == null) return 'Sin fecha';
    try {
      final dt = DateTime.parse(fecha);
      final dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      return '${dias[dt.weekday - 1]}, ${dt.day}/${dt.month}/${dt.year} - ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return fecha;
    }
  }
}

// ====================== Detalles del Viaje ======================
class _TripDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> viaje;
  final VoidCallback onUpdate;

  const _TripDetailsSheet({required this.viaje, required this.onUpdate});

  @override
  State<_TripDetailsSheet> createState() => _TripDetailsSheetState();
}

class _TripDetailsSheetState extends State<_TripDetailsSheet> {
  final _api = ApiClient();
  late Future<Map<String, dynamic>> _futureDetails;

  @override
  void initState() {
    super.initState();
    _futureDetails = _loadDetails();
  }

  Future<Map<String, dynamic>> _loadDetails() async {
    try {
      final idViaje = widget.viaje['id_viaje'] as int;

      // Aquí podrías hacer una llamada específica para obtener más detalles
      // Por ahora usamos lo que ya tenemos
      return widget.viaje;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _cancelTrip() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Viaje'),
        content: const Text('¿Estás seguro de que deseas cancelar este viaje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _api.cancelarViaje(widget.viaje['id_viaje'] as int);
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdate();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viaje cancelado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _futureDetails,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final viaje = snap.data!;
          final idViaje = viaje['id_viaje'] as int;
          final idEstado = viaje['id_estado_viaje'] as int;
          final agendada = viaje['agendada_para'] as String?;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Viaje #$idViaje',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),

                // Estado
                _DetailItem(
                  icon: Icons.info,
                  label: 'Estado',
                  value: _estadoNombre(idEstado),
                  valueColor: _estadoColor(idEstado),
                ),
                const SizedBox(height: 12),

                // Fecha
                _DetailItem(
                  icon: Icons.event,
                  label: 'Fecha y hora',
                  value: _formatFechaCompleta(agendada),
                ),
                const SizedBox(height: 24),

                // Info de conductor (solo si está ACEPTADO o posterior)
                if (idEstado >= 3) ...[
                  const Text(
                    'Información del Conductor',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.green,
                              child: const Icon(Icons.person, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Conductor Asignado',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  Text(
                                    viaje['conductor']?['nombre'] ?? 'No disponible',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (viaje['conductor']?['telefono'] != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          viaje['conductor']['telefono'] as String,
                                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (viaje['vehiculo'] != null) ...[
                          const Divider(height: 24),
                          Row(
                            children: [
                              Icon(Icons.directions_car, color: Colors.grey[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Vehículo',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    Text(
                                      viaje['vehiculo']['descripcion'] ?? 'No disponible',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (viaje['vehiculo']['capacidad'] != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.airline_seat_recline_normal,
                                              size: 14, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Capacidad: ${viaje['vehiculo']['capacidad']} personas',
                                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Botón de cancelar (solo si está PENDIENTE o ASIGNADO)
                if (idEstado <= 2) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _cancelTrip,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancelar Viaje'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _estadoNombre(int estado) {
    switch (estado) {
      case 1: return 'Pendiente';
      case 2: return 'Asignado';
      case 3: return 'Confirmado';
      case 4: return 'En curso';
      case 5: return 'Completado';
      case 6: return 'Rechazado';
      default: return 'Desconocido';
    }
  }

  Color _estadoColor(int estado) {
    switch (estado) {
      case 1: return Colors.orange;
      case 2: return Colors.blue;
      case 3: return Colors.green;
      case 4: return Colors.purple;
      case 5: return Colors.teal;
      case 6: return Colors.red;
      default: return Colors.grey;
    }
  }

  String _formatFechaCompleta(String? fecha) {
    if (fecha == null) return 'Sin fecha';
    try {
      final dt = DateTime.parse(fecha);
      final dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      return '${dias[dt.weekday - 1]}, ${dt.day} ${meses[dt.month - 1]} ${dt.year} - ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return fecha;
    }
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.grey[700]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}