import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/cobro.dart';

/// Chip de estado de un cobro (UI-SPEC, mapa de estados). Siempre icono +
/// texto, nunca solo color. Una cotización abierta no lleva chip: la lista
/// y el detalle muestran su validez en su lugar, así que quien llama usa
/// [EstadoCobroChip.para], que devuelve `null` para [EstadoCobro.abierta].
class EstadoCobroChip extends StatelessWidget {
  const EstadoCobroChip(this.estado, {super.key});

  final EstadoCobro estado;

  /// Chip del [estado], o `null` si el estado no lleva chip (abierta).
  static EstadoCobroChip? para(EstadoCobro estado) =>
      estado == EstadoCobro.abierta ? null : EstadoCobroChip(estado);

  ({Color bg, Color fg, Color? borde, IconData icon})? get _spec =>
      switch (estado) {
        EstadoCobro.pagada => (
          bg: AppColors.successBg,
          fg: AppColors.success,
          borde: null,
          icon: Icons.check_circle_outline,
        ),
        EstadoCobro.pendiente => (
          bg: AppColors.warningBg,
          fg: AppColors.primaryText,
          borde: AppColors.warning,
          icon: Icons.schedule,
        ),
        EstadoCobro.anulada => (
          bg: AppColors.surfaceMuted,
          fg: AppColors.textMuted,
          borde: null,
          icon: Icons.block,
        ),
        EstadoCobro.convertida => (
          bg: AppColors.surfaceMuted,
          fg: AppColors.textSecondary,
          borde: null,
          icon: Icons.swap_horiz,
        ),
        EstadoCobro.abierta => null,
      };

  @override
  Widget build(BuildContext context) {
    final s = _spec;
    if (s == null) return const SizedBox.shrink();
    return Semantics(
      label: estado.etiqueta,
      excludeSemantics: true,
      child: Container(
        height: 28,
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
            Icon(s.icon, size: 16, color: s.fg),
            const SizedBox(width: AppSpacing.xs),
            Text(
              estado.etiqueta,
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
