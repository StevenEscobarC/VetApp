import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Sign-out lives here (no confirmation dialog — out of scope per
/// 01-UI-SPEC.md) so the human checkpoint in Plan 06 can switch accounts.
class MasScreen extends ConsumerWidget {
  const MasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Más'),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Próximamente',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Cerrar sesión',
              icon: Icons.logout,
              variant: AppButtonVariant.outline,
              onPressed: () => ref.read(authProfileProvider.notifier).signOut(),
            ),
          ],
        ),
      ),
    );
  }
}
