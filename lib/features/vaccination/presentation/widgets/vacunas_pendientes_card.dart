import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/status/dosis_estado_chip.dart';
import '../providers/alertas_providers.dart';

/// Tarjeta de Inicio con los conteos de vacunas de toda la clínica (D-10,
/// D-14). Siempre visible; abre la pantalla de pendientes.
class VacunasPendientesCard extends ConsumerWidget {
  const VacunasPendientesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(resumenVacunasProvider);

    final Widget contenido = async.when(
      loading: () => Container(
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      error: (_, _) => Row(
        children: [
          Expanded(
            child: Text(
              'No pudimos cargar las vacunas.',
              style: textTheme.labelMedium,
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(resumenVacunasProvider),
            child: const Text('Reintentar'),
          ),
        ],
      ),
      data: (r) {
        if (r.vencidas == 0 && r.proximas == 0) {
          return Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Todo al día', style: textTheme.bodyLarge),
            ],
          );
        }
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (r.vencidas > 0) ...[
              const DosisEstadoChip(estado: DosisEstado.vencida, compact: true),
              Text('${r.vencidas} vencidas', style: textTheme.bodyMedium),
            ],
            if (r.proximas > 0) ...[
              const DosisEstadoChip(estado: DosisEstado.proxima, compact: true),
              Text('${r.proximas} próximas', style: textTheme.bodyMedium),
            ],
          ],
        );
      },
    );

    return Semantics(
      button: true,
      child: AppCard(
        onTap: () => context.push('/vacunas'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              const Icon(Icons.vaccines_outlined),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vacunas pendientes', style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    contenido,
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
