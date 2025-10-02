// lib/pages/routes_page.dart
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/hotel_session.dart';
import '../services/auth_service.dart';

class RoutesPage extends StatefulWidget {
  const RoutesPage({super.key});
  @override
  State<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends State<RoutesPage> {
  final _api = ApiClient();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<dynamic>> _fetch() async {
    // Si eres admin exigimos hotel elegido; para otros el backend usa su hotel
    if (AuthService.isAdmin) {
      final hid = HotelSession.hotelId;
      if (hid == null) throw 'Selecciona un hotel primero';
      return _api.listarRutas(hid);
    }
    return _api.listarRutas(null);
  }

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
        child: _RouteForm(onSaved: _reload),
      ),
    );
  }

  void _openEdit(Map<String, dynamic> ruta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: _RouteForm(onSaved: _reload, existing: ruta),
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
          if (data.isEmpty) return const Center(child: Text('Sin rutas'));

          return ListView.separated(
            itemCount: data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = data[i] as Map<String, dynamic>;
              final nombre   = (r['nombre_ruta'] ?? '—').toString();
              final origen   = (r['origen_ruta'] ?? '—').toString();
              final destino  = (r['destino_ruta'] ?? '—').toString();
              final precio   = (r['precio_ruta'] ?? 0).toString();
              final durMin   = (r['duracion_aproximada'] ?? 0).toString();
              final estado   = ((r['id_estado_actividad'] ?? 1) == 1) ? 'Activa' : 'Inactiva';

              return ListTile(
                leading: const Icon(Icons.alt_route),
                title: Text(nombre),
                subtitle: Text('$origen → $destino\n$precio • $durMin min • $estado'),
                isThreeLine: true,
                onTap: () => _openEdit(r),
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

/// ================ Formulario Crear / Editar Ruta =================
class _RouteForm extends StatefulWidget {
  final VoidCallback onSaved;
  final Map<String, dynamic>? existing;
  const _RouteForm({required this.onSaved, this.existing});
  @override
  State<_RouteForm> createState() => _RouteFormState();
}

class _RouteFormState extends State<_RouteForm> {
  final _api = ApiClient();
  final _form = GlobalKey<FormState>();

  final _nombre  = TextEditingController();
  final _origen  = TextEditingController();
  final _destino = TextEditingController();
  final _precio  = TextEditingController(); // decimal
  final _dur     = TextEditingController(); // minutos

  int _estado = 1; // 1 activo, 2 inactivo
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final r = widget.existing!;
      _nombre.text   = (r['nombre_ruta'] ?? '').toString();
      _origen.text   = (r['origen_ruta'] ?? '').toString();
      _destino.text  = (r['destino_ruta'] ?? '').toString();
      _precio.text   = (r['precio_ruta'] ?? '').toString();
      _dur.text      = (r['duracion_aproximada'] ?? '').toString();
      _estado        = (r['id_estado_actividad'] as int?) ?? 1;
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final body = {
        'nombre_ruta': _nombre.text.trim(),
        'origen_ruta': _origen.text.trim(),
        'destino_ruta': _destino.text.trim(),
        'precio_ruta': double.tryParse(_precio.text.replaceAll(',', '.').trim()),
        'duracion_aproximada': int.tryParse(_dur.text.trim()),
        'id_estado_actividad': _estado,
        // El id_hotel lo fija el backend (según token + HotelSession si es admin)
      };

      if (widget.existing == null) {
        await _api.crearRuta(body);
      } else {
        await _api.actualizarRuta(widget.existing!['id_ruta'] as int, body);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.existing == null
              ? 'Ruta creada con éxito'
              : 'Ruta actualizada con éxito')),
        );
      }
    } catch (e) {
      setState(() { _error = 'Error: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
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
            Text(isEdit ? 'Editar ruta' : 'Nueva ruta',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v)=> v==null||v.trim().isEmpty ? 'Requerido' : null,
            ),
            TextFormField(
              controller: _origen,
              decoration: const InputDecoration(labelText: 'Origen'),
              validator: (v)=> v==null||v.trim().isEmpty ? 'Requerido' : null,
            ),
            TextFormField(
              controller: _destino,
              decoration: const InputDecoration(labelText: 'Destino'),
              validator: (v)=> v==null||v.trim().isEmpty ? 'Requerido' : null,
            ),
            TextFormField(
              controller: _precio,
              decoration: const InputDecoration(labelText: 'Precio'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v){
                final n = double.tryParse((v??'').replaceAll(',', '.'));
                return (n==null || n<0) ? 'Precio inválido' : null;
              },
            ),
            TextFormField(
              controller: _dur,
              decoration: const InputDecoration(labelText: 'Duración (min)'),
              keyboardType: TextInputType.number,
              validator: (v){
                final n = int.tryParse(v??'');
                return (n==null || n<=0) ? 'Duración inválida' : null;
              },
            ),
            DropdownButtonFormField<int>(
              value: _estado,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Activa')),
                DropdownMenuItem(value: 2, child: Text('Inactiva')),
              ],
              onChanged: (v)=> setState(()=> _estado = v ?? 1),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top:8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: _loading? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : Text(isEdit ? 'Guardar' : 'Crear'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
