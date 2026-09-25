import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/chips/app_filter_chip.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../domain/entities/mascota.dart';

/// Shared pet-fields section, reused by `NuevoClienteMascotaScreen` (Plan
/// 04, combined create) and standalone by `MascotaFormScreen` (Plan 09,
/// D-03 new pet for an existing owner + edit). Only nombre + especie are
/// always visible/required — raza, fecha de nacimiento and peso sit behind
/// the collapsed "Agregar más detalles" disclosure, per D-04. Passing
/// [pesoController] as `null` hides the peso field entirely (edit mode in
/// Plan 09, where weight is registered separately via the history timeline,
/// not edited on the ficha).
class MascotaCamposSection extends StatelessWidget {
  const MascotaCamposSection({
    super.key,
    required this.nombreController,
    required this.especie,
    required this.onEspecieChanged,
    required this.razaController,
    required this.fechaController,
    this.pesoController,
    this.fechaError,
    this.pesoError,
    required this.detallesExpandidos,
    required this.onToggleDetalles,
    this.foto,
  });

  final TextEditingController nombreController;
  final Especie? especie;
  final ValueChanged<Especie> onEspecieChanged;
  final TextEditingController razaController;
  final TextEditingController fechaController;
  final TextEditingController? pesoController;
  final String? fechaError;
  final String? pesoError;
  final bool detallesExpandidos;
  final VoidCallback onToggleDetalles;
  final Widget? foto;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (foto != null) ...[foto!, const SizedBox(height: AppSpacing.md)],
        AppTextField(label: 'Nombre *', controller: nombreController),
        const SizedBox(height: AppSpacing.md),
        Text('Especie *', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: Especie.values
              .map(
                (e) => AppFilterChip(
                  label: e.etiqueta,
                  selected: especie == e,
                  onTap: () => onEspecieChanged(e),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        InkWell(
          onTap: onToggleDetalles,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.touchTarget,
            ),
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Agregar más detalles',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                Icon(
                  detallesExpandidos
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (detallesExpandidos) ...[
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Raza', controller: razaController),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Fecha de nacimiento',
            controller: fechaController,
            hintText: 'dd/mm/aaaa',
            keyboardType: TextInputType.datetime,
            errorText: fechaError,
          ),
          if (pesoController != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Peso (kg)',
              controller: pesoController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              errorText: pesoError,
            ),
          ],
        ],
      ],
    );
  }
}
