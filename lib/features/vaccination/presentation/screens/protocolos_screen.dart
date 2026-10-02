import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/chips/app_filter_chip.dart';
import '../providers/protocolos_providers.dart';
import '../providers/vacuna_providers.dart';
import '../widgets/protocolo_edit_sheet.dart';
import '../widgets/protocolo_tile.dart';

/// Más > Protocolos de vacunación (D-01, D-24): el catálogo efectivo de la
/// clínica por especie. Solo administradores editan; el servidor es la
/// autoridad.
class ProtocolosScreen extends ConsumerStatefulWidget {
  const ProtocolosScreen({super.key});

  @override
  ConsumerState<ProtocolosScreen> createState() => _ProtocolosScreenState();
}

class _ProtocolosScreenState extends ConsumerState<ProtocolosScreen> {
  String _especie = 'perro';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final puedeEditar = ref.watch(puedeEditarProtocolosProvider);
    final catalogo = ref.watch(protocolosProvider(_especie));

    Widget lista;
    if (catalogo.hasError && !catalogo.hasValue) {
      lista = AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No pudimos cargar los protocolos. Intenta de nuevo.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Reintentar',
              variant: AppButtonVariant.outline,
              onPressed: () => ref.invalidate(protocolosProvider),
            ),
          ],
        ),
      );
    } else if (!catalogo.hasValue) {
      lista = Column(
        children: [
          for (var i = 0; i < 4; i++) ...[
            const _SkeletonTile(),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      );
    } else {
      final items = catalogo.value!.where((p) => p.activo).toList();
      lista = Column(
        children: [
          for (final p in items) ...[
            ProtocoloTile(
              protocolo: p,
              onTap: puedeEditar
                  ? () => showProtocoloEditSheet(context, protocolo: p)
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: const AppTopBar(title: 'Protocolos'),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Los cambios aplican a las próximas dosis que '
                          'registres. Las fechas próximas se recalculan con '
                          'el nuevo protocolo.',
                          style: textTheme.labelLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    AppFilterChip(
                      label: 'Perros',
                      selected: _especie == 'perro',
                      onTap: () => setState(() => _especie = 'perro'),
                    ),
                    AppFilterChip(
                      label: 'Gatos',
                      selected: _especie == 'gato',
                      onTap: () => setState(() => _especie = 'gato'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                lista,
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: puedeEditar
                  ? AppButton(
                      label: 'Nuevo biológico',
                      icon: Icons.add,
                      onPressed: () => showProtocoloEditSheet(context),
                    )
                  : Text(
                      'Solo los administradores pueden cambiar los '
                      'protocolos.',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
  );
}
