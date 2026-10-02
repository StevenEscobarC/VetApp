import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

enum DosisEstado { alDia, proxima, vencida, anulada, externa }

/// Estado de una dosis/biológico. Siempre icono + texto, nunca solo color.
class DosisEstadoChip extends StatelessWidget {
  const DosisEstadoChip({super.key, required this.estado, this.compact = false});

  final DosisEstado estado;
  final bool compact;

  ({Color bg, Color fg, Color? borde, IconData icon, String label}) get _spec =>
      switch (estado) {
        DosisEstado.alDia => (
          bg: AppColors.successBg,
          fg: AppColors.success,
          borde: null,
          icon: Icons.check_circle_outline,
          label: 'Al día',
        ),
        DosisEstado.proxima => (
          bg: AppColors.warningBg,
          fg: AppColors.primaryText,
          borde: AppColors.warning,
          icon: Icons.schedule,
          label: 'Próxima',
        ),
        DosisEstado.vencida => (
          bg: AppColors.destructive,
          fg: AppColors.onDestructive,
          borde: null,
          icon: Icons.error_outline,
          label: 'Vencida',
        ),
        DosisEstado.anulada => (
          bg: AppColors.surfaceMuted,
          fg: AppColors.textMuted,
          borde: null,
          icon: Icons.block,
          label: 'Anulada',
        ),
        DosisEstado.externa => (
          bg: AppColors.surfaceMuted,
          fg: AppColors.textSecondary,
          borde: null,
          icon: Icons.apartment_outlined,
          label: 'Otra clínica',
        ),
      };

  @override
  Widget build(BuildContext context) {
    final s = _spec;
    // El icono del chip "Próxima" usa el color de advertencia.
    final iconColor = estado == DosisEstado.proxima ? AppColors.warning : s.fg;
    return Semantics(
      label: s.label,
      excludeSemantics: true,
      child: Container(
        height: compact ? 28 : 32,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: s.bg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: s.borde == null
              ? null
              : Border.all(color: s.borde!.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon, size: compact ? 14 : 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              s.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: s.fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
