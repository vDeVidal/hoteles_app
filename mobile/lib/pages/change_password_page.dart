// lib/pages/change_password_page.dart
import 'package:flutter/material.dart';
import '../services/api_client.dart';

class ChangePasswordPage extends StatefulWidget {
  final VoidCallback? onDone;           // <- opcional
  const ChangePasswordPage({super.key, this.onDone});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _api = ApiClient();
  bool _loading = false;
  String? _err;

  Future<void> _submit() async {
    setState(() { _loading = true; _err = null; });
    try {
      await _api.cambiarPassword(_old.text, _new.text);
      if (!mounted) return;
      // Si te pasaron callback úsalo; si no, cierra
      if (widget.onDone != null) {
        widget.onDone!();
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _err = 'No se pudo cambiar la contraseña');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _old, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña actual')),
            TextField(controller: _new, obscureText: true, decoration: const InputDecoration(labelText: 'Nueva contraseña (min 8)')),
            const SizedBox(height: 12),
            if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading ? const CircularProgressIndicator() : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
