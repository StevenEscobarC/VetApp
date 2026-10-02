import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/status/dosis_estado_chip.dart';
import '../../domain/entities/protocolo.dart';

/// Encabezado de un grupo del carné: icono por tipo, nombre del biológico y
/// el estado vigente del grupo.
class BiologicoGroupHeader extends StatelessWidget {
  const BiologicoGroupHeader({
    super.key,
    required this.nombre,
    required this.tipo,
    required this.estado,
  });

  final String nombre;
  final TipoDosis tipo;
  final DosisEstado estado;

  static IconData iconoDe(TipoDosis t) => switch (t) {
    TipoDosis.vacuna => Icons.vaccines_outlined,
    TipoDosis.desparasitacionInterna => Icons.medication_outlined,
    TipoDosis.desparasitacionExterna => Icons.bug_report_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Icon(iconoDe(tipo), color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              nombre,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          DosisEstadoChip(estado: estado),
        ],
      ),
    );
  }
}
