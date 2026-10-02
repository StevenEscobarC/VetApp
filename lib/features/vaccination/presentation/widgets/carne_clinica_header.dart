import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../clinic/presentation/widgets/clinica_logo.dart';
import '../../domain/entities/carne.dart';

/// Membrete del carné en pantalla (D-26): logo de la clínica junto a su
/// nombre y ciudad. Sin logo (o si falla al cargar) solo se ve el nombre,
/// sin placeholder; colores y tipografía siguen siendo los de VetApp.
class CarneClinicaHeader extends StatelessWidget {
  const CarneClinicaHeader({super.key, required this.carne});

  final Carne carne;

  @override
  Widget build(BuildContext context) {
    final partes = [
      carne.clinicaNombre.trim(),
      carne.clinicaCiudad.trim(),
    ].where((p) => p.isNotEmpty).toList();
    final logoPath = carne.clinicaLogoPath;
    final hayLogo = logoPath != null && logoPath.isNotEmpty;
    if (partes.isEmpty && !hayLogo) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        container: true,
        label: 'Clínica ${carne.clinicaNombre}',
        child: Row(
          children: [
            if (hayLogo) ...[
              ClinicaLogo(logoPath: logoPath, size: 40),
              const SizedBox(width: AppSpacing.sm),
            ],
            if (partes.isNotEmpty)
              Expanded(
                child: Text(
                  partes.join(' · '),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
