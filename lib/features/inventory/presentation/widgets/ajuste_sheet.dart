import 'package:flutter/material.dart';

import '../../domain/entities/movimiento_stock.dart';
import '../../domain/entities/producto.dart';

/// Hoja "Ajustar stock". La versión completa (motivos, cantidad, vista previa)
/// llega en la Tarea 2 de este plan; esta firma permite que los botones de la
/// fila ya la abran.
Future<void> mostrarAjusteSheet(
  BuildContext context, {
  required Producto producto,
  required MotivoMovimiento motivoInicial,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const SizedBox(height: 120),
);
