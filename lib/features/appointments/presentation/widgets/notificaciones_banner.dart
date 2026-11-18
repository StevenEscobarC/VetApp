import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../providers/recordatorios_providers.dart';
import 'permiso_notificaciones.dart';

/// Aviso persistente de notificaciones desactivadas: informativo (no es un
/// error), sin botón de cerrar; desaparece cuando se concede el permiso.
class NotificacionesBanner extends ConsumerWidget {
  const NotificacionesBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mostrar = ref.watch(mostrarBannerNotificacionesProvider).value;
    if (mostrar != true) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: AppColors.warningBg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_off_outlined,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recordatorios desactivados',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
                Text(
                  'Activa las notificaciones para que te avisemos antes de '
                  'cada cita.',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          AppButton(
            label: 'Activar',
            variant: AppButtonVariant.text,
            expand: false,
            onPressed: () => activarNotificaciones(ref),
          ),
        ],
      ),
    );
  }
}
