import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato_hora.dart';
import '../../../../core/utils/zona_bogota.dart';

/// Tira LUN-DOM de la semana de [lunes]: un botón por día con el número de
/// citas no canceladas. Propia (sin paquete de calendario, D-08). Todos los
/// días son `DateTime.utc(y, m, d)` de fechas de Bogotá.
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.lunes,
    required this.seleccionado,
    required this.hoy,
    required this.onSeleccionar,
    this.conteos,
  });

  final DateTime lunes;
  final DateTime seleccionado;
  final DateTime hoy;

  /// Conteo por día; `null` mientras carga (sin insignias).
  final Map<DateTime, int>? conteos;
  final ValueChanged<DateTime> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: _DayCell(
                dia: DateTime.utc(lunes.year, lunes.month, lunes.day + i),
                seleccionado: seleccionado,
                hoy: hoy,
                conteo:
                    conteos?[DateTime.utc(
                      lunes.year,
                      lunes.month,
                      lunes.day + i,
                    )],
                onTap: onSeleccionar,
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dia,
    required this.seleccionado,
    required this.hoy,
    required this.conteo,
    required this.onTap,
  });

  final DateTime dia;
  final DateTime seleccionado;
  final DateTime hoy;
  final int? conteo;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final esSel = mismoDia(dia, seleccionado);
    final esHoy = mismoDia(dia, hoy);
    final n = conteo ?? 0;

    final fondo = esSel ? AppColors.primary : AppColors.surface;
    final texto = esSel ? AppColors.onPrimary : AppColors.foreground;
    final borde = esSel
        ? null
        : Border.all(
            color: esHoy ? AppColors.primary : AppColors.border,
            width: esHoy ? 2 : 1,
          );

    return Semantics(
      button: true,
      selected: esSel,
      excludeSemantics: true,
      label:
          '${nombreDiaLargo(dia)} ${dia.day}, '
          '${n == 1 ? '1 cita' : '$n citas'}${esSel ? ', seleccionado' : ''}',
      onTap: () => onTap(dia),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          key: ValueKey('dia-${dia.year}-${dia.month}-${dia.day}'),
          onTap: () => onTap(dia),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 64),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: fondo,
              border: borde,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  diaAbrev(dia),
                  style: textTheme.labelMedium?.copyWith(color: texto),
                ),
                Text(
                  '${dia.day}',
                  style: textTheme.headlineSmall?.copyWith(color: texto),
                ),
                const SizedBox(height: 2),
                if (conteo != null && n > 0)
                  Container(
                    constraints: const BoxConstraints(minHeight: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: esSel
                          ? AppColors.primaryStrong
                          : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      '$n',
                      style: textTheme.labelMedium?.copyWith(
                        color: esSel
                            ? AppColors.onPrimary
                            : AppColors.foreground,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
