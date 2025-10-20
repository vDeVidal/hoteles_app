// lib/pages/conductor_vehiculo_page.dart
import 'package:flutter/material.dart';
import '../services/api_client.dart';

class ConductorVehiculoPage extends StatefulWidget {
  const ConductorVehiculoPage({super.key});

  @override
  State<ConductorVehiculoPage> createState() => _ConductorVehiculoPageState();
}

class _ConductorVehiculoPageState extends State<ConductorVehiculoPage> {
  final _api = ApiClient();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<dynamic>> _fetch() async {
    try {
      return await _api.listarAsignacionesConductorVehiculo();
    } catch (e) {
      return [];
    }
  }

  Future<void> _reload() async {
    setState(() => _future = _fetch());
  }

  void _openAssignDialog() {
    showDialog(
      context: context,
      builder: (_) => _AssignVehiculoDialog(onAssigned: _reload),
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
                    Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                    SizedBox(height: 16),
                    Text('No hay asignaciones activas'),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final asig = data[i] as Map<String, dynamic>;
                return _AsignacionCard(asignacion: asig, onFinalized: _reload);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAssignDialog,
        icon: const Icon(Icons.add),
        label: const Text('Asignar Vehículo'),
      ),
    );
  }
}

class _AsignacionCard extends StatelessWidget {
  final Map<String, dynamic> asignacion;
  final VoidCallback onFinalized;

  const _AsignacionCard({required this.asignacion, required this.onFinalized});

  @override
  Widget build(BuildContext context) {
    final conductorNombre = asignacion['conductor_nombre'] as String;
    final vehiculoInfo = asignacion['vehiculo_info'] as String;
    final horaAsignacion = asignacion['hora_asignacion'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    conductorNombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.directions_car, size: 20),
                const SizedBox(width: 8),
                Text(vehiculoInfo),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Desde: ${_formatFecha(horaAsignacion)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmar = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Confirmar'),
                          content: const Text('¿Finalizar esta asignación?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Finalizar'),
                            ),
                          ],
                        ),
                      );

                      if (confirmar != true) return;

                      try {
                        await ApiClient().finalizarAsignacionConductorVehiculo(
                          asignacion['id_conductor_vehiculo'] as int,
                        );
                        onFinalized();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Asignación finalizada')),
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
                    icon: const Icon(Icons.cancel),
                    label: const Text('Finalizar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

class _AssignVehiculoDialog extends StatefulWidget {
  final VoidCallback onAssigned;

  const _AssignVehiculoDialog({required this.onAssigned});

  @override
  State<_AssignVehiculoDialog> createState() => _AssignVehiculoDialogState();
}

class _AssignVehiculoDialogState extends State<_AssignVehiculoDialog> {
  final _api = ApiClient();

  List<Map<String, dynamic>> _conductores = [];
  List<Map<String, dynamic>> _vehiculos = [];

  int? _conductorSeleccionado;
  int? _vehiculoSeleccionado;

  bool _loading = false;
  bool _loadingData = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final conductores = await _api.listarUsuariosDeMiHotel(null);
      final vehiculos = await _api.listarVehiculos();

      setState(() {
        // Filtrar conductores activos que NO tengan vehículo asignado
        _conductores = conductores
            .where((u) =>
        u['id_tipo_usuario'] == 2 &&
            u['id_estado_actividad'] == 1 &&
            u['is_suspended'] == false
        )
            .cast<Map<String, dynamic>>()
            .toList();

        _vehiculos = vehiculos
            .where((v) => v['id_estado_vehiculo'] == 1)
            .cast<Map<String, dynamic>>()
            .toList();

        _loadingData = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error cargando datos: $e';
        _loadingData = false;
      });
    }
  }

  Future<void> _asignar() async {
    if (_conductorSeleccionado == null || _vehiculoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar conductor y vehículo')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _api.asignarVehiculoAConductor(
        _conductorSeleccionado!,
        _vehiculoSeleccionado!,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onAssigned(); //  Actualiza la lista inmediatamente
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehículo asignado con éxito')),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Error al asignar: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Asignar Vehículo a Conductor'),
      content: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              value: _conductorSeleccionado,
              decoration: const InputDecoration(
                labelText: 'Conductor',
                border: OutlineInputBorder(),
              ),
              items: _conductores.map((c) {
                return DropdownMenuItem(
                  value: c['id_usuario'] as int,
                  child: Text(c['nombre_usuario'] as String),
                );
              }).toList(),
              onChanged: (v) => setState(() => _conductorSeleccionado = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _vehiculoSeleccionado,
              decoration: const InputDecoration(
                labelText: 'Vehículo',
                border: OutlineInputBorder(),
              ),
              items: _vehiculos.map((v) {
                return DropdownMenuItem(
                  value: v['id_vehiculo'] as int,
                  child: Text('${v['patente']} - ${v['marca_nombre'] ?? ''}'),
                );
              }).toList(),
              onChanged: (v) => setState(() => _vehiculoSeleccionado = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _asignar,
          child: _loading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Asignar'),
        ),
      ],
    );
  }
}