import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato_hora.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../domain/entities/cita.dart';

/// Banner "Próxima: Luna 10:30 a. m. · en 55 min" para la siguiente cita
/// no terminal de hoy. [ahora] llega del reloj inyectado, nunca del reloj
/// del sistema.
class ProximaBanner extends StatelessWidget {
  const ProximaBanner({
    super.key,
    required this.cita,
    required this.ahora,
    this.onTap,
  });

  final Cita cita;
  final DateTime ahora;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final faltan = cita.fechaHora.difference(ahora);
    final texto = 'Próxima: ${cita.nombresMascotasCorto} '
        '${hora12(aBogota(cita.fechaHora))} · ${enCuanto(faltan)}';

    return Material(
      color: AppColors.warningBg,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.schedule_outlined, color: AppColors.primaryStrong),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  texto,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
