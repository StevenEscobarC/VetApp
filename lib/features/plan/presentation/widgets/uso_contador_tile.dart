import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cards/app_card.dart';

/// Contador de uso del plan (pacientes, veterinarios): icono, texto y, si hay
/// límite, una barra de 8px. La barra nunca va sin el texto numérico al lado
/// y nunca usa rojo ni el acento: `success` bajo 80 %, `warning` desde 80 %.
class UsoContadorTile extends StatelessWidget {
  const UsoContadorTile({
    super.key,
    required this.icono,
    required this.texto,
    this.progreso,
    this.ayuda,
    this.ayudaColor = AppColors.textSecondary,
  });

  final IconData icono;
  final String texto;

  /// 0..1; `null` oculta la barra.
  final double? progreso;
  final String? ayuda;
  final Color ayudaColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = progreso?.clamp(0.0, 1.0);
    final porcentaje = p == null ? null : (p * 100).round();
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: [
        if (porcentaje == null) texto else '$texto, $porcentaje por ciento',
        ?ayuda,
      ].join('. '),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(texto, style: textTheme.bodyLarge),
                  if (p != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        key: const ValueKey('uso-barra'),
                        value: p,
                        minHeight: 8,
                        backgroundColor: AppColors.border,
                        color: p >= 0.8 ? AppColors.warning : AppColors.success,
                      ),
                    ),
                  ],
                  if (ayuda != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      ayuda!,
                      style: textTheme.labelLarge?.copyWith(color: ayudaColor),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
