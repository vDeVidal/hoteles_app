// lib/pages/conductor_trips_page.dart - VERSIÓN MEJORADA
import 'package:flutter/material.dart';
import '../services/api_client.dart';

class ConductorTripsPage extends StatefulWidget {
  const ConductorTripsPage({super.key});

  @override
  State<ConductorTripsPage> createState() => _ConductorTripsPageState();
}

class _ConductorTripsPageState extends State<ConductorTripsPage> {
  final _api = ApiClient();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.listarViajes();
  }

  Future<void> _reload() async {
    setState(() => _future = _api.listarViajes());
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
                    ElevatedButton(onPressed: _reload, child: const Text('Reintentar')),
                  ],
                ),
              );
            }

            final data = snap.data ?? [];
            if (data.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No tienes viajes asignados'),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final viaje = data[i] as Map<String, dynamic>;
                return _ViajeCard(viaje: viaje, onAction: _reload);
              },
            );
          },
        ),
      ),
    );
  }
}

class _ViajeCard extends StatelessWidget {
  final Map<String, dynamic> viaje;
  final VoidCallback onAction;

  const _ViajeCard({required this.viaje, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final idViaje = viaje['id_viaje'] as int;
    final idEstado = viaje['id_estado_viaje'] as int;
    final agendadaPara = viaje['agendada_para'] as String?;

    final estadoNombre = _nombreEstado(idEstado);
    final estadoColor = _colorEstado(idEstado);

    return Card(
      elevation: 2,
      child: Column(
        children: [
          // Header con estado
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: estadoColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(_iconEstado(idEstado), size: 20),
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
                  label: Text(estadoNombre),
                  backgroundColor: Colors.white.withOpacity(0.8),
                ),
              ],
            ),
          ),

          // Detalles del viaje
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.schedule,
                  label: 'Salida programada',
                  value: _formatFecha(agendadaPara),
                ),
                const SizedBox(height: 8),

                // Mostrar más detalles según el estado
                if (idEstado >= 2) ...[
                  const Divider(),
                  _InfoRow(
                    icon: Icons.route,
                    label: 'Ruta',
                    value: 'Ver detalles',
                    onTap: () => _showTripDetails(context, viaje),
                  ),
                ],

                const SizedBox(height: 16),

                // Botones de acción
                _buildActions(context, idViaje, idEstado),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTripDetails(BuildContext context, Map<String, dynamic> viaje) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TripDetailsSheet(viaje: viaje),
    );
  }

  Widget _buildActions(BuildContext context, int idViaje, int estado) {
    final api = ApiClient();

    if (estado == 2) {
      // ASIGNADO: puede aceptar o rechazar
      return Column(
        children: [
          const Text(
            '¿Aceptas este viaje?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleAction(
                    context,
                        () => api.rechazarViaje(idViaje),
                    'Viaje rechazado',
                  ),
                  icon: const Icon(Icons.close),
                  label: const Text('Rechazar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _handleAction(
                    context,
                        () => api.aceptarViaje(idViaje),
                    'Viaje aceptado',
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Aceptar'),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (estado == 3) {
      // ACEPTADO: puede iniciar
      return FilledButton.icon(
        onPressed: () => _handleAction(
          context,
              () => api.iniciarViaje(idViaje),
          'Viaje iniciado',
        ),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Iniciar Viaje'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
        ),
      );
    } else if (estado == 4) {
      // EN_CURSO: puede finalizar
      return FilledButton.icon(
        onPressed: () => _handleAction(
          context,
              () => api.finalizarViaje(idViaje),
          'Viaje completado',
        ),
        icon: const Icon(Icons.flag),
        label: const Text('Finalizar Viaje'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.green,
          minimumSize: const Size(double.infinity, 48),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _handleAction(
      BuildContext context,
      Future<void> Function() action,
      String successMessage,
      ) async {
    try {
      await action();
      onAction(); // ✅ Actualiza la lista inmediatamente
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _nombreEstado(int estado) {
    switch (estado) {
      case 1: return 'PENDIENTE';
      case 2: return 'ASIGNADO';
      case 3: return 'ACEPTADO';
      case 4: return 'EN CURSO';
      case 5: return 'COMPLETADO';
      case 6: return 'CANCELADO';
      default: return 'DESCONOCIDO';
    }
  }

  IconData _iconEstado(int estado) {
    switch (estado) {
      case 1: return Icons.pending;
      case 2: return Icons.assignment;
      case 3: return Icons.check_circle;
      case 4: return Icons.drive_eta;
      case 5: return Icons.done_all;
      case 6: return Icons.cancel;
      default: return Icons.help;
    }
  }

  Color _colorEstado(int estado) {
    switch (estado) {
      case 1: return Colors.orange.shade100;
      case 2: return Colors.blue.shade100;
      case 3: return Colors.cyan.shade100;
      case 4: return Colors.purple.shade100;
      case 5: return Colors.green.shade100;
      case 6: return Colors.red.shade100;
      default: return Colors.grey.shade100;
    }
  }

  String _formatFecha(String? fecha) {
    if (fecha == null) return 'Sin fecha';
    try {
      final dt = DateTime.parse(fecha);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return fecha;
    }
  }
}

// Widget reutilizable para mostrar info
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final widget = Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null) const Icon(Icons.chevron_right, color: Colors.grey),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: widget,
        ),
      );
    }

    return widget;
  }
}

// ================== Detalles del viaje ==================
class _TripDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> viaje;

  const _TripDetailsSheet({required this.viaje});

  @override
  State<_TripDetailsSheet> createState() => _TripDetailsSheetState();
}

class _TripDetailsSheetState extends State<_TripDetailsSheet> {
  final _api = ApiClient();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadDetails();
  }

  Future<Map<String, dynamic>> _loadDetails() async {
    try {
      final idViaje = widget.viaje['id_viaje'] as int;

      // Aquí puedes agregar más llamadas API si necesitas más detalles
      // Por ahora usamos lo que ya tenemos
      return widget.viaje;
    } catch (e) {
      rethrow;
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
        future: _future,
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
            return Center(
              child: Text('Error: ${snap.error}'),
            );
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
                      'Detalles del Viaje',
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

                // ID del viaje
                _DetailItem(
                  icon: Icons.tag,
                  label: 'ID del viaje',
                  value: '#$idViaje',
                ),
                const SizedBox(height: 12),

                // Estado
                _DetailItem(
                  icon: Icons.info,
                  label: 'Estado actual',
                  value: _estadoNombre(idEstado),
                  valueColor: _estadoColor(idEstado),
                ),
                const SizedBox(height: 12),

                // Fecha y hora
                _DetailItem(
                  icon: Icons.event,
                  label: 'Fecha programada',
                  value: _formatFechaCompleta(agendada),
                ),
                const SizedBox(height: 12),

                // Ruta (si está disponible)
                if (viaje['id_ruta'] != null)
                  _DetailItem(
                    icon: Icons.route,
                    label: 'Ruta',
                    value: 'Ruta #${viaje['id_ruta']}',
                  ),
                const SizedBox(height: 12),

                // Hotel
                if (viaje['id_hotel'] != null)
                  _DetailItem(
                    icon: Icons.hotel,
                    label: 'Hotel',
                    value: 'Hotel #${viaje['id_hotel']}',
                  ),
                const SizedBox(height: 24),

                // Instrucciones según estado
                _buildInstructions(idEstado),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstructions(int estado) {
    String title = '';
    String message = '';
    IconData icon = Icons.info;
    Color color = Colors.blue;

    switch (estado) {
      case 2: // ASIGNADO
        title = 'Viaje asignado';
        message = 'Este viaje te ha sido asignado. Revisa los detalles y acepta si puedes realizarlo.';
        icon = Icons.assignment;
        color = Colors.blue;
        break;
      case 3: // ACEPTADO
        title = 'Viaje aceptado';
        message = 'Has aceptado este viaje. Inicia el viaje cuando estés listo para partir.';
        icon = Icons.check_circle;
        color = Colors.cyan;
        break;
      case 4: // EN_CURSO
        title = 'Viaje en curso';
        message = 'El viaje está en curso. Finaliza cuando llegues al destino.';
        icon = Icons.drive_eta;
        color = Colors.purple;
        break;
      case 5: // COMPLETADO
        title = 'Viaje completado';
        message = 'Este viaje ha sido completado exitosamente.';
        icon = Icons.done_all;
        color = Colors.green;
        break;
      case 6: // CANCELADO
        title = 'Viaje cancelado';
        message = 'Este viaje ha sido cancelado.';
        icon = Icons.cancel;
        color = Colors.red;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  String _estadoNombre(int estado) {
    switch (estado) {
      case 1: return 'Pendiente';
      case 2: return 'Asignado';
      case 3: return 'Aceptado';
      case 4: return 'En curso';
      case 5: return 'Completado';
      case 6: return 'Cancelado';
      default: return 'Desconocido';
    }
  }

  Color _estadoColor(int estado) {
    switch (estado) {
      case 1: return Colors.orange;
      case 2: return Colors.blue;
      case 3: return Colors.cyan;
      case 4: return Colors.purple;
      case 5: return Colors.green;
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
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
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