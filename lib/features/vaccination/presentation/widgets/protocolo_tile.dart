import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../domain/duraciones.dart';
import '../../domain/entities/protocolo.dart';

/// Resumen legible de la regla, p. ej. "3 dosis cada 21 días · refuerzo anual".
String resumenProtocolo(Protocolo p) {
  final serie = p.dosisSerie > 1 && p.intervaloSerieDias != null
      ? '${p.dosisSerie} dosis cada ${etiquetaDuracion(p.intervaloSerieDias!)}'
      : p.dosisSerie > 1
      ? '${p.dosisSerie} dosis'
      : '1 dosis';
  final refuerzo = switch (p.intervaloRefuerzoDias) {
    null => 'sin refuerzo',
    365 => 'refuerzo anual',
    final d => 'refuerzo cada ${etiquetaDuracion(d)}',
  };
  return '$serie · $refuerzo';
}

IconData iconoTipoDosis(TipoDosis t) => switch (t) {
  TipoDosis.vacuna => Icons.vaccines_outlined,
  TipoDosis.desparasitacionInterna => Icons.medication_outlined,
  TipoDosis.desparasitacionExterna => Icons.bug_report_outlined,
};

/// Fila del catálogo; el chevron solo aparece cuando [onTap] permite editar.
class ProtocoloTile extends StatelessWidget {
  const ProtocoloTile({super.key, required this.protocolo, this.onTap});

  final Protocolo protocolo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final personalizado = protocolo.personalizado || !protocolo.esSemilla;
    return AppCard(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Icon(iconoTipoDosis(protocolo.tipo)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(protocolo.nombre, style: textTheme.bodyLarge),
                  Text(
                    resumenProtocolo(protocolo),
                    style: textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (personalizado) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                child: Text(
                  'Personalizado',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ],
            if (onTap != null) const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
