import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../appointments/presentation/providers/recordatorios_providers.dart';
import '../../../appointments/presentation/screens/recordatorios_screen.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Sign-out lives here (no confirmation dialog — out of scope per
/// 01-UI-SPEC.md) so the human checkpoint in Plan 06 can switch accounts.
class MasScreen extends ConsumerWidget {
  const MasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anticipacion =
        ref.watch(anticipacionRecordatorioProvider).value ?? 60;
    return Scaffold(
      appBar: const AppTopBar(title: 'Más'),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              onTap: () => context.push('/mas/recordatorios'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_outlined),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Recordatorios',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    Text(
                      etiquetaAnticipacion(anticipacion),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
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
