import 'package:flutter/material.dart';

import '../../../../core/utils/formato.dart';
import '../providers/registrar_dosis_providers.dart';

/// Confirmación tras registrar una dosis: 'Dosis registrada. Próxima:
/// dd/mm/aaaa' (sin la parte de la próxima cuando no hay refuerzo). Sin
/// "Deshacer": las dosis son append-only, se corrigen con Anular.
void mostrarDosisRegistrada(
  BuildContext context,
  DosisRegistrada r, {
  VoidCallback? onCompartir,
}) {
  final proxima = r.proximaFecha;
  final texto = proxima == null
      ? 'Dosis registrada.'
      : 'Dosis registrada. Próxima: ${formatearFecha(proxima)}';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(texto),
        action: onCompartir == null
            ? null
            : SnackBarAction(label: 'Compartir carné', onPressed: onCompartir),
      ),
    );
}
