// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'change_password_page.dart';
import 'login_page.dart';
import '../services/hotel_session.dart';


class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  String _roleName(int r) {
    switch (r) {
      case 4: return 'Administrador';
      case 3: return 'Supervisor';
      case 2: return 'Conductor';
      default: return 'Usuario';
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = AuthService.role;
    // intenta armar nombre completo desde los claims si existen
    final n   = (AuthService.claim('nombre_usuario') ?? AuthService.claim('name') ?? '') as String? ?? '';
    final ap1 = (AuthService.claim('apellido1_usuario') ?? '') as String? ?? '';
    final ap2 = (AuthService.claim('apellido2_usuario') ?? '') as String? ?? '';
    final fullName = [n, ap1, ap2].where((p) => p.isNotEmpty).join(' ').trim();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mi perfil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (fullName.isNotEmpty) Text('Nombre: $fullName'),
          Text('Tipo de usuario: ${_roleName(role)}'),
          if (role == 4) const Text('Permisos: administrador (todos los hoteles)'),
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
              );
            },
            icon: const Icon(Icons.lock),
            label: const Text('Cambiar contraseña'),
          ),

          const Spacer(),
          // dentro del Column de ProfilePage, cerca del botón de Cerrar sesión
          if (AuthService.isAdmin) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                // limpiar hotel y navegar al selector
                HotelSession.clear();
                Navigator.of(context).pushNamedAndRemoveUntil('/select_hotel', (_) => false);
              },
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Cambiar de hotel'),
            ),
          ],

          Center(
            child: SizedBox(
              width: 220,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await AuthService.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => LoginPage()),
                          (_) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
