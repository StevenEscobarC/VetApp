import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

enum AppStatus { confirmed, pending, cancelled, completed, noShow }

/// Status indicator for appointments/records. Per accessibility rule
/// `color-not-only`, status is conveyed by icon + label, never color alone.
///
/// Built on a plain [Container] instead of [Chip]: Chip's internal
/// size animation can lock in a stale (too-narrow) width when Google
/// Fonts swaps in the real font after first layout, clipping the label.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({super.key, required this.status});

  final AppStatus status;

  ({Color color, IconData icon, String label}) get _spec => switch (status) {
        AppStatus.confirmed => (
            color: AppColors.success,
            icon: Icons.check_circle_outline,
            label: 'Confirmada',
          ),
        AppStatus.pending => (
            color: AppColors.warning,
            icon: Icons.schedule_outlined,
            label: 'Pendiente',
          ),
        AppStatus.cancelled => (
            color: AppColors.destructive,
            icon: Icons.cancel_outlined,
            label: 'Cancelada',
          ),
        AppStatus.completed => (
            color: AppColors.primary,
            icon: Icons.task_alt_outlined,
            label: 'Completada',
          ),
        AppStatus.noShow => (
            color: AppColors.textMuted,
            icon: Icons.person_off_outlined,
            label: 'No asistió',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: spec.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: spec.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon, size: 16, color: spec.color),
          const SizedBox(width: 6),
          Text(
            spec.label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: spec.color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
