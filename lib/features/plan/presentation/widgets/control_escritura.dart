import 'package:flutter/material.dart';

import '../limite_plan_gate.dart';

/// Envuelve un control de escritura (botón, ícono, avatar) para el colega en
/// solo lectura: sin cambiar su lugar, variante ni tamaño, expone a
/// accesibilidad un único nodo "[label], bloqueado, solo lectura" que al
/// activarse llama a [onTap] (que abre la hoja explicativa). Con escritura
/// permitida devuelve [child] intacto, así que la semántica de siempre no
/// cambia (D-12, UI-SPEC §6: sin atenuar con opacidad).
class ControlEscritura extends StatelessWidget {
  const ControlEscritura({
    super.key,
    required this.puedeEscribir,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final bool puedeEscribir;
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (puedeEscribir) return child;
    return Semantics(
      button: true,
      label: semanticaEscritura(puedeEscribir, label),
      onTap: onTap,
      excludeSemantics: true,
      child: child,
    );
  }
}
