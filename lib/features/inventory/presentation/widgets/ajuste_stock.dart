import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../domain/entities/movimiento_stock.dart';
import '../../domain/entities/producto.dart';
import '../../domain/inventario_failure.dart';
import '../../domain/stock.dart';
import '../providers/inventario_providers.dart';

/// Ayudas compartidas por la fila de la lista, la hoja de ajuste y el detalle
/// del producto (UI-SPEC §2.2): textos del snackbar, mensajes de error y el
/// flujo "aplicar -> mostrar resultado -> Deshacer". La cantidad que se
/// muestra es siempre la que devuelve el servidor.

const _msgOffline =
    'Sin conexión. El ajuste no se guardó. Inténtalo de nuevo cuando tengas '
    'señal.';
const _msgOtro = 'No pudimos completar la operación. Intenta de nuevo.';

/// Texto del snackbar de un ajuste ya aplicado (UI-SPEC §2.2).
String textoAjusteAplicado({
  required Producto producto,
  required int delta,
  required MotivoMovimiento motivo,
  required int cantidadNueva,
}) {
  final n = delta.abs();
  final m = formatearMiles(cantidadNueva);
  final nombre = producto.nombre;
  if (n > kAjusteGrande) return 'Ajuste aplicado a $nombre. Ahora hay $m.';
  if (motivo == MotivoMovimiento.conteo) {
    return 'Stock de $nombre corregido a $m.';
  }
  final cuantos = '${formatearMiles(n)} ${producto.unidad.etiqueta(n)}';
  return delta > 0
      ? 'Agregaste $cuantos a $nombre. Ahora hay $m.'
      : 'Descontaste $cuantos de $nombre. Ahora hay $m.';
}

/// Mensaje de un ajuste fallido. Con [deshacer] el rechazo por stock significa
/// que la cantidad cambió desde el ajuste original.
String textoErrorAjuste(InventarioFailure e, {bool deshacer = false}) {
  switch (e.tipo) {
    case ErrorInventario.sinConexion:
      return _msgOffline;
    case ErrorInventario.stockInsuficiente:
      return deshacer
          ? 'El stock cambió. Ajusta la cantidad manualmente.'
          : 'No hay suficiente stock para ese ajuste. Actualiza la lista.';
    case ErrorInventario.noDisponible:
      return 'Ese producto ya no está disponible. Actualiza la lista.';
    case ErrorInventario.yaDeshecho:
      return 'Ese ajuste ya se deshizo.';
    case ErrorInventario.stockCambio:
      return e.message;
    default:
      return _msgOtro;
  }
}

/// Texto de error dentro de la hoja de ajuste (UI-SPEC §3, "Sheet failures").
String textoErrorEnHoja(InventarioFailure e) => switch (e.tipo) {
  ErrorInventario.stockInsuficiente =>
    'No hay suficiente stock para ese ajuste. Actualiza la lista y revisa la '
        'cantidad.',
  ErrorInventario.noDisponible => 'Ese producto ya no está disponible.',
  ErrorInventario.stockCambio => e.message,
  ErrorInventario.sinConexion => _msgOffline,
  _ => _msgOtro,
};

void mostrarSnackbarAjuste(
  ScaffoldMessengerState messenger,
  String texto, {
  VoidCallback? onDeshacer,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(texto),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: onDeshacer == null
            ? null
            : SnackBarAction(label: 'Deshacer', onPressed: onDeshacer),
      ),
    );
}

/// Muestra el resultado de un ajuste exitoso; solo los de |delta| <= 10 llevan
/// Deshacer, que aplica el movimiento inverso (nunca borra, D-09).
void mostrarResultadoAjuste(
  ScaffoldMessengerState messenger,
  InventarioActions actions, {
  required Producto producto,
  required int delta,
  required MotivoMovimiento motivo,
  required ResultadoAjuste resultado,
}) {
  final texto = textoAjusteAplicado(
    producto: producto,
    delta: delta,
    motivo: motivo,
    cantidadNueva: resultado.cantidadNueva,
  );
  VoidCallback? deshacer;
  if (delta.abs() <= kAjusteGrande) {
    deshacer = () async {
      try {
        final r = await actions.deshacer(
          productoId: producto.id,
          movimientoId: resultado.movimientoId,
          delta: delta,
        );
        mostrarSnackbarAjuste(
          messenger,
          'Ajuste deshecho. Ahora hay ${formatearMiles(r.cantidadNueva)}.',
        );
      } on InventarioFailure catch (e) {
        mostrarSnackbarAjuste(messenger, textoErrorAjuste(e, deshacer: true));
      }
    };
  }
  mostrarSnackbarAjuste(messenger, texto, onDeshacer: deshacer);
}

/// Aplica el ajuste y da el feedback del snackbar (con Deshacer cuando
/// corresponde). Un límite del plan abre su hoja en vez del snackbar.
Future<void> aplicarAjusteConFeedback(
  BuildContext context,
  WidgetRef ref, {
  required Producto producto,
  required int delta,
  required MotivoMovimiento motivo,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final actions = ref.read(inventarioActionsProvider);
  try {
    final r = await actions.ajustar(
      producto: producto,
      delta: delta,
      motivo: motivo,
    );
    mostrarResultadoAjuste(
      messenger,
      actions,
      producto: producto,
      delta: delta,
      motivo: motivo,
      resultado: r,
    );
  } on InventarioFailure catch (e) {
    if (context.mounted && await manejarLimitePlan(context, ref, e)) return;
    mostrarSnackbarAjuste(messenger, textoErrorAjuste(e));
  }
}

/// Descuento rápido de uno (D-09): sin hoja, motivo Uso.
Future<void> descontarUno(
  BuildContext context,
  WidgetRef ref,
  Producto producto,
) => aplicarAjusteConFeedback(
  context,
  ref,
  producto: producto,
  delta: -1,
  motivo: MotivoMovimiento.uso,
);

/// Confirmación previa de un ajuste grande (|delta| > [kAjusteGrande]).
Future<bool> confirmarAjusteGrande(
  BuildContext context, {
  required Producto producto,
  required int delta,
  required int cantidadNueva,
}) async {
  final n = delta.abs();
  final verbo = delta > 0 ? 'sumar' : 'restar';
  final prep = delta > 0 ? 'a' : 'de';
  final cuantos = '${formatearMiles(n)} ${producto.unidad.etiqueta(n)}';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Confirmas este ajuste?'),
      content: Text(
        'Vas a $verbo $cuantos $prep ${producto.nombre}. '
        'Quedarán ${formatearMiles(cantidadNueva)}.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Revisar'),
        ),
        AppButton(
          label: 'Confirmar ajuste',
          expand: false,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  return ok ?? false;
}
