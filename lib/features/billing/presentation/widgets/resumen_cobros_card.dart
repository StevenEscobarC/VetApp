import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/clock_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../providers/cobros_providers.dart';
import 'cobro_fila.dart';

// Escritos a mano: la app nunca llama `initializeDateFormatting`.
const _meses = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// '1 cuenta pendiente', '{n} cuentas pendientes' o 'Nada pendiente'.
String textoPendientes(int n) => switch (n) {
  0 => 'Nada pendiente',
  1 => '1 cuenta pendiente',
  _ => '$n cuentas pendientes',
};

/// Encabezado de la lista de cobros (D-17): lo cobrado este mes y lo que
/// falta por cobrar. Las dos cifras vienen del servidor (`cobros_resumen`),
/// nunca se suman en el cliente con la página visible.
class ResumenCobrosCard extends ConsumerWidget {
  const ResumenCobrosCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(resumenCobrosProvider);
    final hoy = diaBogota(ref.watch(clockProvider)());
    final mes = '${_meses[hoy.month - 1]} ${hoy.year}';
    final apilar = MediaQuery.textScalerOf(context).scale(10) >= 13;

    final resumen = async.value;
    final Widget cuerpo;
    final String? semantica;
    if (resumen != null) {
      final pend = textoPendientes(resumen.pendientes);
      semantica =
          'Cobrado este mes, ${pesosSemantica(resumen.cobradoMes)}. '
          'Por cobrar, ${pesosSemantica(resumen.porCobrar)}, $pend.';
      cuerpo = _columnas(
        apilar: apilar,
        izquierda: _Columna(
          titulo: 'Cobrado este mes',
          monto: formatearCop(resumen.cobradoMes),
          sub: mes,
        ),
        derecha: _Columna(
          titulo: 'Por cobrar',
          monto: formatearCop(resumen.porCobrar),
          sub: pend,
        ),
      );
    } else if (async.hasError) {
      semantica = null;
      cuerpo = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _columnas(
            apilar: apilar,
            izquierda: const _Columna(titulo: 'Cobrado este mes', monto: '—'),
            derecha: const _Columna(titulo: 'Por cobrar', monto: '—'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No pudimos cargar el resumen. Desliza hacia abajo para '
            'reintentar.',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
          ),
        ],
      );
    } else {
      semantica = null;
      cuerpo = _columnas(
        apilar: apilar,
        izquierda: const _Bloque(),
        derecha: const _Bloque(),
      );
    }

    return AppCard(
      child: semantica == null
          ? cuerpo
          : Semantics(label: semantica, excludeSemantics: true, child: cuerpo),
    );
  }

  Widget _columnas({
    required bool apilar,
    required Widget izquierda,
    required Widget derecha,
  }) {
    if (apilar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          izquierda,
          const Divider(
            height: AppSpacing.md,
            thickness: 1,
            color: AppColors.border,
          ),
          derecha,
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: izquierda),
          const VerticalDivider(
            width: AppSpacing.md,
            thickness: 1,
            color: AppColors.border,
          ),
          Expanded(child: derecha),
        ],
      ),
    );
  }
}

class _Columna extends StatelessWidget {
  const _Columna({required this.titulo, required this.monto, this.sub});

  final String titulo;
  final String monto;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titulo,
          style: t.labelLarge?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            monto,
            style: t.displaySmall?.copyWith(color: AppColors.primaryText),
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(sub!, style: t.labelLarge?.copyWith(color: AppColors.textMuted)),
        ],
      ],
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque();

  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
  );
}
