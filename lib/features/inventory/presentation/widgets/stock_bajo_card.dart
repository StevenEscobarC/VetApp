import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../inventario_routes.dart';
import '../providers/inventario_providers.dart';

/// Aviso de Inicio cuando hay productos bajo su mínimo (INV-02, D-08). Es un
/// aviso opcional: no pinta nada con 0 bajos, cargando ni con error, para que
/// un fallo de inventario nunca ensucie Inicio (el reintento vive en la
/// lista). Incluye su propio espacio superior para no dejar doble hueco
/// cuando está oculto. Nunca se bloquea por solo lectura.
class StockBajoCard extends ConsumerWidget {
  const StockBajoCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bajos = ref.watch(resumenInventarioProvider).value?.bajos ?? 0;
    if (bajos <= 0) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final titulo = bajos == 1
        ? '1 producto con stock bajo'
        : '$bajos productos con stock bajo';
    final borde = BorderRadius.circular(AppSpacing.radiusMd);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Semantics(
        button: true,
        label: '$titulo. Ver inventario.',
        excludeSemantics: true,
        child: Material(
          color: AppColors.warningBg,
          shape: RoundedRectangleBorder(
            borderRadius: borde,
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(rutaInventario(bajos: true)),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 24,
                    color: AppColors.primaryText,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: textTheme.labelLarge?.copyWith(
                            color: AppColors.primaryText,
                          ),
                        ),
                        Text(
                          'Revisa qué hay que reabastecer.',
                          style: textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
