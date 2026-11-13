import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Tira de alerta de la lista de inventario (INV-02): avisa cuántos productos
/// están bajo su mínimo y lleva al filtro "Bajos". No se descarta: es el mismo
/// dato que el chip y desaparece sola cuando [bajos] llega a 0 (quien la
/// monta decide cuándo mostrarla).
class ResumenBajosStrip extends StatelessWidget {
  const ResumenBajosStrip({
    super.key,
    required this.bajos,
    required this.onVerBajos,
  });

  final int bajos;
  final VoidCallback onVerBajos;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final texto = bajos == 1
        ? '1 producto con stock bajo'
        : '$bajos productos con stock bajo';
    return Container(
      constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.trending_down,
            size: 24,
            color: AppColors.primaryText,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              texto,
              style: textTheme.labelLarge?.copyWith(
                color: AppColors.primaryText,
              ),
            ),
          ),
          TextButton(
            onPressed: onVerBajos,
            style: TextButton.styleFrom(
              minimumSize: const Size(
                AppSpacing.touchTarget,
                AppSpacing.touchTarget,
              ),
            ),
            child: const Text('Ver bajos'),
          ),
        ],
      ),
    );
  }
}
