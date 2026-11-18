import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'Aún no tienes mascotas registradas.',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Tu veterinario registra tus mascotas; aquí podrás consultar su '
          'historial.',
        ),
      ],
    ),
  );
}
