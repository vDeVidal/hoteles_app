// lib/pages/assignments_page.dart
import 'package:flutter/material.dart';
import '../services/api_client.dart';

class AssignmentsPage extends StatefulWidget {
  const AssignmentsPage({super.key});

  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  final _api = ApiClient();
  late Future<List<dynamic>> _futureViajes;

  @override
  void initState() {
    super.initState();
    _futureViajes = _api.listarViajes(estado: 1); // Solo PENDIENTES
  }

  Future<void> _reload() async {
    setState(() => _futureViajes = _api.listarViajes(estado: 1));
  }

  void _openAssignDialog(Map<String, dynamic> viaje) {
    showDialog(
      context: context,
      builder: (_) => _AssignDialog(viaje: viaje, onAssigned: _reload),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<dynamic>>(
          future: _futureViajes,
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
                    Text('No hay viajes pendientes de asignar'),
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
                final idViaje = viaje['id_viaje'] as int;
                final agendada = viaje['agendada_para'] as String?;

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.pending_actions),
                    ),
                    title: Text('Viaje #$idViaje'),
                    subtitle: Text('Salida: ${_formatFecha(agendada)}'),
                    trailing: FilledButton.icon(
                      onPressed: () => _openAssignDialog(viaje),
                      icon: const Icon(Icons.assignment_ind),
                      label: const Text('Asignar'),
                    ),
                  ),
                );
              },
            );
          },
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

class _AssignDialog extends StatefulWidget {
  final Map<String, dynamic> viaje;
  final VoidCallback onAssigned;

  const _AssignDialog({required this.viaje, required this.onAssigned});

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
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
        _conductores = conductores
            .where((u) => u['id_tipo_usuario'] == 2 && u['disponible'] == true)
            .cast<Map<String, dynamic>>()
            .toList();
        _vehiculos = vehiculos.cast<Map<String, dynamic>>();
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
      await _api.asignarViaje(
        widget.viaje['id_viaje'] as int,
        _conductorSeleccionado!,
        _vehiculoSeleccionado!,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onAssigned();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viaje asignado con éxito')),
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
      title: Text('Asignar Viaje #${widget.viaje['id_viaje']}'),
      content: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Conductor
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

            // Vehículo
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
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
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