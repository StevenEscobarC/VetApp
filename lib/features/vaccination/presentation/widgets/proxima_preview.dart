import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../domain/entities/carne.dart';
import '../../domain/estado_dosis_ui.dart';

/// Vista previa de solo lectura de la próxima dosis (D-02): la fecha y las
/// etiquetas las calcula el servidor; aquí nunca se editan ni se calculan.
/// La sugerencia de reiniciar la serie nunca bloquea el guardado.
class ProximaPreview extends StatelessWidget {
  const ProximaPreview({
    super.key,
    required this.preview,
    required this.hoy,
    required this.iniciaSerie,
    required this.onReiniciar,
  });

  final AsyncValue<PrevisualizacionDosis?> preview;

  /// Día actual en Bogotá, para el "en N días" de la línea de contexto.
  final DateTime hoy;
  final bool iniciaSerie;
  final ValueChanged<bool> onReiniciar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: preview.when(
          loading: () => const Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, _) => Text(
            'No pudimos calcular la próxima fecha.',
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          data: (p) {
            if (p == null) {
              return Text(
                'Se calcula sola con el protocolo.',
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              );
            }
            // UI-SPEC: "Dosis 2 de 3 · en 21 días" describe la próxima dosis,
            // no la que se registra. Sin refuerzo no hay línea de contexto.
            final proxima = p.proximaFecha;
            final contexto = proxima == null
                ? ''
                : [
                    p.etiquetaProxima,
                    textoEnDias(proxima, hoy),
                  ].where((s) => s.trim().isNotEmpty).join(' · ');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_outlined, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        p.proximaFecha == null
                            ? 'Sin refuerzo'
                            : 'Próxima: ${formatearFecha(p.proximaFecha!)}',
                        style: textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                if (contexto.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    contexto,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Se calcula sola con el protocolo.',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                if (p.sugerirReiniciar || iniciaSerie) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pasó mucho tiempo desde la dosis anterior. '
                          'Puede reiniciar la serie.',
                          style: textTheme.bodyLarge,
                        ),
                        AppButton(
                          label: iniciaSerie
                              ? 'Continuar serie'
                              : 'Reiniciar serie',
                          variant: AppButtonVariant.text,
                          expand: false,
                          onPressed: () => onReiniciar(!iniciaSerie),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
