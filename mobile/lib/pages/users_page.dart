// lib/pages/users_page.dart
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/hotel_session.dart';

String _clean(String? s) => (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

String _fullNameOf(Map<String, dynamic> u) {
  final nombre = _clean(u['nombre_usuario']);
  final ap1 = _clean(u['apellido1_usuario']);
  final ap2 = _clean(u['apellido2_usuario']);
  final parts = <String>[];
  if (nombre.isNotEmpty) parts.add(nombre);
  if (ap1.isNotEmpty) parts.add(ap1);
  if (ap2.isNotEmpty) parts.add(ap2);
  return parts.join(' ');
}

int? _tipoUsuario(dynamic raw) {
  if (raw is int) return raw;
  if (raw is String) return int.tryParse(raw);
  return null;
}

class UsersPage extends StatefulWidget {
  final bool soloPersonal; // true = solo conductores/supervisores, false = solo usuarios huéspedes

  const UsersPage({super.key, this.soloPersonal = false});

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
      final users = await _api.listarUsuariosDeMiHotel(hid);
      return _filterUsers(users);
    } else {
      final users = await _api.listarUsuariosDeMiHotel(null);
      return _filterUsers(users);
    }
  }

  List<dynamic> _filterUsers(List<dynamic> users) {
    // Personal (conductores y supervisores)
    if (widget.soloPersonal || AuthService.isAdmin) {
      return users
          .where((u) {
            final tipo = _tipoUsuario(u['id_tipo_usuario']);
            return tipo == 2 || tipo == 3;
          })
          .toList();
    }

    // Huéspedes únicamente
    return users
        .where((u) => _tipoUsuario(u['id_tipo_usuario']) == 1)
        .toList();
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
          onCreated: (_) => _reload(),
          isAdmin: AuthService.isAdmin,
          hotelId: HotelSession.hotelId,
          soloPersonal: widget.soloPersonal,
        ),
      ),
    );
  }

  void _openActions(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: _EditUserSheet(user: user, onChanged: _reload),
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
          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(widget.soloPersonal
                      ? 'Sin personal registrado'
                      : 'Sin usuarios huéspedes'),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final u = data[i] as Map<String, dynamic>;
              final nombre = _fullNameOf(u);
              final correo = (u['correo_usuario'] ?? '').toString();
              final tipo = (u['tipo_usuario_nombre'] ?? '—').toString();
              final disponible = (u['disponible'] == true);
              final estadoTxt = disponible ? 'Disponible' : 'Sin disponibilidad';
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(nombre),
                subtitle: Text('$correo\n$tipo • $estadoTxt'),
                isThreeLine: true,
                onTap: () => _openActions(u),
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

// -------------------- Crear Usuario --------------------
class _CreateUserForm extends StatefulWidget {
  final void Function(Map<String, dynamic>) onCreated;
  final bool isAdmin;
  final int? hotelId;
  final bool soloPersonal;

  const _CreateUserForm({
    required this.onCreated,
    required this.isAdmin,
    required this.hotelId,
    required this.soloPersonal,
  });

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

  int _tipo = 2; // Por defecto conductor para personal
  int _estado = 1;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Admin siempre crea personal (conductor o supervisor)
    // Supervisor: si soloPersonal=true crea personal, si no crea huéspedes
    if (widget.isAdmin || widget.soloPersonal) {
      _tipo = 2; // Por defecto conductor
    } else {
      _tipo = 1; // Usuario huésped
    }
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
        if (widget.isAdmin && widget.hotelId != null) "id_hotel": widget.hotelId,
        "must_change_password": true,
      };

      final created = await _api.crearUsuario(body);

      if (mounted) {
        Navigator.pop(context);
        widget.onCreated(created);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario creado con éxito')),
        );
      }
    } catch (e) {
      setState(() { _error = 'No se pudo crear: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.soloPersonal ? 'Nuevo Personal' : 'Nuevo Usuario Huésped',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextFormField(controller: _nombre, decoration: const InputDecoration(labelText: 'Nombre'), validator: (v)=> v==null||v.isEmpty?'Requerido':null),
            TextFormField(controller: _ap1, decoration: const InputDecoration(labelText: 'Apellido paterno'), validator: (v)=> v==null||v.isEmpty?'Requerido':null),
            TextFormField(controller: _ap2, decoration: const InputDecoration(labelText: 'Apellido materno')),
            TextFormField(controller: _tel, decoration: const InputDecoration(labelText: 'Teléfono')),
            TextFormField(
              controller: _correo,
              decoration: const InputDecoration(labelText: 'Correo'),
              validator: (v)=> (v==null||!v.contains('@'))?'Correo inválido':null,
            ),
            const SizedBox(height: 8),

            // Dropdown de tipo: varía según rol
            if (widget.isAdmin || widget.soloPersonal)
              DropdownButtonFormField<int>(
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo de personal'),
                items: const [
                  DropdownMenuItem(value: 2, child: Text('Conductor')),
                  DropdownMenuItem(value: 3, child: Text('Supervisor')),
                ],
                onChanged: (v)=> setState(()=> _tipo = v ?? 2),
              )
            else
            // Supervisor creando huéspedes: tipo fijo en 1, no mostrar dropdown
              const SizedBox.shrink(),

            DropdownButtonFormField<int>(
              value: _estado,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Activo')),
                DropdownMenuItem(value: 2, child: Text('Inactivo')),
              ],
              onChanged: (v)=> setState(()=> _estado = v ?? 1),
            ),

            if (_error != null)
              Padding(padding: const EdgeInsets.only(top:8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: _loading? null : _submit,
                  child: _loading? const CircularProgressIndicator() : const Text('Crear'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// -------------------- Editar / Suspender / Reactivar --------------------
class _EditUserSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onChanged;
  const _EditUserSheet({required this.user, this.onChanged});

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

    String rawNombre = _clean(widget.user['nombre_usuario']?.toString());
    String rawAp1 = _clean(widget.user['apellido1_usuario']?.toString());
    String rawAp2 = _clean(widget.user['apellido2_usuario']?.toString());

    if (rawAp1.isEmpty && rawAp2.isEmpty) {
      final tokens = rawNombre.split(' ').where((t) => t.isNotEmpty).toList();
      if (tokens.length >= 3) {
        rawNombre = tokens.first;
        rawAp1 = tokens[1];
        rawAp2 = tokens.sublist(2).join(' ');
      } else if (tokens.length == 2) {
        rawNombre = tokens.first;
        rawAp1 = tokens.last;
      }
    }

    _nombre = TextEditingController(text: rawNombre);
    _ap1 = TextEditingController(text: rawAp1);
    _ap2 = TextEditingController(text: rawAp2);
    _correo = TextEditingController(text: _clean(widget.user['correo_usuario']?.toString()));
    _tel = TextEditingController(text: _clean(widget.user['telefono_usuario']?.toString()));

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
        Navigator.pop(context);
        widget.onChanged?.call();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar')),
      );
    }
  }

  Future<void> _suspender() async {
    final motivo = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        final motivoCtrl = TextEditingController();
        return AlertDialog(
          title: const Text('Motivo de suspensión'),
          content: TextField(controller: motivoCtrl, decoration: const InputDecoration(hintText: 'Escribe el motivo')),
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(ctx, null), child: const Text('Cancelar')),
            FilledButton(onPressed: ()=> Navigator.pop(ctx, motivoCtrl.text.trim()), child: const Text('Suspender')),
          ],
        );
      },
    );
    if (motivo == null || motivo.isEmpty) return;
    await _api.suspenderUsuario(widget.user['id_usuario'] as int, motivo);
    if (mounted) {
      Navigator.pop(context);
      widget.onChanged?.call();
    }
  }

  Future<void> _reactivar() async {
    await _api.reactivarUsuario(widget.user['id_usuario'] as int);
    if (mounted) {
      Navigator.pop(context);
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final suspendido = (widget.user['is_suspended'] == true);
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Editar usuario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: _nombre, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: _ap1, decoration: const InputDecoration(labelText: 'Apellido paterno')),
            TextField(controller: _ap2, decoration: const InputDecoration(labelText: 'Apellido materno')),
            TextField(controller: _correo, decoration: const InputDecoration(labelText: 'Correo')),
            TextField(controller: _tel, decoration: const InputDecoration(labelText: 'Teléfono')),
            const SizedBox(height: 8),

            DropdownButtonFormField<int>(
              value: _tipo,
              items: const [
                DropdownMenuItem(value: 1, child: Text('Usuario Huésped')),
                DropdownMenuItem(value: 2, child: Text('Conductor')),
                DropdownMenuItem(value: 3, child: Text('Supervisor')),
              ],
              onChanged: (v) => setState(() => _tipo = v ?? 2),
              decoration: const InputDecoration(labelText: 'Tipo'),
            ),

            DropdownButtonFormField<int>(
              value: _estado,
              items: const [
                DropdownMenuItem(value: 1, child: Text('Activo')),
                DropdownMenuItem(value: 2, child: Text('Inactivo')),
              ],
              onChanged: (v) => setState(() => _estado = v ?? 1),
              decoration: const InputDecoration(labelText: 'Estado'),
            ),

            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: FilledButton(onPressed: _guardar, child: const Text('Guardar'))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: suspendido ? null : _suspender,
                  child: const Text('Suspender'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: suspendido ? _reactivar : null,
                  child: const Text('Reactivar'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}