// lib/pages/conductor_trips_page.dart
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Viaje #$idViaje',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(estadoNombre),
                  backgroundColor: estadoColor,
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16),
                const SizedBox(width: 8),
                Text('Salida: ${_formatFecha(agendadaPara)}'),
              ],
            ),
            const SizedBox(height: 16),

            // Botones según estado
            _buildActions(context, idViaje, idEstado),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, int idViaje, int estado) {
    final api = ApiClient();

    if (estado == 2) {
      // ASIGNADO: puede aceptar o rechazar
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  await api.rechazarViaje(idViaje);
                  onAction();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Viaje rechazado')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.close),
              label: const Text('Rechazar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () async {
                try {
                  await api.aceptarViaje(idViaje);
                  onAction();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Viaje aceptado')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('Aceptar'),
            ),
          ),
        ],
      );
    } else if (estado == 3) {
      // ACEPTADO: puede iniciar
      return FilledButton.icon(
        onPressed: () async {
          try {
            await api.iniciarViaje(idViaje);
            onAction();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Viaje iniciado')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Iniciar Viaje'),
      );
    } else if (estado == 4) {
      // EN_CURSO: puede finalizar
      return FilledButton.icon(
        onPressed: () async {
          try {
            await api.finalizarViaje(idViaje);
            onAction();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Viaje finalizado')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        },
        icon: const Icon(Icons.flag),
        label: const Text('Finalizar Viaje'),
        style: FilledButton.styleFrom(backgroundColor: Colors.green),
      );
    }

    // Otros estados: sin acciones
    return const SizedBox.shrink();
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