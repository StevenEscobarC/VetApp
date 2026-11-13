import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../domain/entities/producto.dart';
import 'insignia_stock.dart';

/// Fila de la lista de inventario: nombre, mínimo / vencimiento, cantidad e
/// insignias de estado. Los botones de ajuste rápido y la apertura del detalle
/// llegan en planes posteriores.
class ProductoFila extends StatelessWidget {
  const ProductoFila({super.key, required this.producto, required this.hoy});

  final Producto producto;
  final DateTime hoy;

  String get _meta {
    final v = producto.vencimiento;
    final base = 'Mínimo ${formatearMiles(producto.minimo)}';
    return v == null ? base : '$base · Vence ${formatearFecha(v)}';
  }

  String get _semantica {
    final p = producto;
    final etiquetas = [
      for (final e in estadosDe(p, hoy))
        switch (e) {
          EstadoStock.agotado => 'Agotado',
          EstadoStock.bajo => 'Bajo',
          EstadoStock.vencido => 'Vencido',
          EstadoStock.vencePronto => 'Vence pronto',
        },
    ];
    final v = p.vencimiento;
    return [
      p.nombre,
      '${formatearMiles(p.cantidad)} ${p.unidad.etiqueta(p.cantidad)}',
      'mínimo ${formatearMiles(p.minimo)}',
      ...etiquetas,
      if (v != null) 'vence ${formatearFecha(v)}',
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = producto;
    final insignias = insigniasDe(p, hoy);
    return Semantics(
      label: '$_semantica.',
      excludeSemantics: true,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nombre,
                        style: textTheme.headlineSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _meta,
                        style: textTheme.labelLarge?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          formatearMiles(p.cantidad),
                          style: textTheme.displaySmall,
                        ),
                      ),
                      Text(
                        p.unidad.etiqueta(p.cantidad),
                        style: textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (insignias.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: insignias,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
