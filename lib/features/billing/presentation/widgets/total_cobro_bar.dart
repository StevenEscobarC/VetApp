import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/buttons/app_button.dart';

/// Barra fija del formulario de cobro (UI-SPEC §3): total en vivo y el único
/// CTA de acento. Deshabilitada se dibuja sin opacidad y, al tocarla, avisa
/// con [onTapDeshabilitado] qué falta. El total es solo vista previa: el
/// servidor lo recalcula.
class TotalCobroBar extends StatelessWidget {
  const TotalCobroBar({
    super.key,
    required this.totalCop,
    required this.etiquetaCta,
    required this.onPressed,
    this.habilitado = true,
    this.onTapDeshabilitado,
    this.isLoading = false,
    this.ayuda,
    this.error,
  });

  final int totalCop;
  final String etiquetaCta;
  final VoidCallback onPressed;
  final bool habilitado;
  final VoidCallback? onTapDeshabilitado;
  final bool isLoading;

  /// Línea de ayuda bajo el total (p. ej. que se resta del inventario).
  final String? ayuda;

  /// Primera validación pendiente, en rojo sobre el CTA.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cta = habilitado
        ? AppButton(
            label: etiquetaCta,
            onPressed: onPressed,
            isLoading: isLoading,
          )
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTapDeshabilitado,
            child: Semantics(
              button: true,
              enabled: false,
              label: etiquetaCta,
              excludeSemantics: true,
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.touchTarget,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  etiquetaCta,
                  style: t.labelLarge?.copyWith(color: AppColors.textMuted),
                ),
              ),
            ),
          );
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Total',
                    style: t.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Semantics(
                      label: '${formatearMiles(totalCop)} pesos',
                      excludeSemantics: true,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatearCop(totalCop),
                            style: t.displaySmall?.copyWith(
                              color: AppColors.primaryText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (ayuda != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  ayuda!,
                  style: t.labelLarge?.copyWith(color: AppColors.textMuted),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Semantics(
                  liveRegion: true,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: AppColors.destructive,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          error!,
                          style: t.labelLarge?.copyWith(
                            color: AppColors.destructive,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              cta,
            ],
          ),
        ),
      ),
    );
  }
}
