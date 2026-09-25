import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Reusable pill-shaped single-select chip. Introduced for the especie
/// selector in [MascotaCamposSection] (Plan 04); reused as-is for the
/// species filter row on `PacientesListScreen` (Plan 06) and any future
/// single-select filter (Agenda, Inventario) — keep this widget generic,
/// never fork a feature-local copy.
///
/// Built on [Container]+[InkWell], not Material's `FilterChip`/`ChoiceChip`
/// — same reasoning as [AppStatusChip]: `Chip`'s internal size animation can
/// lock in a stale (too-narrow) width when Google Fonts swaps in the real
/// font after first layout, clipping the label.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? AppColors.onPrimary : null,
          ),
        ),
      ),
    );
  }
}
