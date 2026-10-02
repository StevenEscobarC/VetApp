import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/status/dosis_estado_chip.dart';
import '../../domain/entities/carne.dart';
import '../../domain/estado_dosis_ui.dart';
import '../providers/vacuna_providers.dart';

/// Sección "Carné de vacunación" de la ficha: estado más urgente, cuántos
/// biológicos están pendientes y acceso al carné completo. [rutaBase] es la
/// ubicación de la ficha (el carné vive en `'$rutaBase/carne'`).
class CarneResumenSection extends ConsumerWidget {
  const CarneResumenSection({
    super.key,
    required this.mascotaId,
    required this.rutaBase,
  });

  final String mascotaId;
  final String rutaBase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final carneAsync = ref.watch(carneProvider(mascotaId));
    final activas = carneAsync.maybeWhen(
      data: (c) => c.dosis.where((d) => !d.anulada).length,
      orElse: () => 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Carné de vacunación', style: textTheme.titleMedium),
            ),
            if (carneAsync.hasValue)
              Text(
                '$activas dosis',
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        carneAsync.when(
          data: (carne) => _Resumen(
            carne: carne,
            activas: activas,
            onTap: () => context.push('$rutaBase/carne'),
          ),
          loading: () => const AppCard(
            child: SizedBox(height: 32, width: double.infinity),
          ),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('No pudimos cargar el carné. Intenta de nuevo.'),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Reintentar',
                variant: AppButtonVariant.text,
                expand: false,
                onPressed: () => ref.invalidate(carneProvider(mascotaId)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({
    required this.carne,
    required this.activas,
    required this.onTap,
  });

  final Carne carne;
  final int activas;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final peor = carne.peorEstado;
    return AppCard(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
        child: Row(
          children: [
            Expanded(
              child: activas == 0 || peor == null
                  ? Text(
                      'Sin vacunas registradas',
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    )
                  : Wrap(
                      spacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DosisEstadoChip(estado: dosisEstadoDe(peor)),
                        if (carne.pendientes > 0)
                          Text(
                            '${carne.pendientes} pendientes',
                            style: textTheme.labelMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Insignia bajo el nombre de la mascota: chip Vencida/Próxima, "Vacunas al
/// día" cuando hay dosis y nada pendiente, o nada si no hay dosis. Tocarla
/// abre el carné.
class CarneBadge extends ConsumerWidget {
  const CarneBadge({super.key, required this.mascotaId, required this.rutaBase});

  final String mascotaId;
  final String rutaBase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carne = ref.watch(carneProvider(mascotaId)).asData?.value;
    if (carne == null) return const SizedBox.shrink();
    final activas = carne.dosis.where((d) => !d.anulada).length;
    final peor = carne.peorEstado;
    if (activas == 0 || peor == null) return const SizedBox.shrink();

    final Widget contenido;
    if (peor == EstadoCarne.alDia) {
      contenido = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: AppColors.success,
          ),
          const SizedBox(width: 6),
          Text(
            'Vacunas al día',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    } else {
      contenido = DosisEstadoChip(estado: dosisEstadoDe(peor), compact: true);
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Center(
        child: InkWell(
          onTap: () => context.push('$rutaBase/carne'),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.touchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Center(widthFactor: 1, child: contenido),
            ),
          ),
        ),
      ),
    );
  }
}
