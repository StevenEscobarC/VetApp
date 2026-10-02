import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/chips/app_filter_chip.dart';
import '../../domain/duraciones.dart';

/// Selector de duración / intervalo con chips de 48dp (D-03): nunca se
/// escribe una fecha. `null` significa "Sin refuerzo" (solo si
/// [incluirSinRefuerzo]).
class DuracionChips extends StatelessWidget {
  const DuracionChips({
    super.key,
    required this.titulo,
    required this.opciones,
    required this.seleccion,
    this.incluirSinRefuerzo = false,
    required this.onChanged,
  });

  final String titulo;
  final List<int> opciones;
  final int? seleccion;
  final bool incluirSinRefuerzo;
  final ValueChanged<int?> onChanged;

  Widget _chip(String label, bool selected, int? valor) => Semantics(
    button: true,
    selected: selected,
    label: selected ? 'Duración $label, seleccionada' : 'Duración $label',
    excludeSemantics: true,
    child: AppFilterChip(
      label: label,
      selected: selected,
      onTap: () => onChanged(valor),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final d in opciones)
              _chip(etiquetaDuracion(d), seleccion == d, d),
            if (incluirSinRefuerzo)
              _chip('Sin refuerzo', seleccion == null, null),
          ],
        ),
      ],
    );
  }
}
