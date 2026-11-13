import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/producto.dart';

enum EstadoStock { agotado, bajo, vencido, vencePronto }

/// Estados de stock de [p]: como máximo uno de existencias (agotado gana a
/// bajo) seguido de como máximo uno de vencimiento (vencido gana a vence
/// pronto). Vacío si el producto está normal.
List<EstadoStock> estadosDe(Producto p, DateTime hoy) => [
  if (p.agotado) EstadoStock.agotado else if (p.bajo) EstadoStock.bajo,
  if (p.vencido(hoy))
    EstadoStock.vencido
  else if (p.vencePronto(hoy))
    EstadoStock.vencePronto,
];

List<Widget> insigniasDe(Producto p, DateTime hoy) => [
  for (final e in estadosDe(p, hoy)) InsigniaStock(estado: e),
];

/// Insignia de estado de stock. Siempre icono + texto, nunca solo color.
/// Mismo molde que `DosisEstadoChip`, local a inventario para no tocar los
/// widgets compartidos.
class InsigniaStock extends StatelessWidget {
  const InsigniaStock({super.key, required this.estado});

  final EstadoStock estado;

  ({Color bg, Color fg, Color? borde, IconData icon, String label}) get _spec =>
      switch (estado) {
        EstadoStock.agotado => (
          bg: AppColors.destructive,
          fg: AppColors.onDestructive,
          borde: null,
          icon: Icons.error_outline,
          label: 'Agotado',
        ),
        EstadoStock.bajo => (
          bg: AppColors.warningBg,
          fg: AppColors.primaryText,
          borde: AppColors.warning,
          icon: Icons.trending_down,
          label: 'Bajo',
        ),
        EstadoStock.vencido => (
          bg: AppColors.destructive,
          fg: AppColors.onDestructive,
          borde: null,
          icon: Icons.event_busy,
          label: 'Vencido',
        ),
        EstadoStock.vencePronto => (
          bg: AppColors.warningBg,
          fg: AppColors.primaryText,
          borde: AppColors.warning,
          icon: Icons.schedule,
          label: 'Vence pronto',
        ),
      };

  @override
  Widget build(BuildContext context) {
    final s = _spec;
    return Semantics(
      label: s.label,
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
