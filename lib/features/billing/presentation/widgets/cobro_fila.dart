import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../domain/entities/cobro.dart';
import '../cobros_rutas.dart';
import 'estado_cobro_chip.dart';

/// Monto leído completo por accesibilidad ('120.000 pesos').
String pesosSemantica(int pesos) => '${formatearMiles(pesos)} pesos';

/// Validez de una cotización abierta para la meta de la lista: 'Válida hasta
/// …' o 'Venció el …' (solo se muestra; el estado no cambia, D-23). `null`
/// si el documento no es una cotización abierta con fecha de validez.
String? validezCotizacion(Cobro c, DateTime hoyBogota) {
  final v = c.validaHasta;
  if (!c.esCotizacion || !c.abierta || v == null) return null;
  return c.vencida(hoyBogota)
      ? 'Venció el ${formatearFecha(v)}'
      : 'Válida hasta ${formatearFecha(v)}';
}

/// Tarjeta de un cobro en la lista (UI-SPEC §2.1). Toda la tarjeta es un
/// solo nodo de accesibilidad y abre el detalle.
class CobroFila extends StatelessWidget {
  const CobroFila({super.key, required this.cobro, required this.hoy});

  final Cobro cobro;

  /// Día de Bogotá del reloj inyectado, para la validez de cotizaciones.
  final DateTime hoy;

  @override
  Widget build(BuildContext context) {
    final c = cobro;
    final textTheme = Theme.of(context).textTheme;
    final mascota = c.mascotaNombre;
    final titulo = mascota == null
        ? c.clienteNombre
        : '${c.clienteNombre} · $mascota';
    final validez = validezCotizacion(c, hoy);
    final meta = [
      c.numeroTexto,
      formatearFecha(c.fecha),
      if (c.resumenLineas.isNotEmpty) c.resumenLineas,
      ?validez,
    ].join(' · ');
    final chip = EstadoCobroChip.para(c.estado);
    final semantica = [
      '${c.tipo.etiqueta} ${c.numeroTexto}',
      c.clienteNombre,
      ?mascota,
      pesosSemantica(c.totalCop),
      validez ?? c.estado.etiqueta,
      formatearFecha(c.fecha),
    ].join(', ');

    return Semantics(
      label: '$semantica. Abrir detalle.',
      button: true,
      excludeSemantics: true,
      onTap: () => context.push(rutaCobro(c.id)),
      child: AppCard(
        onTap: () => context.push(rutaCobro(c.id)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  c.esCotizacion
                      ? Icons.request_quote_outlined
                      : Icons.receipt_long_outlined,
                  size: 20,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      meta,
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatearCop(c.totalCop),
                      style: textTheme.headlineSmall?.copyWith(
                        color: c.anulada
                            ? AppColors.textMuted
                            : AppColors.foreground,
                        decoration: c.anulada
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  if (chip != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    chip,
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
