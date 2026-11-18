import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../aviso_plan.dart';
import '../providers/aviso_plan_visible_provider.dart';

/// Aviso suave de plan al inicio de Inicio (D-16.2): uno solo a la vez, por
/// prioridad. No ocupa espacio mientras carga, ante error o sin aviso. "Ver mi
/// plan" (y el cuerpo del aviso) abre Mi plan; las variantes descartables se
/// pueden cerrar durante la sesión.
class PlanBanner extends ConsumerWidget {
  const PlanBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Una sola regla de visibilidad, compartida con Inicio.
    final aviso = ref.watch(avisoPlanVisibleProvider);
    if (aviso == null) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: '${aviso.titulo}. ${aviso.mensaje}. Ver mi plan',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => context.push('/mas/plan'),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(aviso.icono, color: AppColors.primaryText),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                aviso.titulo,
                                style: textTheme.labelLarge?.copyWith(
                                  color: AppColors.primaryText,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                aviso.mensaje,
                                style: textTheme.bodyLarge?.copyWith(
                                  color: AppColors.foreground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ExcludeSemantics(
              child: AppButton(
                label: 'Ver mi plan',
                variant: AppButtonVariant.text,
                expand: false,
                onPressed: () => context.push('/mas/plan'),
              ),
            ),
            if (aviso.descartable)
              IconButton(
                tooltip: 'Descartar aviso',
                constraints: const BoxConstraints(
                  minWidth: AppSpacing.touchTarget,
                  minHeight: AppSpacing.touchTarget,
                ),
                icon: const Icon(Icons.close),
                onPressed: () => ref
                    .read(avisosDescartadosProvider.notifier)
                    .descartar(aviso.tipo),
              ),
          ],
        ),
      ),
    );
  }
}
