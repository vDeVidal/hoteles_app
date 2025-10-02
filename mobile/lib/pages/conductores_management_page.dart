// lib/pages/conductores_management_page.dart
import 'package:flutter/material.dart';
import '../services/api_client.dart';

class ConductoresManagementPage extends StatefulWidget {
  const ConductoresManagementPage({super.key});

  @override
  State<ConductoresManagementPage> createState() => _ConductoresManagementPageState();
}

class _ConductoresManagementPageState extends State<ConductoresManagementPage> {
  final _api = ApiClient();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<dynamic>> _fetch() async {
    try {
      // Obtener conductores del hotel
      final users = await _api.listarUsuariosDeMiHotel(null);
      return users.where((u) => u['id_tipo_usuario'] == 2).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _reload() async {
    setState(() => _future = _fetch());
  }

  void _openActions(Map<String, dynamic> conductor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ConductorActionsSheet(
        conductor: conductor,
        onChanged: _reload,
      ),
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
                    Icon(Icons.people_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No hay conductores registrados'),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final conductor = data[i] as Map<String, dynamic>;
                return _ConductorCard(
                  conductor: conductor,
                  onTap: () => _openActions(conductor),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ConductorCard extends StatelessWidget {
  final Map<String, dynamic> conductor;
  final VoidCallback onTap;

  const _ConductorCard({required this.conductor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final nombre = conductor['nombre_usuario'] as String? ?? 'Sin nombre';
    final disponible = conductor['disponible'] == true;
    final suspendido = conductor['is_suspended'] == true;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (suspendido) {
      statusColor = Colors.red;
      statusText = 'Suspendido';
      statusIcon = Icons.block;
    } else if (disponible) {
      statusColor = Colors.green;
      statusText = 'Disponible';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.orange;
      statusText = 'No disponible';
      statusIcon = Icons.schedule;
    }

    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Icon(statusIcon, size: 14, color: statusColor),
            const SizedBox(width: 4),
            Text(statusText, style: TextStyle(color: statusColor)),
          ],
        ),
        trailing: const Icon(Icons.more_vert),
        onTap: onTap,
      ),
    );
  }
}

class _ConductorActionsSheet extends StatelessWidget {
  final Map<String, dynamic> conductor;
  final VoidCallback onChanged;

  const _ConductorActionsSheet({required this.conductor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final nombre = conductor['nombre_usuario'] as String? ?? 'Sin nombre';
    final idConductor = conductor['id_usuario'] as int;
    final disponible = conductor['disponible'] == true;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            nombre,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const Divider(height: 32),

          // Asignar vehículo
          ListTile(
            leading: const Icon(Icons.directions_car, color: Colors.blue),
            title: const Text('Asignar Vehículo'),
            subtitle: const Text('Vincular un vehículo a este conductor'),
            onTap: () {
              Navigator.pop(context);
              _showAsignarVehiculoDialog(context, idConductor, onChanged);
            },
          ),
          const Divider(height: 1),

          // Asignar viaje
          ListTile(
            leading: Icon(
              Icons.assignment,
              color: disponible ? Colors.green : Colors.grey,
            ),
            title: const Text('Asignar Viaje'),
            subtitle: Text(
              disponible
                  ? 'Asignar un viaje pendiente'
                  : 'Conductor no disponible',
            ),
            enabled: disponible,
            onTap: disponible
                ? () {
              Navigator.pop(context);
              _showAsignarViajeDialog(context, idConductor, onChanged);
            }
                : null,
          ),
        ],
      ),
    );
  }

  void _showAsignarVehiculoDialog(
      BuildContext context, int idConductor, VoidCallback onChanged) {
    showDialog(
      context: context,
      builder: (_) => _AsignarVehiculoDialog(
        idConductor: idConductor,
        onAssigned: onChanged,
      ),
    );
  }

  void _showAsignarViajeDialog(
      BuildContext context, int idConductor, VoidCallback onChanged) {
    showDialog(
      context: context,
      builder: (_) => _AsignarViajeDialog(
        idConductor: idConductor,
        onAssigned: onChanged,
      ),
    );
  }
}

// Dialog para asignar vehículo
class _AsignarVehiculoDialog extends StatefulWidget {
  final int idConductor;
  final VoidCallback onAssigned;

  const _AsignarVehiculoDialog({
    required this.idConductor,
    required this.onAssigned,
  });

  @override
  State<_AsignarVehiculoDialog> createState() => _AsignarVehiculoDialogState();
}

class _AsignarVehiculoDialogState extends State<_AsignarVehiculoDialog> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _vehiculos = [];
  int? _vehiculoSeleccionado;
  bool _loading = false;
  bool _loadingData = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVehiculos();
  }

  Future<void> _loadVehiculos() async {
    try {
      final vehiculos = await _api.listarVehiculos();
      setState(() {
        _vehiculos = vehiculos.cast<Map<String, dynamic>>();
        _loadingData = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error cargando vehículos: $e';
        _loadingData = false;
      });
    }
  }

  Future<void> _asignar() async {
    if (_vehiculoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar un vehículo')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _api.asignarVehiculoAConductor(
        widget.idConductor,
        _vehiculoSeleccionado!,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onAssigned();
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
      title: const Text('Asignar Vehículo'),
      content: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: _vehiculoSeleccionado,
              decoration: const InputDecoration(
                labelText: 'Vehículo',
                border: OutlineInputBorder(),
              ),
              items: _vehiculos.map((v) {
                return DropdownMenuItem(
                  value: v['id_vehiculo'] as int,
                  child: Text(
                    '${v['patente']} - ${v['marca_nombre'] ?? ''}',
                  ),
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

// Dialog para asignar viaje
class _AsignarViajeDialog extends StatefulWidget {
  final int idConductor;
  final VoidCallback onAssigned;

  const _AsignarViajeDialog({
    required this.idConductor,
    required this.onAssigned,
  });

  @override
  State<_AsignarViajeDialog> createState() => _AsignarViajeDialogState();
}

class _AsignarViajeDialogState extends State<_AsignarViajeDialog> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _viajes = [];
  List<Map<String, dynamic>> _vehiculos = [];
  int? _viajeSeleccionado;
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
      final viajes = await _api.listarViajes(estado: 1); // Solo PENDIENTES
      final vehiculos = await _api.listarVehiculos();

      setState(() {
        _viajes = viajes.cast<Map<String, dynamic>>();
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
    if (_viajeSeleccionado == null || _vehiculoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar viaje y vehículo')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _api.asignarViaje(
        _viajeSeleccionado!,
        widget.idConductor,
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
      title: const Text('Asignar Viaje'),
      content: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: _viajeSeleccionado,
              decoration: const InputDecoration(
                labelText: 'Viaje Pendiente',
                border: OutlineInputBorder(),
              ),
              items: _viajes.map((v) {
                final id = v['id_viaje'] as int;
                final fecha = v['agendada_para'] as String?;
                return DropdownMenuItem(
                  value: id,
                  child: Text('Viaje #$id - ${_formatFecha(fecha)}'),
                );
              }).toList(),
              onChanged: (v) => setState(() => _viajeSeleccionado = v),
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
                  child: Text(
                    '${v['patente']} - ${v['marca_nombre'] ?? ''}',
                  ),
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