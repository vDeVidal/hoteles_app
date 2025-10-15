// lib/pages/guests_page.dart
import 'package:flutter/material.dart';
import '../services/api_client.dart';

String _clean(String? s) => (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

String _fullName(Map<String, dynamic> data) {
  final nombre = _clean(data['nombre_usuario']);
  final ap1 = _clean(data['apellido1_usuario']);
  final ap2 = _clean(data['apellido2_usuario']);
  final apellidos = [ap1, ap2].where((p) => p.isNotEmpty).toList();

  var base = nombre;
  if (apellidos.isNotEmpty) {
    final combined = apellidos.join(' ');
    base = _removeEndingIgnoreCase(base, combined);
    for (final apellido in apellidos) {
      base = _removeEndingIgnoreCase(base, apellido);
    }
  }

  final parts = <String>[];
  final trimmedBase = base.trim();
  if (trimmedBase.isNotEmpty) {
    parts.add(trimmedBase);
  }

  final existingTokens = trimmedBase
      .split(' ')
      .where((t) => t.isNotEmpty)
      .map((t) => t.toLowerCase())
      .toSet();

  for (final apellido in apellidos) {
    final lower = apellido.toLowerCase();
    if (lower.isEmpty || existingTokens.contains(lower)) continue;
    parts.add(apellido);
    existingTokens.add(lower);
  }

  if (parts.isEmpty) {
    final fallback = [nombre, ...apellidos].where((p) => p.isNotEmpty).toList();
    return fallback.join(' ');
  }

  return parts.join(' ');
}

String _extractFirstName(String nombreCompleto, String ap1, String ap2) {
  var result = nombreCompleto.trim();
  final apellidos = [ap1, ap2].where((a) => a.isNotEmpty).toList();

  if (result.isEmpty) {
    return result;
  }

  if (apellidos.isNotEmpty) {
    final combined = apellidos.join(' ');
    result = _removeEndingIgnoreCase(result, combined);
    for (final apellido in apellidos) {
      result = _removeEndingIgnoreCase(result, apellido);
    }
  }

  if (result.isEmpty && nombreCompleto.isNotEmpty) {
    final parts = nombreCompleto.split(' ');
    if (parts.isNotEmpty) {
      result = parts.first;
    }
  }

  return result.trim();
}

String _removeEndingIgnoreCase(String value, String ending) {
  final trimmedValue = value.trimRight();
  final trimmedEnding = ending.trim();

  if (trimmedValue.isEmpty || trimmedEnding.isEmpty) {
    return trimmedValue;
  }

  final lowerValue = trimmedValue.toLowerCase();
  final lowerEnding = trimmedEnding.toLowerCase();

  if (lowerValue == lowerEnding) {
    return '';
  }

  if (lowerValue.endsWith(' $lowerEnding')) {
    return trimmedValue
        .substring(0, trimmedValue.length - trimmedEnding.length - 1)
        .trimRight();
  }

  if (lowerValue.endsWith(lowerEnding)) {
    return trimmedValue
        .substring(0, trimmedValue.length - trimmedEnding.length)
        .trimRight();
  }

  return trimmedValue;
}


class GuestsPage extends StatefulWidget {
  const GuestsPage({super.key});

  @override
  State<GuestsPage> createState() => _GuestsPageState();
}

class _GuestsPageState extends State<GuestsPage> {
  final _api = ApiClient();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchGuests();
  }

  Future<List<dynamic>> _fetchGuests() async {
    // El backend ya filtra automáticamente: supervisor solo ve huéspedes
    return await _api.listarUsuariosDeMiHotel(null);
  }

  Future<void> _reload() async {
    setState(() => _future = _fetchGuests());
  }

  void _openCreate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: _CreateGuestForm(
          onCreated: () {
            Navigator.pop(context);
            _reload();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Huésped creado con éxito')),
            );
          },
        ),
      ),
    );
  }

  void _openEdit(Map<String, dynamic> guest) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: _EditGuestSheet(
          guest: guest,
          onChanged: () {
            Navigator.pop(context);
            _reload();
          },
        ),
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
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _reload,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }

            final data = snap.data ?? [];

            if (data.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hotel, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'No hay huéspedes registrados',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toca el botón + para agregar uno',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: data.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final u = data[i] as Map<String, dynamic>;
                final nombre = _fullName(u);
                final correo = _clean(u['correo_usuario']);
                final disponible = (u['disponible'] == true);
                final suspendido = (u['is_suspended'] == true);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: suspendido
                          ? Colors.red.shade100
                          : disponible
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      child: Icon(
                        suspendido
                            ? Icons.block
                            : disponible
                            ? Icons.check_circle
                            : Icons.person,
                        color: suspendido
                            ? Colors.red
                            : disponible
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                    title: Text(
                      nombre.isEmpty ? 'Sin nombre' : nombre,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(correo.isEmpty ? 'Sin correo' : correo),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              suspendido
                                  ? Icons.block
                                  : disponible
                                  ? Icons.check_circle
                                  : Icons.warning,
                              size: 14,
                              color: suspendido
                                  ? Colors.red
                                  : disponible
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              suspendido
                                  ? 'Suspendido'
                                  : disponible
                                  ? 'Activo'
                                  : 'Inactivo',
                              style: TextStyle(
                                fontSize: 12,
                                color: suspendido
                                    ? Colors.red
                                    : disponible
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openEdit(u),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Huésped'),
      ),
    );
  }
}

// ==================== Crear Huésped ====================
class _CreateGuestForm extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateGuestForm({required this.onCreated});

  @override
  State<_CreateGuestForm> createState() => _CreateGuestFormState();
}

class _CreateGuestFormState extends State<_CreateGuestForm> {
  final _api = ApiClient();
  final _form = GlobalKey<FormState>();

  final _nombre = TextEditingController();
  final _ap1 = TextEditingController();
  final _ap2 = TextEditingController();
  final _tel = TextEditingController();
  final _correo = TextEditingController();

  int _estado = 1;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final correo = _correo.text.trim().toLowerCase();
      String tel = _tel.text.trim();
      if (tel.isNotEmpty && !tel.startsWith('+')) tel = '+$tel';

      final body = {
        "nombre_usuario": _nombre.text.trim(),
        "apellido1_usuario": _ap1.text.trim().isEmpty ? null : _ap1.text.trim(),
        "apellido2_usuario": _ap2.text.trim().isEmpty ? null : _ap2.text.trim(),
        "telefono_usuario": tel.isEmpty ? null : tel,
        "correo_usuario": correo,
        "contrasena_usuario": "12345678",
        "id_tipo_usuario": 1, // HUÉSPED (tipo 1)
        "id_estado_actividad": _estado,
        "must_change_password": true,
      };

      await _api.crearUsuario(body);

      if (mounted) {
        widget.onCreated();
      }
    } catch (e) {
      setState(() {
        _error = 'No se pudo crear: $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.hotel, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Nuevo Huésped',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Nombre
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) =>
              v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),

            // Apellido paterno
            TextFormField(
              controller: _ap1,
              decoration: const InputDecoration(
                labelText: 'Apellido paterno *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
              v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),

            // Apellido materno
            TextFormField(
              controller: _ap2,
              decoration: const InputDecoration(
                labelText: 'Apellido materno',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Teléfono
            TextFormField(
              controller: _tel,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
                hintText: '+56912345678',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            // Correo
            TextFormField(
              controller: _correo,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'Correo inválido'
                  : null,
            ),
            const SizedBox(height: 16),

            // Estado
            DropdownButtonFormField<int>(
              value: _estado,
              decoration: const InputDecoration(
                labelText: 'Estado',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Activo')),
                DropdownMenuItem(value: 2, child: Text('Inactivo')),
              ],
              onChanged: (v) => setState(() => _estado = v ?? 1),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
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
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Info sobre contraseña
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'La contraseña inicial será: 12345678\nEl huésped deberá cambiarla en su primer ingreso.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Botón
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Crear Huésped'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Editar Huésped ====================
class _EditGuestSheet extends StatefulWidget {
  final Map<String, dynamic> guest;
  final VoidCallback onChanged;
  const _EditGuestSheet({required this.guest, required this.onChanged});

  @override
  State<_EditGuestSheet> createState() => _EditGuestSheetState();
}

class _EditGuestSheetState extends State<_EditGuestSheet> {
  final _api = ApiClient();

  late final TextEditingController _nombre;
  late final TextEditingController _ap1;
  late final TextEditingController _ap2;
  late final TextEditingController _correo;
  late final TextEditingController _tel;

  int _estado = 1;

  @override
  void initState() {
    super.initState();

    // Parsear nombre completo si es necesario
    final nombreCompleto = _clean(widget.guest['nombre_usuario']);
    String nombre = nombreCompleto;
    String ap1 = _clean(widget.guest['apellido1_usuario']);
    String ap2 = _clean(widget.guest['apellido2_usuario']);

    if (ap1.isEmpty && ap2.isEmpty && nombreCompleto.contains(' ')) {
      final partes = nombreCompleto.split(' ');
      if (partes.length >= 3) {
        nombre = partes[0];
        ap1 = partes[1];
        ap2 = partes.sublist(2).join(' ');
      } else if (partes.length == 2) {
        nombre = partes[0];
        ap1 = partes[1];
      }
    } else {
      final deduced = _extractFirstName(nombreCompleto, ap1, ap2);
      if (deduced.isNotEmpty) {
        nombre = deduced;
      }
    }
    _nombre = TextEditingController(text: nombre);
    _ap1 = TextEditingController(text: ap1);
    _ap2 = TextEditingController(text: ap2);
    _correo = TextEditingController(text: _clean(widget.guest['correo_usuario']));
    _tel = TextEditingController(text: _clean(widget.guest['telefono_usuario']));

    _estado = (widget.guest['id_estado_actividad'] as int?) ?? 1;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _ap1.dispose();
    _ap2.dispose();
    _correo.dispose();
    _tel.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    try {
      String correo = _correo.text.trim().toLowerCase();
      String tel = _tel.text.trim();
      if (tel.isNotEmpty && !tel.startsWith('+')) tel = '+$tel';

      await _api.actualizarUsuario(
        widget.guest['id_usuario'] as int,
        {
          'nombre_usuario': _nombre.text.trim(),
          'apellido1_usuario': _ap1.text.trim().isEmpty ? null : _ap1.text.trim(),
          'apellido2_usuario': _ap2.text.trim().isEmpty ? null : _ap2.text.trim(),
          'correo_usuario': correo,
          'telefono_usuario': tel.isEmpty ? null : tel,
          'id_estado_actividad': _estado,
        },
      );

      if (mounted) {
        widget.onChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Huésped actualizado con éxito')),
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

  Future<void> _suspender() async {
    final motivo = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        final motivoCtrl = TextEditingController();
        return AlertDialog(
          title: const Text('Motivo de suspensión'),
          content: TextField(
            controller: motivoCtrl,
            decoration: const InputDecoration(hintText: 'Escribe el motivo'),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, motivoCtrl.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Suspender'),
            ),
          ],
        );
      },
    );

    if (motivo == null || motivo.isEmpty) return;

    try {
      await _api.suspenderUsuario(widget.guest['id_usuario'] as int, motivo);
      if (mounted) {
        widget.onChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Huésped suspendido')),
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

  Future<void> _reactivar() async {
    try {
      await _api.reactivarUsuario(widget.guest['id_usuario'] as int);
      if (mounted) {
        widget.onChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Huésped reactivado')),
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
    final suspendido = (widget.guest['is_suspended'] == true);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.hotel, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Editar Huésped',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _nombre,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _ap1,
            decoration: const InputDecoration(
              labelText: 'Apellido paterno',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _ap2,
            decoration: const InputDecoration(
              labelText: 'Apellido materno',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _correo,
            decoration: const InputDecoration(
              labelText: 'Correo',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _tel,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<int>(
            value: _estado,
            decoration: const InputDecoration(
              labelText: 'Estado',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Activo')),
              DropdownMenuItem(value: 2, child: Text('Inactivo')),
            ],
            onChanged: (v) => setState(() => _estado = v ?? 1),
          ),

          const SizedBox(height: 20),

          FilledButton(
            onPressed: _guardar,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Guardar Cambios'),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: suspendido ? null : _suspender,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Suspender'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: suspendido ? _reactivar : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Reactivar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}