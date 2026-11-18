import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/clock_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato_hora.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/status/app_status_chip.dart';
import '../../../../core/widgets/status/vet_avatar.dart';
import '../../../appointments/domain/entities/cita.dart';
import '../../../appointments/presentation/agenda_routes.dart';
import '../../../appointments/presentation/estado_cita_ui.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../../plan/presentation/providers/plan_providers.dart';
import '../../../plan/presentation/widgets/control_escritura.dart';
import '../../../team/presentation/providers/team_providers.dart';
import '../../domain/inicio_failure.dart';
import '../providers/inicio_providers.dart';
import 'bloque_error.dart';
import 'inicio_colores.dart';

/// Alto mínimo de una fila (y de su esqueleto), UI-SPEC §5.4.
const double _kAltoFila = 72;

/// Lado de la marca inicial de la fila (avatar o huella).
const double _kMarca = 40;

/// Próximas citas de la clínica en Inicio (DASH-02): hasta 5 pendientes o
/// confirmadas desde ahora, agrupadas por día de Bogotá. El encabezado y
/// "Ver agenda" se ven en todo estado; un error solo afecta a este bloque
/// (D-14) y al refrescar se conservan las filas viejas.
class ProximasCitas extends ConsumerWidget {
  const ProximasCitas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(proximasCitasProvider);
    final citas = async.value;

    final Widget cuerpo;
    if (citas == null && async.hasError) {
      final error = async.error;
      cuerpo = BloqueError(
        failure: error is InicioFailure
            ? error
            : const InicioFailure(kErrorProximasCitas),
        cargando: async.isLoading,
        onReintentar: () => ref.invalidate(proximasCitasProvider),
      );
    } else if (citas == null) {
      cuerpo = const Column(
        children: [
          _FilaEsqueleto(),
          SizedBox(height: AppSpacing.sm),
          _FilaEsqueleto(),
          SizedBox(height: AppSpacing.sm),
          _FilaEsqueleto(),
        ],
      );
    } else if (citas.isEmpty) {
      cuerpo = const _SinCitas();
    } else {
      cuerpo = _Filas(citas: citas, hoy: diaBogota(ref.watch(clockProvider)()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Próximas citas',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: InicioColores.principal(context),
                  ),
                ),
              ),
            ),
            AppButton(
              label: 'Ver agenda',
              variant: AppButtonVariant.text,
              expand: false,
              onPressed: () => context.go('/agenda'),
              contenido: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Ver agenda'),
                  ExcludeSemantics(child: Icon(Icons.chevron_right, size: 20)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        cuerpo,
      ],
    );
  }
}

/// Filas con un separador [encabezadoDia] antes de cada día, incluido el
/// primero, para que la fecha siempre quede explícita (UI-SPEC §5.3).
class _Filas extends StatelessWidget {
  const _Filas({required this.citas, required this.hoy});

  final List<Cita> citas;
  final DateTime hoy;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: InicioColores.tenue(context));
    final hijos = <Widget>[];
    DateTime? diaActual;
    for (final cita in citas) {
      final dia = diaBogota(cita.fechaHora);
      if (dia != diaActual) {
        if (diaActual != null) {
          hijos.add(const SizedBox(height: AppSpacing.md));
        }
        hijos
          ..add(
            Semantics(
              header: true,
              child: Text(encabezadoDia(dia, hoy), style: estilo),
            ),
          )
          ..add(const SizedBox(height: AppSpacing.sm));
        diaActual = dia;
      } else {
        hijos.add(const SizedBox(height: AppSpacing.sm));
      }
      hijos.add(ProximaCitaFila(cita: cita));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: hijos,
    );
  }
}

String _estadoTexto(EstadoCita e) => switch (e) {
  EstadoCita.pendiente => 'Pendiente',
  EstadoCita.confirmada => 'Confirmada',
  EstadoCita.completada => 'Completada',
  EstadoCita.cancelada => 'Cancelada',
  EstadoCita.noAsistio => 'No asistió',
};

/// Una próxima cita: marca del veterinario (o huella si la clínica tiene uno
/// solo), "{mascotas} · {motivo}", "{hora} · {cliente}" y el chip de estado.
/// Tocarla cambia a la pestaña Agenda con `go` (rama distinta del shell).
class ProximaCitaFila extends ConsumerWidget {
  const ProximaCitaFila({super.key, required this.cita});

  final Cita cita;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    // Inicio es siempre de toda la clínica: la marca no depende del filtro
    // de la agenda (D-07).
    final marcarVet = ref.watch(esClinicaMultiVetProvider);
    final activos = ref.watch(miembrosActivosProvider);
    final miembro = activos
        .where((m) => m.id == cita.veterinarioId)
        .firstOrNull;
    // Sin datos aún (lista vacía) no se marca como retirado: evita el parpadeo.
    final retirado = activos.isNotEmpty && miembro == null;
    final indice = ref.watch(indicesColorVetProvider)[cita.veterinarioId] ?? 0;
    final nombreVet = (cita.veterinarioNombre ?? miembro?.nombre ?? '').trim();

    final mascotas = cita.nombresMascotasCorto;
    final motivo = cita.motivo.trim();
    final titulo = motivo.isEmpty ? mascotas : '$mascotas · $motivo';
    final hora = hora12(aBogota(cita.fechaHora));
    final estado = _estadoTexto(cita.estado);
    final semantica = [
      hora,
      mascotas,
      if (motivo.isNotEmpty) motivo,
      cita.clienteNombre,
      estado,
      if (marcarVet && nombreVet.isNotEmpty) 'Dr(a). $nombreVet',
    ].join(', ');

    void abrir() => context.go('/agenda/${cita.id}');

    final Widget marca = marcarVet
        ? VetAvatar(
            nombre: nombreVet,
            indice: indice,
            size: _kMarca,
            retirado: retirado,
          )
        : Container(
            width: _kMarca,
            height: _kMarca,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: InicioColores.esqueleto(context),
            ),
            child: Icon(
              Icons.pets_outlined,
              size: 20,
              color: oscuro
                  ? InicioColores.tenue(context)
                  : AppColors.primaryStrong,
            ),
          );

    return Semantics(
      button: true,
      label: '$semantica. Abre el detalle de la cita',
      onTap: abrir,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kAltoFila),
        child: AppCard(
          onTap: abrir,
          child: Row(
            children: [
              marca,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: InicioColores.principal(context),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '$hora · ${cita.clienteNombre}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge?.copyWith(
                        color: InicioColores.secundario(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppStatusChip(status: estadoAStatus(cita.estado)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaEsqueleto extends StatelessWidget {
  const _FilaEsqueleto();

  @override
  Widget build(BuildContext context) {
    final color = InicioColores.esqueleto(context);
    Widget barra(double ancho) => Container(
      height: 16,
      constraints: BoxConstraints(maxWidth: ancho),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
    );
    return ExcludeSemantics(
      child: ConstrainedBox(
        key: const ValueKey('proxima-esqueleto'),
        constraints: const BoxConstraints(minHeight: _kAltoFila),
        child: AppCard(
          child: Row(
            children: [
              Container(
                width: _kMarca,
                height: _kMarca,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    barra(180),
                    const SizedBox(height: AppSpacing.xs),
                    barra(120),
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

/// Sin próximas citas (D-08): invita a agendar. En solo lectura el botón
/// conserva su lugar con candado y abre la hoja explicativa.
class _SinCitas extends ConsumerWidget {
  const _SinCitas();

  Future<void> _agendar(BuildContext context, WidgetRef ref) async {
    if (!await asegurarEscritura(
      context,
      ref,
      plan: ref.read(miPlanProvider).value,
    )) {
      return;
    }
    if (!context.mounted) return;
    unawaited(context.push(rutaNuevaCita()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puede = ref.watch(puedeEscribirProvider);
    return AppCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xl,
        horizontal: AppSpacing.md,
      ),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: InicioColores.esqueleto(context),
              ),
              child: Icon(
                Icons.event_available_outlined,
                size: 32,
                color: InicioColores.tenue(context),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No tienes citas próximas.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: InicioColores.secundario(context),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ControlEscritura(
            puedeEscribir: puede,
            label: 'Agendar cita',
            onTap: () => _agendar(context, ref),
            child: AppButton(
              label: 'Agendar cita',
              icon: iconoEscritura(puede, Icons.add),
              variant: AppButtonVariant.outline,
              expand: false,
              onPressed: () => _agendar(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}
