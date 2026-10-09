import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../plan_textos.dart';

/// Pastilla de estado del plan: icono + texto, nunca solo color. Usa un
/// [Container] (no [Chip]) por la misma razón que `AppStatusChip`. El acento
/// terracota está reservado a los CTA, así que ningún estilo lo usa.
class PlanInsignia extends StatelessWidget {
  const PlanInsignia({
    super.key,
    required this.texto,
    required this.estilo,
    this.compacta = false,
    this.icono,
  });

  final String texto;
  final EstiloPlan estilo;

  /// En una fila apretada (Más) el texto puede envolver a una segunda línea;
  /// si no, se mantiene en una sola.
  final bool compacta;

  /// Reemplaza el icono del [estilo] (etiquetas Prueba / Beta / Fundador).
  final IconData? icono;

  ({Color fondo, Color color, IconData icono}) get _spec => switch (estilo) {
    EstiloPlan.activo => (
      fondo: AppColors.successBg,
      color: AppColors.success,
      icono: Icons.check_circle_outline,
    ),
    EstiloPlan.gratis => (
      fondo: AppColors.surfaceMuted,
      color: AppColors.textSecondary,
      icono: Icons.workspace_premium_outlined,
    ),
    EstiloPlan.prueba => (
      fondo: AppColors.surfaceMuted,
      color: AppColors.primaryText,
      icono: Icons.timer_outlined,
    ),
    EstiloPlan.beta => (
      fondo: AppColors.surfaceMuted,
      color: AppColors.primaryText,
      icono: Icons.science_outlined,
    ),
    EstiloPlan.alerta => (
      fondo: AppColors.warningBg,
      color: AppColors.primaryText,
      icono: Icons.schedule,
    ),
    EstiloPlan.soloLectura => (
      fondo: AppColors.warningBg,
      color: AppColors.primaryText,
      icono: Icons.lock_outline,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    final etiqueta = Text(
      texto,
      maxLines: compacta ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: spec.color,
        fontWeight: FontWeight.w600,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: spec.fondo,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono ?? spec.icono, size: 16, color: spec.color),
          const SizedBox(width: AppSpacing.xs),
          Flexible(child: etiqueta),
        ],
      ),
    );
  }
}
