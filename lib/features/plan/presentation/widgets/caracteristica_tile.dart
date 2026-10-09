import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cards/app_card.dart';

/// Fila de una característica del plan (logo, protocolos propios): título a
/// la izquierda y su estado a la derecha con icono + texto (incluido en
/// `success`, no incluido en `textMuted`), más una ayuda opcional debajo.
class CaracteristicaTile extends StatelessWidget {
  const CaracteristicaTile({
    super.key,
    required this.icono,
    required this.titulo,
    required this.estado,
    required this.incluido,
    this.ayuda,
  });

  final IconData icono;
  final String titulo;
  final String estado;
  final bool incluido;
  final String? ayuda;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = incluido ? AppColors.success : AppColors.textMuted;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: [titulo, estado, ?ayuda].join('. '),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(titulo, style: textTheme.bodyLarge)),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  incluido ? Icons.check_circle_outline : Icons.lock_outline,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    estado,
                    textAlign: TextAlign.end,
                    style: textTheme.labelLarge?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            if (ayuda != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                ayuda!,
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
