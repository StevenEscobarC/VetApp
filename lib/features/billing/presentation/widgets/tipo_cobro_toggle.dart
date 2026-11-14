import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/cobro.dart';

/// Control segmentado Cotización | Cuenta de cobro (UI-SPEC §2). Siempre hay
/// una opción elegida. La lista usa las etiquetas en plural; el formulario
/// reutiliza el widget con [etiquetaCot]/[etiquetaCc] en singular. Con
/// [habilitado] en `false` se dibuja igual pero no responde (lista cargando).
class TipoCobroToggle extends StatelessWidget {
  const TipoCobroToggle({
    super.key,
    required this.valor,
    required this.onChanged,
    this.etiquetaCot = 'Cotizaciones',
    this.etiquetaCc = 'Cuentas de cobro',
    this.habilitado = true,
  });

  final TipoCobro valor;
  final ValueChanged<TipoCobro> onChanged;
  final String etiquetaCot;
  final String etiquetaCc;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    Widget opcion(TipoCobro tipo, String etiqueta) {
      final sel = valor == tipo;
      return Expanded(
        child: Semantics(
          inMutuallyExclusiveGroup: true,
          checked: sel,
          selected: sel,
          enabled: habilitado,
          button: true,
          label: etiqueta,
          excludeSemantics: true,
          onTap: habilitado ? () => onChanged(tipo) : null,
          child: InkWell(
            onTap: habilitado && !sel ? () => onChanged(tipo) : null,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.touchTarget,
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : null,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: Text(
                etiqueta,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: sel ? AppColors.onPrimary : AppColors.foreground,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: 'Tipo de documento',
      explicitChildNodes: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              opcion(TipoCobro.cotizacion, etiquetaCot),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.border,
              ),
              opcion(TipoCobro.cuentaCobro, etiquetaCc),
            ],
          ),
        ),
      ),
    );
  }
}
