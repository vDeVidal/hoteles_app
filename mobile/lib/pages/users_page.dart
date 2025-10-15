// lib/pages/users_page.dart - CORRECCIÓN FINAL
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/hotel_session.dart';

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


class UsersPage extends StatefulWidget {
  const UsersPage({super.key}); // Sin parámetro soloPersonal

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _api = ApiClient();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchUsers();
  }

  Future<List<dynamic>> _fetchUsers() async {
    if (AuthService.isAdmin) {
      final hid = HotelSession.hotelId;
      if (hid == null) throw 'Selecciona un hotel primero';
      return await _api.listarUsuariosDeMiHotel(hid);
    } else {
      // Supervisor: el backend ya filtra y devuelve SOLO huéspedes
      return await _api.listarUsuariosDeMiHotel(null);
    }
  }

  Future<void> _reload() async {
    setState(() => _future = _fetchUsers());
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
        child: _CreateUserForm(
          onCreated: () {
            Navigator.pop(context);
            _reload();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Usuario creado con éxito')),
            );
          },
        ),
      ),
    );
  }

  void _openEdit(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: _EditUserSheet(
          user: user,
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
    // Determinar texto del botón según rol
    final isAdmin = AuthService.isAdmin;
    final buttonText = isAdmin ? 'Nuevo Personal' : 'Nuevo Huésped';

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
                    const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      isAdmin ? 'Sin personal registrado' : 'Sin usuarios huéspedes',
                      style: const TextStyle(fontSize: 16),
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
                final tipo = _clean(u['tipo_usuario_nombre']);
                final disponible = (u['disponible'] == true);
                final estadoTxt = disponible ? 'Disponible' : 'Sin disponibilidad';

                return ListTile(
                  leading: CircleAvatar(
                    child: Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : '?'),
                  ),
                  title: Text(nombre.isEmpty ? 'Sin nombre' : nombre),
                  subtitle: Text('$correo\n$tipo • $estadoTxt'),
                  isThreeLine: true,
                  onTap: () => _openEdit(u),
                  trailing: const Icon(Icons.edit, size: 20),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: Text(buttonText),
      ),
    );
  }
}

// ==================== Crear Usuario ====================
class _CreateUserForm extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateUserForm({required this.onCreated});

  @override
  State<_CreateUserForm> createState() => _CreateUserFormState();
}

class _CreateUserFormState extends State<_CreateUserForm> {
  final _api = ApiClient();
  final _form = GlobalKey<FormState>();

  final _nombre = TextEditingController();
  final _ap1 = TextEditingController();
  final _ap2 = TextEditingController();
  final _tel = TextEditingController();
  final _correo = TextEditingController();

  int _tipo = 1;
  int _estado = 1;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Admin: conductor por defecto
    // Supervisor: huésped por defecto (forzado)
    _tipo = AuthService.isAdmin ? 2 : 1;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    setState(() { _loading = true; _error = null; });

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
        "id_tipo_usuario": _tipo,
        "id_estado_actividad": _estado,
        if (AuthService.isAdmin && HotelSession.hotelId != null)
          "id_hotel": HotelSession.hotelId,
        "must_change_password": true,
      };

      await _api.crearUsuario(body);

      if (mounted) {
        widget.onCreated();
      }
    } catch (e) {
      setState(() { _error = 'No se pudo crear: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = AuthService.isAdmin;
    final title = isAdmin ? 'Nuevo Personal' : 'Nuevo Huésped';

    return Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _ap1,
              decoration: const InputDecoration(
                labelText: 'Apellido paterno',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _ap2,
              decoration: const InputDecoration(
                labelText: 'Apellido materno',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _tel,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _correo,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@')) ? 'Correo inválido' : null,
            ),
            const SizedBox(height: 16),

            // Solo admin ve el dropdown de tipo
            if (isAdmin)
              DropdownButtonFormField<int>(
                value: _tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de personal',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 2, child: Text('Conductor')),
                  DropdownMenuItem(value: 3, child: Text('Supervisor')),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? 2),
              ),

            if (isAdmin) const SizedBox(height: 12),

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

            const SizedBox(height: 20),

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
                    : const Text('Crear Usuario'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Editar Usuario ====================
class _EditUserSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onChanged;
  const _EditUserSheet({required this.user, required this.onChanged});

  @override
  State<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<_EditUserSheet> {
  final _api = ApiClient();

  late final TextEditingController _nombre;
  late final TextEditingController _ap1;
  late final TextEditingController _ap2;
  late final TextEditingController _correo;
  late final TextEditingController _tel;

  int _tipo = 2;
  int _estado = 1;

  @override
  void initState() {
    super.initState();

    // CORRECCIÓN: Si nombre_usuario tiene el nombre completo, parsearlo SOLO para edición
    final nombreCompleto = _clean(widget.user['nombre_usuario']);
    String nombre = nombreCompleto;
    String ap1 = _clean(widget.user['apellido1_usuario']);
    String ap2 = _clean(widget.user['apellido2_usuario']);

    // Si los apellidos están vacíos pero hay nombre completo, intentar parsear
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
    _correo = TextEditingController(text: _clean(widget.user['correo_usuario']));
    _tel = TextEditingController(text: _clean(widget.user['telefono_usuario']));

    _tipo = (widget.user['id_tipo_usuario'] as int?) ?? 2;
    _estado = (widget.user['id_estado_actividad'] as int?) ?? 1;
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
        widget.user['id_usuario'] as int,
        {
          'nombre_usuario': _nombre.text.trim(),
          'apellido1_usuario': _ap1.text.trim().isEmpty ? null : _ap1.text.trim(),
          'apellido2_usuario': _ap2.text.trim().isEmpty ? null : _ap2.text.trim(),
          'correo_usuario': correo,
          'telefono_usuario': tel.isEmpty ? null : tel,
          'id_tipo_usuario': _tipo,
          'id_estado_actividad': _estado,
        },
      );

      if (mounted) {
        widget.onChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario actualizado con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
      await _api.suspenderUsuario(widget.user['id_usuario'] as int, motivo);
      if (mounted) {
        widget.onChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario suspendido')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reactivar() async {
    try {
      await _api.reactivarUsuario(widget.user['id_usuario'] as int);
      if (mounted) {
        widget.onChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario reactivado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suspendido = (widget.user['is_suspended'] == true);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Editar usuario',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

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
            value: _tipo,
            decoration: const InputDecoration(
              labelText: 'Tipo',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Usuario Huésped')),
              DropdownMenuItem(value: 2, child: Text('Conductor')),
              DropdownMenuItem(value: 3, child: Text('Supervisor')),
            ],
            onChanged: (v) => setState(() => _tipo = v ?? 2),
          ),
          const SizedBox(height: 12),

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
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
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