import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/clock_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato_hora.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import 'package:go_router/go_router.dart';

import '../../domain/cita_solapes.dart';
import '../../domain/entities/cita.dart';
import '../providers/citas_providers.dart';
import '../widgets/cita_card.dart';
import '../widgets/day_strip.dart';
import '../widgets/proxima_banner.dart';

/// Agenda del veterinario (AGND-01): semana LUN-DOM con conteos por día,
/// lista del día por hora, banner de próxima cita y estados de carga /
/// vacío / error. Siempre abre en "hoy" de Bogotá (D-08).
class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key, this.diaInicial});

  /// Día de Bogotá (`DateTime.utc(y, m, d)`) a seleccionar al abrir; `null`
  /// abre en hoy. Lo usa el formulario de cita al volver a la agenda.
  final DateTime? diaInicial;

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  late DateTime _lunes;
  late DateTime _dia;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final hoy = diaBogota(ref.read(clockProvider)());
    _dia = widget.diaInicial ?? hoy;
    _lunes = lunesDeSemana(_dia);
    // Refresca "en N min" y el banner mientras la pantalla está abierta.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(AgendaScreen old) {
    super.didUpdateWidget(old);
    final nuevo = widget.diaInicial;
    if (nuevo != null && nuevo != old.diaInicial) {
      _dia = nuevo;
      _lunes = lunesDeSemana(nuevo);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _cambiarSemana(int semanas) {
    setState(() {
      final offset = _dia.difference(_lunes).inDays;
      _lunes = DateTime.utc(_lunes.year, _lunes.month, _lunes.day + 7 * semanas);
      _dia = DateTime.utc(_lunes.year, _lunes.month, _lunes.day + offset);
    });
  }

  void _irAHoy() {
    final hoy = diaBogota(ref.read(clockProvider)());
    setState(() {
      _dia = hoy;
      _lunes = lunesDeSemana(hoy);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ahora = ref.read(clockProvider)();
    final hoy = diaBogota(ahora);
    final citasAsync = ref.watch(agendaSemanaProvider(_lunes));

    final citas = citasAsync.asData?.value;
    final conteos = citas == null ? null : _conteos(citas);
    final delDia = citas == null
        ? const <Cita>[]
        : citas
              .where((c) => mismoDia(diaBogota(c.fechaHora), _dia))
              .toList();

    return Scaffold(
      appBar: const AppTopBar(title: 'Agenda'),
      body: Column(
        children: [
          _EncabezadoSemana(
            lunes: _lunes,
            mostrarHoy: !mismoDia(_dia, hoy),
            onAnterior: () => _cambiarSemana(-1),
            onSiguiente: () => _cambiarSemana(1),
            onHoy: _irAHoy,
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -200) _cambiarSemana(1);
              if (v > 200) _cambiarSemana(-1);
            },
            child: DayStrip(
              lunes: _lunes,
              seleccionado: _dia,
              hoy: hoy,
              conteos: conteos,
              onSeleccionar: (d) => setState(() => _dia = d),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xxl + AppSpacing.md,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        encabezadoDia(_dia, hoy),
                        style: textTheme.headlineSmall,
                      ),
                    ),
                    if (citas != null)
                      Text(
                        conteoCitas(
                          delDia
                              .where((c) => c.estado != EstadoCita.cancelada)
                              .length,
                        ),
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ..._cuerpo(citasAsync, delDia, hoy, ahora),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppButton(
                label: 'Nueva cita',
                icon: Icons.add,
                onPressed: () => context.push(
                  Uri(
                    path: '/agenda/nueva',
                    queryParameters: {'fecha': _yyyyMmDd(_dia)},
                  ).toString(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _cuerpo(
    AsyncValue<List<Cita>> citasAsync,
    List<Cita> delDia,
    DateTime hoy,
    DateTime ahora,
  ) {
    return citasAsync.when(
      loading: () => [
        for (var i = 0; i < 3; i++) ...[
          const _CitaSkeleton(),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
      error: (_, _) => [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No pudimos cargar la agenda. Intenta de nuevo.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Reintentar',
                variant: AppButtonVariant.outline,
                expand: false,
                onPressed: () =>
                    ref.invalidate(agendaSemanaProvider(_lunes)),
              ),
            ],
          ),
        ),
      ],
      data: (_) {
        final widgets = <Widget>[];
        if (mismoDia(_dia, hoy)) {
          final proxima = delDia
              .where((c) => !c.estado.esTerminal && c.fechaHora.isAfter(ahora))
              .firstOrNull;
          if (proxima != null) {
            widgets
              ..add(ProximaBanner(cita: proxima, ahora: ahora))
              ..add(const SizedBox(height: AppSpacing.md));
          }
        }
        if (delDia.isEmpty) {
          widgets.add(_Vacio(pasado: _dia.isBefore(hoy)));
          return widgets;
        }
        widgets.addAll(_porHora(delDia));
        return widgets;
      },
    );
  }

  Map<DateTime, int> _conteos(List<Cita> citas) {
    final mapa = <DateTime, int>{};
    for (final c in citas) {
      if (c.estado == EstadoCita.cancelada) continue;
      final d = diaBogota(c.fechaHora);
      mapa[d] = (mapa[d] ?? 0) + 1;
    }
    return mapa;
  }

  static String _yyyyMmDd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Nombre(s) de la cita activa anterior con la que [c] se cruza (D-09).
  String? _cruceCon(Cita c, List<Cita> delDia) {
    if (!ocupaHorario(c.estado)) return null;
    for (final o in delDia) {
      if (o.id == c.id || !ocupaHorario(o.estado)) continue;
      if (o.fechaHora.isBefore(c.fechaHora) &&
          solapa(c.fechaHora, c.duracionMin, o.fechaHora, o.duracionMin)) {
        return o.nombresMascotasCorto;
      }
    }
    return null;
  }

  List<Widget> _porHora(List<Cita> delDia) {
    final grupos = <int, List<Cita>>{};
    for (final c in delDia) {
      grupos.putIfAbsent(aBogota(c.fechaHora).hour, () => []).add(c);
    }
    final horas = grupos.keys.toList()..sort();
    final textTheme = Theme.of(context).textTheme;
    return [
      for (final h in horas)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 64,
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      hora12(aBogota(grupos[h]!.first.fechaHora)),
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.border,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    children: [
                      for (final c in grupos[h]!) ...[
                        CitaCard(cita: c, cruceCon: _cruceCon(c, delDia)),
                        if (c != grupos[h]!.last)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }
}

class _EncabezadoSemana extends StatelessWidget {
  const _EncabezadoSemana({
    required this.lunes,
    required this.mostrarHoy,
    required this.onAnterior,
    required this.onSiguiente,
    required this.onHoy,
  });

  final DateTime lunes;
  final bool mostrarHoy;
  final VoidCallback onAnterior;
  final VoidCallback onSiguiente;
  final VoidCallback onHoy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const caja = BoxConstraints.tightFor(width: 48, height: 48);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Semana anterior',
            constraints: caja,
            icon: const Icon(Icons.chevron_left),
            onPressed: onAnterior,
          ),
          Text(rangoSemanaTexto(lunes), style: textTheme.titleMedium),
          IconButton(
            tooltip: 'Semana siguiente',
            constraints: caja,
            icon: const Icon(Icons.chevron_right),
            onPressed: onSiguiente,
          ),
          const Spacer(),
          if (mostrarHoy) TextButton(onPressed: onHoy, child: const Text('Hoy')),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.pasado});

  final bool pasado;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          const Icon(Icons.event_outlined, size: 48, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm),
          Text('Sin citas este día', style: textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            pasado
                ? 'No hubo citas este día.'
                : 'Toca “Nueva cita” para agendar la primera.',
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CitaSkeleton extends StatelessWidget {
  const _CitaSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bloque(double w) => Container(
      width: w,
      height: 14,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bloque(120),
          const SizedBox(height: AppSpacing.sm),
          bloque(180),
          const SizedBox(height: AppSpacing.sm),
          bloque(100),
        ],
      ),
    );
  }
}
