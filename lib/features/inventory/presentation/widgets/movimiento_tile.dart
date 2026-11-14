import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/utils/formato_hora.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../domain/entities/movimiento_stock.dart';
import '../../domain/entities/producto.dart';

/// Fila del historial de un producto (UI-SPEC §5.3). Solo lectura. La
/// dirección se comunica con el signo y la flecha; una salida es normal, así
/// que nunca va en rojo. El autor se conserva aunque ya no esté en la clínica
/// ("Veterinario" si no se conoce).
class MovimientoTile extends StatelessWidget {
  const MovimientoTile({
    super.key,
    required this.movimiento,
    required this.unidad,
  });

  final MovimientoStock movimiento;
  final Unidad unidad;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final m = movimiento;
    final entra = m.delta > 0;
    final n = m.delta.abs();
    // Ventas y anulaciones de cuentas de cobro llevan el número del documento
    // en vez de "Venta" / "Ajuste deshecho" (UI-SPEC §7). Sin deshacer aquí.
    final motivo = m.origen == kOrigenCobro
        ? (m.motivo == MotivoMovimiento.deshacer
              ? (m.nota ?? 'Anulada')
              : 'Cuenta de cobro${m.nota == null ? '' : ' ${m.nota}'}')
        : m.motivo.etiqueta;
    final titulo =
        '${entra ? '+' : '−'}${formatearMiles(n)} ${unidad.etiqueta(n)} · '
        '$motivo';
    final autor = (m.autorNombre ?? '').trim();
    final subtitulo =
        'Quedaron ${formatearMiles(m.cantidadResultante)} · '
        '${formatearFecha(m.creadoEn)} ${hora12(m.creadoEn)} · '
        '${autor.isEmpty ? 'Veterinario' : autor}';
    return Semantics(
      label: '$titulo. $subtitulo.',
      excludeSemantics: true,
      child: AppCard(
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
                  entra ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 20,
                  color: entra ? AppColors.success : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: textTheme.bodyLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitulo,
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
