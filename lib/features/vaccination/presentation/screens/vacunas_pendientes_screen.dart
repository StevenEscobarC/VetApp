import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/chips/app_filter_chip.dart';
import '../../domain/entities/carne.dart';
import '../providers/alertas_providers.dart';
import '../widgets/pendiente_tile.dart';

enum _Filtro {
  todas('Todas', null),
  perros('Perros', 'perro'),
  gatos('Gatos', 'gato');

  const _Filtro(this.label, this.especie);
  final String label;
  final String? especie;
}

/// "Vacunas pendientes" (VAC-03): alertas de toda la clínica, sin filtro por
/// veterinario (D-14), con vencidas primero (D-10..D-13).
class VacunasPendientesScreen extends ConsumerStatefulWidget {
  const VacunasPendientesScreen({super.key});

  @override
  ConsumerState<VacunasPendientesScreen> createState() =>
      _VacunasPendientesScreenState();
}

class _VacunasPendientesScreenState
    extends ConsumerState<VacunasPendientesScreen> {
  _Filtro _filtro = _Filtro.todas;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(vacunasPendientesProvider);
    final ocultas =
        ref.watch(resumenVacunasProvider).asData?.value.ocultasAntiguas ?? 0;

    return Scaffold(
      appBar: const AppTopBar(title: 'Vacunas pendientes'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                for (final f in _Filtro.values) ...[
                  AppFilterChip(
                    label: f.label,
                    selected: _filtro == f,
                    onTap: () => setState(() => _filtro = f),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    const _SkeletonTile(),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
              error: (_, _) => ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No pudimos cargar las alertas. Intenta de nuevo.',
                          style: textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppButton(
                          label: 'Reintentar',
                          variant: AppButtonVariant.outline,
                          expand: false,
                          onPressed: () =>
                              ref.invalidate(vacunasPendientesProvider),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              data: (todas) {
                final lista = todas
                    .where(
                      (p) =>
                          _filtro.especie == null ||
                          p.mascotaEspecie == _filtro.especie,
                    )
                    .toList();
                final vencidas =
                    lista.where((p) => p.estado == EstadoCarne.vencida).toList()
                      ..sort((a, b) => b.diasVencida.compareTo(a.diasVencida));
                final proximas =
                    lista.where((p) => p.estado != EstadoCarne.vencida).toList()
                      ..sort(
                        (a, b) => a.proximaFecha.compareTo(b.proximaFecha),
                      );
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  children: [
                    if (lista.isEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text('Todo al día', style: textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'No hay vacunas vencidas ni próximas en la clínica.',
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (vencidas.isNotEmpty)
                      ..._grupo(
                        'Vencidas (${vencidas.length})',
                        vencidas,
                        textTheme,
                      ),
                    if (proximas.isNotEmpty)
                      ..._grupo(
                        'Próximas (${proximas.length})',
                        proximas,
                        textTheme,
                      ),
                    if (ocultas > 0) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Se ocultan las vacunas vencidas hace más de 6 meses. '
                        'Siguen marcadas en cada carné.',
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _grupo(
    String titulo,
    List<PendienteVacuna> items,
    TextTheme textTheme,
  ) => [
    const SizedBox(height: AppSpacing.sm),
    Text(titulo, style: textTheme.titleMedium),
    const SizedBox(height: AppSpacing.sm),
    for (final p in items) ...[
      PendienteTile(
        key: ValueKey('${p.ultimaDosisId}-${p.codigoProtocolo}'),
        pendiente: p,
      ),
      const SizedBox(height: AppSpacing.sm),
    ],
  ];
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    Widget bloque(double h, [double? w]) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bloque(20, 160),
          const SizedBox(height: AppSpacing.sm),
          bloque(16),
          const SizedBox(height: AppSpacing.sm),
          bloque(48),
        ],
      ),
    );
  }
}
