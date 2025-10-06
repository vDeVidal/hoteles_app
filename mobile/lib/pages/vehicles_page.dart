// lib/pages/vehicles_page.dart
import 'package:flutter/material.dart';
import '../services/api_client.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});
  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final _api = ApiClient();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<dynamic>> _fetch() async => _api.listarVehiculos();

  Future<void> _reload() async {
    setState(() => _future = _fetch());
  }

  void _openCreate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: _VehicleForm(onSaved: _reload),
      ),
    );
  }

  void _openEdit(Map<String, dynamic> vehiculo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: _VehicleForm(onSaved: _reload, existing: vehiculo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final data = snap.data ?? [];
          if (data.isEmpty) return const Center(child: Text('Sin vehículos'));

          return ListView.separated(
            itemCount: data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final v = data[i] as Map<String, dynamic>;
              final patente = v['patente'] ?? '—';
              final marca   = v['marca_nombre'] ?? '—';
              final modelo  = v['modelo'] ?? '';
              final estado  = v['estado_nombre'] ?? '—';
              return ListTile(
                leading: const Icon(Icons.local_taxi),
                title: Text('$patente • $marca'),
                subtitle: Text('${modelo.isNotEmpty ? modelo : 'Sin modelo'}\nEstado: $estado'),
                isThreeLine: true,
                onTap: () => _openEdit(v),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// ====================== Formulario Crear/Editar ======================
class _VehicleForm extends StatefulWidget {
  final VoidCallback onSaved;
  final Map<String, dynamic>? existing;
  const _VehicleForm({required this.onSaved, this.existing});
  @override
  State<_VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<_VehicleForm> {
  final _api = ApiClient();
  final _form = GlobalKey<FormState>();

  final _patente = TextEditingController();
  final _modelo  = TextEditingController();
  final _anio    = TextEditingController();
  final _cap     = TextEditingController();

  List<Map<String, dynamic>> _marcas = [];
  List<Map<String, dynamic>> _estados = [
    {'id_estado_vehiculo': 1, 'nombre_estado_vehiculo': 'Activo'},
    {'id_estado_vehiculo': 2, 'nombre_estado_vehiculo': 'En mantención'},
    {'id_estado_vehiculo': 3, 'nombre_estado_vehiculo': 'Baja'},
  ];

  int? _marcaSel;
  int _estadoSel = 1;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMarcas();

    if (widget.existing != null) {
      final v = widget.existing!;
      _patente.text = v['patente'] ?? '';
      _modelo.text  = v['modelo'] ?? '';
      _anio.text    = (v['anio'] ?? '').toString();
      _cap.text     = (v['capacidad'] ?? '').toString();
      _marcaSel     = v['id_marca_vehiculo'] as int?;
      _estadoSel    = v['id_estado_vehiculo'] as int? ?? 1;
    }
  }

  Future<void> _loadMarcas() async {
    try {
      final list = await _api.listarMarcasVehiculo();
      setState(() {
        _marcas = list.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint('Error cargando marcas: $e');
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final body = {
        'patente': _patente.text.trim(),
        'id_marca_vehiculo': _marcaSel,
        'modelo': _modelo.text.trim().isEmpty ? null : _modelo.text.trim(),
        'anio': int.tryParse(_anio.text.trim()),
        'capacidad': int.tryParse(_cap.text.trim()),
        'id_estado_vehiculo': _estadoSel,
      };

      if (widget.existing == null) {
        await _api.crearVehiculo(body);
      } else {
        await _api.actualizarVehiculo(widget.existing!['id_vehiculo'] as int, body);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved(); // ✅ Actualiza inmediatamente
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.existing == null
              ? 'Vehículo creado con éxito'
              : 'Vehículo actualizado con éxito')),
        );
      }
    } catch (e) {
      setState(() { _error = 'Error: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }


  Future<void> _addMarcaDialog() async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva marca'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Nombre de marca')),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: ()=> Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Crear')),
        ],
      ),
    );

    if (nombre != null && nombre.isNotEmpty) {
      try {
        final m = await _api.crearMarcaVehiculo(nombre);
        await _loadMarcas();
        setState(() => _marcaSel = m['id_marca_vehiculo'] as int);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creando marca: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEdit ? 'Editar vehículo' : 'Nuevo vehículo',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextFormField(controller: _patente, decoration: const InputDecoration(labelText: 'Patente'),
                validator: (v)=> v==null||v.isEmpty?'Requerido':null),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _marcaSel,
                    decoration: const InputDecoration(labelText: 'Marca'),
                    items: _marcas.map((m) =>
                        DropdownMenuItem(value: m['id_marca_vehiculo'] as int, child: Text(m['nombre_marca_vehiculo'] ?? '')))
                        .toList(),
                    onChanged: (v)=> setState(()=> _marcaSel = v),
                    validator: (v)=> v==null?'Selecciona marca':null,
                  ),
                ),
                IconButton(onPressed: _addMarcaDialog, icon: const Icon(Icons.add)),
              ],
            ),
            TextFormField(controller: _modelo, decoration: const InputDecoration(labelText: 'Modelo')),
            TextFormField(controller: _anio, decoration: const InputDecoration(labelText: 'Año'), keyboardType: TextInputType.number),
            TextFormField(controller: _cap, decoration: const InputDecoration(labelText: 'Capacidad'), keyboardType: TextInputType.number),
            DropdownButtonFormField<int>(
              value: _estadoSel,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: _estados.map((e) =>
                  DropdownMenuItem(value: e['id_estado_vehiculo'] as int, child: Text(e['nombre_estado_vehiculo'] ?? '')))
                  .toList(),
              onChanged: (v)=> setState(()=> _estadoSel = v ?? 1),
            ),
            if (_error != null)
              Padding(padding: const EdgeInsets.only(top:8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: _loading? null : _submit,
                  child: _loading? const CircularProgressIndicator() : Text(isEdit? 'Guardar' : 'Crear'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
