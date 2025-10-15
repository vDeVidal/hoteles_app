// lib/pages/guest_request_trip_page.dart
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class GuestRequestTripPage extends StatefulWidget {
  const GuestRequestTripPage({super.key});

  @override
  State<GuestRequestTripPage> createState() => _GuestRequestTripPageState();
}

class _GuestRequestTripPageState extends State<GuestRequestTripPage> {
  final _api = ApiClient();
  late Future<List<dynamic>> _futureRutas;

  @override
  void initState() {
    super.initState();
    _futureRutas = _loadRutas();
  }

  Future<List<dynamic>> _loadRutas() async {
    try {
      return await _api.listarRutas(null);
    } catch (e) {
      debugPrint('Error cargando rutas: $e');
      return [];
    }
  }

  Future<void> _reload() async {
    setState(() => _futureRutas = _loadRutas());
  }

  void _showRequestDialog(Map<String, dynamic> ruta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RequestTripSheet(
        ruta: ruta,
        onRequested: () {
          Navigator.pop(context);
          _reload();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Viaje solicitado con éxito'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<dynamic>>(
          future: _futureRutas,
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

            final rutas = snap.data ?? [];

            if (rutas.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.route, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'No hay rutas disponibles',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Contacta con recepción',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header
                const Text(
                  'Solicitar Transporte',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selecciona tu destino',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),

                // Lista de rutas
                ...rutas.map((ruta) {
                  return _RutaCard(
                    ruta: ruta as Map<String, dynamic>,
                    onTap: () => _showRequestDialog(ruta),
                  );
                }).toList(),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ====================== Card de Ruta ======================
class _RutaCard extends StatelessWidget {
  final Map<String, dynamic> ruta;
  final VoidCallback onTap;

  const _RutaCard({required this.ruta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final nombre = ruta['nombre_ruta'] as String? ?? 'Sin nombre';
    final origen = ruta['origen_ruta'] as String? ?? 'Origen';
    final destino = ruta['destino_ruta'] as String? ?? 'Destino';
    final precio = ruta['precio_ruta'];
    final duracion = ruta['duracion_aproximada'] as int?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nombre de la ruta
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.route,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              const SizedBox(height: 16),

              // Origen -> Destino
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.circle, size: 12, color: Colors.green[700]),
                            const SizedBox(width: 8),
                            const Text(
                              'Origen',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          origen,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.red[700]),
                            const SizedBox(width: 8),
                            const Text(
                              'Destino',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          destino,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Info adicional (precio y duración)
              Row(
                children: [
                  if (precio != null) ...[
                    Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '\$${precio.toString()}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (duracion != null) ...[
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '$duracion min',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================== Sheet de Solicitud ======================
class _RequestTripSheet extends StatefulWidget {
  final Map<String, dynamic> ruta;
  final VoidCallback onRequested;

  const _RequestTripSheet({required this.ruta, required this.onRequested});

  @override
  State<_RequestTripSheet> createState() => _RequestTripSheetState();
}

class _RequestTripSheetState extends State<_RequestTripSheet> {
  final _api = ApiClient();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  bool _loading = false;
  String? _error;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _requestTrip() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final agendadaPara = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Crear el viaje
      await _api.crearViaje({
        'id_ruta': widget.ruta['id_ruta'],
        'agendada_para': agendadaPara.toIso8601String(),
      });

      if (mounted) {
        widget.onRequested();
      }
    } catch (e) {
      setState(() {
        _error = 'Error al solicitar viaje: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.ruta['nombre_ruta'] as String? ?? '';
    final origen = widget.ruta['origen_ruta'] as String? ?? '';
    final destino = widget.ruta['destino_ruta'] as String? ?? '';
    final precio = widget.ruta['precio_ruta'];
    final duracion = widget.ruta['duracion_aproximada'] as int?;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.directions_car, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Solicitar Viaje',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 32),

            // Info de la ruta
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Origen', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(origen, style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward, size: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Destino', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(destino, style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (precio != null || duracion != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (precio != null) ...[
                          const Icon(Icons.attach_money, size: 16),
                          Text('\$$precio', style: const TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(width: 16),
                        ],
                        if (duracion != null) ...[
                          const Icon(Icons.access_time, size: 16),
                          Text('$duracion min', style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Selección de fecha
            const Text('¿Cuándo necesitas el viaje?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
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
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Botón de solicitar
            FilledButton.icon(
              onPressed: _loading ? null : _requestTrip,
              icon: _loading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.check),
              label: Text(_loading ? 'Solicitando...' : 'Confirmar Solicitud'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}