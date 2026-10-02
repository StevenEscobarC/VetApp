import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/miembro.dart';

/// Insignia de rol de un [Miembro]: icono + texto, nunca solo color. Usa un
/// [Container] (no [Chip]) por la misma razón que `AppStatusChip`.
class RolBadge extends StatelessWidget {
  const RolBadge({super.key, required this.miembro});

  final Miembro miembro;

  ({Color color, IconData? icon, String label}) get _spec {
    if (!miembro.activo) {
      return (
        color: AppColors.textMuted,
        icon: Icons.person_off_outlined,
        label: 'Retirado',
      );
    }
    if (miembro.esAdmin) {
      return (
        color: AppColors.primaryText,
        icon: Icons.admin_panel_settings_outlined,
        label: 'Administrador',
      );
    }
    return (color: AppColors.textSecondary, icon: null, label: 'Veterinario');
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spec.icon != null) ...[
            Icon(spec.icon, size: 16, color: spec.color),
            const SizedBox(width: 6),
          ],
          Text(
            spec.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: spec.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
