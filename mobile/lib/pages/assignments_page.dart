// lib/pages/assignments_page.dart - VERSIÓN MEJORADA
import 'package:flutter/material.dart';
import '../services/api_client.dart';

class AssignmentsPage extends StatefulWidget {
  const AssignmentsPage({super.key});

  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage> with AutomaticKeepAliveClientMixin {
  final _api = ApiClient();
  late Future<List<dynamic>> _futureViajes;

  @override
  bool get wantKeepAlive => true;

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
    super.build(context); // Para AutomaticKeepAliveClientMixin

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
                    Text(
                      'No hay viajes pendientes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Todos los viajes han sido asignados',
                      style: TextStyle(color: Colors.grey),
                    ),
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
                return _ViajeCardPendiente(
                  viaje: viaje,
                  onAssign: () => _openAssignDialog(viaje),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ================ Card de viaje pendiente ================
class _ViajeCardPendiente extends StatelessWidget {
  final Map<String, dynamic> viaje;
  final VoidCallback onAssign;

  const _ViajeCardPendiente({
    required this.viaje,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final idViaje = viaje['id_viaje'] as int;
    final agendada = viaje['agendada_para'] as String?;
    final idRuta = viaje['id_ruta'];

    return Card(
      elevation: 2,
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.pending_actions,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Viaje #$idViaje',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'PENDIENTE',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
            const Divider(height: 24),

            // Detalles
            _DetailRow(
              icon: Icons.schedule,
              label: 'Salida programada',
              value: _formatFecha(agendada),
            ),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.route,
              label: 'Ruta',
              value: 'Ruta #$idRuta',
            ),

            const SizedBox(height: 16),

            // Botón de asignar
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAssign,
                icon: const Icon(Icons.assignment_ind),
                label: const Text('Asignar Conductor y Vehículo'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
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
      final dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      return '${dias[dt.weekday - 1]}, ${dt.day}/${dt.month}/${dt.year} - ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return fecha;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
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
      ],
    );
  }
}

// ================ Diálogo de asignación ================
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
        _vehiculos = vehiculos
            .where((v) => v['id_estado_vehiculo'] == 1) // Solo disponibles
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
      _showError('Debes seleccionar conductor y vehículo');
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
        widget.onAssigned(); // ✅ Actualiza la lista
        _showSuccess('Viaje asignado con éxito');
      }
    } catch (e) {
      setState(() {
        _error = 'Error al asignar: $e';
        _loading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.assignment_ind),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Asignar Viaje #${widget.viaje['id_viaje']}'),
          ),
        ],
      ),
      content: _loadingData
          ? const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      )
          : SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info del viaje
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Detalles del viaje',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Salida: ${_formatFecha(widget.viaje['agendada_para'] as String?)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Selector de conductor
              Text(
                'Conductor (${_conductores.length} disponibles)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),

              if (_conductores.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No hay conductores disponibles',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<int>(
                  value: _conductorSeleccionado,
                  decoration: InputDecoration(
                    labelText: 'Seleccionar conductor',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: _conductores.map((c) {
                    return DropdownMenuItem(
                      value: c['id_usuario'] as int,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['nombre_usuario'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            c['correo_usuario'] as String? ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _conductorSeleccionado = v),
                ),
              const SizedBox(height: 20),

              // Selector de vehículo
              Text(
                'Vehículo (${_vehiculos.length} disponibles)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),

              if (_vehiculos.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No hay vehículos disponibles',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<int>(
                  value: _vehiculoSeleccionado,
                  decoration: InputDecoration(
                    labelText: 'Seleccionar vehículo',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.directions_car),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: _vehiculos.map((v) {
                    return DropdownMenuItem(
                      value: v['id_vehiculo'] as int,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${v['patente']} - ${v['marca_nombre'] ?? 'Sin marca'}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${v['modelo'] ?? 'Sin modelo'} • Capacidad: ${v['capacidad'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _vehiculoSeleccionado = v),
                ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
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
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _loading || _conductores.isEmpty || _vehiculos.isEmpty
              ? null
              : _asignar,
          icon: _loading
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(Icons.check),
          label: Text(_loading ? 'Asignando...' : 'Asignar'),
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