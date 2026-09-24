import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../providers/auth_providers.dart';

/// Minimal landing for self-registered CLIENTE accounts (D-05) until the
/// owner-facing app arrives (SCALE-01).
class ClientHomeScreen extends ConsumerWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppTopBar(
      title: 'Mis mascotas',
      actions: [
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout),
          onPressed: () => ref.read(authProfileProvider.notifier).signOut(),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Aún no tienes mascotas registradas.',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('Agrégalas para consultar su historial y agendar citas.'),
        const SizedBox(height: 24),
        AppButton(label: 'Agregar mascota', icon: Icons.add, onPressed: () {}),
        const SizedBox(height: 12),
        AppButton(
          label: 'Agendar cita',
          icon: Icons.calendar_month,
          variant: AppButtonVariant.outline,
          onPressed: () {},
        ),
      ],
    ),
  );
}
