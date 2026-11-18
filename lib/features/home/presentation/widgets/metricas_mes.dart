import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../billing/presentation/cobros_rutas.dart';
import '../../data/supabase_inicio_repository.dart' show kErrorResumenInicio;
import '../../domain/inicio_failure.dart';
import '../providers/inicio_providers.dart';
import 'bloque_error.dart';
import 'inicio_colores.dart';

/// Las 3 cifras del mes en Inicio (DASH-01, D-01..D-06). Vienen de una sola
/// RPC, así que fallan juntas: el error reemplaza la fila por un
/// [BloqueError]. Al refrescar se conservan las cifras viejas (sin parpadeo
/// de esqueleto). Nunca se envuelven en `ControlEscritura`: leer y navegar
/// es igual para un colega en solo lectura (D-06).
class MetricasMes extends ConsumerWidget {
  const MetricasMes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inicioResumenProvider);
    final resumen = async.value;

    if (resumen == null && async.hasError) {
      final error = async.error;
      return BloqueError(
        failure: error is InicioFailure
            ? error
            : const InicioFailure(kErrorResumenInicio),
        cargando: async.isLoading,
        onReintentar: () => ref.invalidate(inicioResumenProvider),
      );
    }

    final tarjetas = [
      MetricaTarjeta(
        kicker: 'Consultas',
        valor: resumen == null ? null : formatearMiles(resumen.consultasMes),
        semantica: resumen == null
            ? 'Consultas'
            : 'Consultas del mes: ${formatearMiles(resumen.consultasMes)}',
      ),
      MetricaTarjeta(
        kicker: 'Ingresos',
        valor: resumen == null ? null : formatearCopCorto(resumen.ingresosMes),
        semantica: resumen == null
            ? 'Ingresos'
            : 'Ingresos del mes: ${formatearCop(resumen.ingresosMes)}. '
                  'Abre Cobros',
        onTap: resumen == null ? null : () => context.push(kRutaCobros),
      ),
      MetricaTarjeta(
        kicker: 'Pacientes nuevos',
        valor: resumen == null ? null : formatearMiles(resumen.pacientesNuevos),
        semantica: resumen == null
            ? 'Pacientes nuevos'
            : 'Pacientes nuevos del mes: '
                  '${formatearMiles(resumen.pacientesNuevos)}. Abre Pacientes',
        onTap: resumen == null ? null : () => context.go('/pacientes'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final apilar =
            constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(16) > 20.8;
        if (apilar) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tarjetas.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                MetricaTarjeta(
                  kicker: tarjetas[i].kicker,
                  valor: tarjetas[i].valor,
                  semantica: tarjetas[i].semantica,
                  onTap: tarjetas[i].onTap,
                  apilada: true,
                ),
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tarjetas.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(child: tarjetas[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Una cifra del mes. [valor] `null` = cargando (barra de esqueleto con el
/// kicker real). Solo es botón cuando [onTap] no es `null`: Consultas no
/// tiene lista global a la que ir (D-04).
class MetricaTarjeta extends StatelessWidget {
  const MetricaTarjeta({
    super.key,
    required this.kicker,
    required this.valor,
    required this.semantica,
    this.onTap,
    this.apilada = false,
  });

  final String kicker;
  final String? valor;
  final String semantica;
  final VoidCallback? onTap;

  /// Una fila por tarjeta (pantalla angosta o texto grande).
  final bool apilada;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tenue = InicioColores.tenue(context);
    final tocable = onTap != null;

    final textoKicker = Text(
      kicker,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: t.labelLarge?.copyWith(color: tenue),
    );
    final chevron = Icon(Icons.chevron_right, size: 16, color: tenue);
    final valor = this.valor;
    final Widget cifra = valor == null
        ? Container(
            key: const ValueKey('metrica-esqueleto'),
            width: 56,
            height: 28,
            decoration: BoxDecoration(
              color: InicioColores.esqueleto(context),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            alignment: apilada ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              valor,
              style: t.displaySmall?.copyWith(
                color: InicioColores.numero(context),
              ),
            ),
          );

    final Widget cuerpo = apilada
        ? ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Row(
              children: [
                Expanded(child: textoKicker),
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: cifra),
                if (tocable) ...[const SizedBox(width: AppSpacing.xs), chevron],
              ],
            ),
          )
        : ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: textoKicker),
                    if (tocable) chevron,
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                cifra,
              ],
            ),
          );

    return Semantics(
      container: true,
      button: tocable,
      label: semantica,
      onTap: onTap,
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: cuerpo,
      ),
    );
  }
}
