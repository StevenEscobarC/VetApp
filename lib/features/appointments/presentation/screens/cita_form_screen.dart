import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/clock_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato_hora.dart';
import '../../../../core/utils/telefono_co.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/chips/app_filter_chip.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../clients/domain/entities/cliente.dart';
import '../../../clients/presentation/providers/clientes_providers.dart';
import '../../../patients/domain/entities/mascota.dart';
import '../../../patients/presentation/providers/mascotas_providers.dart';
import '../../domain/cita_failure.dart';
import '../../domain/cita_solapes.dart';
import '../../domain/entities/cita.dart';
import '../../domain/motivos_cita.dart';
import '../providers/citas_providers.dart';
import '../widgets/cliente_search_field.dart';
import '../widgets/mascota_multi_select.dart';
import '../widgets/time_stepper.dart';

/// "Nueva cita" (AGND-02). Solo cliente, al menos una mascota, fecha y hora
/// son obligatorios (D-01); la hora arranca en el primer hueco libre del día
/// (D-06) y un cruce con otra cita solo advierte, nunca bloquea (D-09).
/// Abierta desde una ficha ([clienteIdInicial]/[mascotaIdInicial]) llega con
/// cliente y mascota ya elegidos (D-07).
class CitaFormScreen extends ConsumerStatefulWidget {
  const CitaFormScreen({
    super.key,
    this.clienteIdInicial,
    this.mascotaIdInicial,
    this.fechaInicial,
    this.citaId,
  });

  final String? clienteIdInicial;
  final String? mascotaIdInicial;

  /// Día de Bogotá (`DateTime.utc(y, m, d)`) preseleccionado.
  final DateTime? fechaInicial;

  /// Si no es null, el formulario edita esa cita (cliente fijo).
  final String? citaId;

  @override
  ConsumerState<CitaFormScreen> createState() => _CitaFormScreenState();
}

class _CitaFormScreenState extends ConsumerState<CitaFormScreen> {
  final _otroCtrl = TextEditingController();
  final _dirCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  String? _clienteId;
  // null = el usuario aún no tocó las casillas (se usa la selección por defecto).
  Set<String>? _mascotasSel;
  bool _quitoUltima = false;

  late DateTime _dia;
  String _motivo = motivoPorDefecto;
  int _duracion = duracionPorDefecto(motivoPorDefecto);
  int? _minutosManual;
  bool _domicilio = false;
  bool _notasExpandidas = false;

  bool _loading = false;
  String? _error;

  // Modo edición: los campos se precargan una sola vez desde la cita.
  bool _prefilled = false;
  bool get _editando => widget.citaId != null;

  void _precargar(Cita c) {
    if (_prefilled) return;
    final cuando = aBogota(c.fechaHora);
    setState(() {
      _prefilled = true;
      _clienteId = c.clienteId;
      _mascotasSel = c.mascotas.map((m) => m.id).toSet();
      final conocido = motivosCita.any((m) => m.label == c.motivo);
      if (conocido) {
        _motivo = c.motivo;
      } else {
        _motivo = 'Otro';
        _otroCtrl.text = c.motivo;
      }
      _duracion = c.duracionMin;
      _dia = diaBogota(c.fechaHora);
      _minutosManual = cuando.hour * 60 + cuando.minute;
      _domicilio = c.modalidad == ModalidadCita.domicilio;
      _dirCtrl.text = c.direccion ?? '';
      final notas = (c.notas ?? '').trim();
      _notasCtrl.text = notas;
      _notasExpandidas = notas.isNotEmpty;
    });
  }

  @override
  void initState() {
    super.initState();
    _clienteId = widget.clienteIdInicial;
    _dia = widget.fechaInicial ?? diaBogota(ref.read(clockProvider)());
    for (final c in [_otroCtrl, _dirCtrl, _notasCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _otroCtrl.dispose();
    _dirCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  // ----- selección derivada -------------------------------------------------

  Set<String> _seleccionEfectiva(List<Mascota>? mascotas) {
    final manual = _mascotasSel;
    if (manual != null) return manual;
    if (mascotas == null) return const {};
    final inicial = widget.mascotaIdInicial;
    if (inicial != null && mascotas.any((m) => m.id == inicial)) {
      return {inicial};
    }
    if (mascotas.length == 1) return {mascotas.first.id};
    return const {};
  }

  /// Citas activas del día cargadas, o `null` si la agenda no está lista.
  List<Cita>? _citasDelDia(AsyncValue<List<Cita>> semana) {
    final data = semana.asData?.value;
    if (data == null) return null;
    return data.where((c) => mismoDia(diaBogota(c.fechaHora), _dia)).toList();
  }

  /// Hora (min desde medianoche) efectiva y el texto de ayuda.
  ({int? minutos, String ayuda}) _hora(AsyncValue<List<Cita>> semana) {
    if (_minutosManual != null) {
      return (minutos: _minutosManual, ayuda: 'Hora elegida');
    }
    final ahora = ref.read(clockProvider)();
    final citas = _citasDelDia(semana);
    if (citas != null) {
      final h = primerHuecoLibre(
        citas: citas,
        dia: _dia,
        ahora: ahora,
        duracionMin: _duracion,
      );
      return (minutos: minutosDelDia(h), ayuda: 'Primer hueco libre sugerido');
    }
    if (semana.hasError) {
      final h = primerHuecoLibre(
        citas: const [],
        dia: _dia,
        ahora: ahora,
        duracionMin: _duracion,
      );
      return (
        minutos: minutosDelDia(h),
        ayuda: 'No pudimos revisar tu agenda; elige la hora.',
      );
    }
    return (minutos: null, ayuda: 'Buscando hueco libre…');
  }

  String get _motivoGuardado {
    if (_motivo != 'Otro') return _motivo;
    final t = _otroCtrl.text.trim();
    return t.isEmpty ? 'Otro' : t;
  }

  // ----- acciones -----------------------------------------------------------

  void _seleccionarCliente(Cliente c) {
    setState(() {
      _clienteId = c.id;
      _mascotasSel = null;
      _quitoUltima = false;
      if (_domicilio) _dirCtrl.text = c.direccion ?? '';
    });
  }

  void _quitarCliente() {
    setState(() {
      _clienteId = null;
      _mascotasSel = null;
      _quitoUltima = false;
    });
  }

  Future<void> _nuevoClienteYMascota() async {
    final r = await context.push<({String clienteId, String mascotaId})>(
      '/agenda/nueva/cliente',
    );
    if (r == null || !mounted) return;
    ref.invalidate(clienteProvider(r.clienteId));
    ref.invalidate(mascotasDeClienteProvider(r.clienteId));
    setState(() {
      _clienteId = r.clienteId;
      _mascotasSel = {r.mascotaId};
      _quitoUltima = false;
    });
  }

  Future<void> _agregarMascota(String clienteId) async {
    await context.push('/agenda/nueva/mascota?clienteId=$clienteId');
    if (!mounted) return;
    ref.invalidate(mascotasDeClienteProvider(clienteId));
  }

  Future<void> _elegirFecha() async {
    final elegido = await showDatePicker(
      context: context,
      initialDate: DateTime(_dia.year, _dia.month, _dia.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (elegido == null || !mounted) return;
    setState(() {
      _dia = DateTime.utc(elegido.year, elegido.month, elegido.day);
      _minutosManual = null;
    });
  }

  void _toggleDomicilio(bool v, Cliente? cliente) {
    setState(() {
      _domicilio = v;
      if (v && _dirCtrl.text.trim().isEmpty) {
        _dirCtrl.text = cliente?.direccion ?? '';
      }
    });
  }

  Future<bool> _confirmarCruce(List<Cita> cruces) async {
    final String cuerpo;
    if (cruces.length == 1) {
      final c = cruces.first;
      cuerpo =
          'Se cruza con ${c.nombresMascotasCorto} a las '
          '${hora12(aBogota(c.fechaHora))} ¿Agendar igual?';
    } else {
      final items = cruces
          .map((c) => '${c.nombresMascotasCorto} ${hora12(aBogota(c.fechaHora))}')
          .join(', ');
      cuerpo = 'Se cruza con ${cruces.length} citas: $items ¿Agendar igual?';
    }
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se cruza con otra cita'),
        content: Text(cuerpo),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cambiar hora'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(_editando ? 'Guardar igual' : 'Agendar igual'),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _submit(Set<String> mascotas, int minutos) async {
    if (_loading || _clienteId == null) return;
    final fechaHora = deBogota(_dia.year, _dia.month, _dia.day, 0, minutos);

    final semana = ref.read(agendaSemanaProvider(lunesDeSemana(_dia)));
    final delDia = _citasDelDia(semana);
    if (delDia != null) {
      final cruces = solapesCon(
        inicio: fechaHora,
        duracionMin: _duracion,
        citas: delDia,
        excluirId: widget.citaId,
      );
      if (cruces.isNotEmpty) {
        final seguir = await _confirmarCruce(cruces);
        if (!seguir || !mounted) return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final modalidad = _domicilio
          ? ModalidadCita.domicilio
          : ModalidadCita.consultorio;
      final acciones = ref.read(citaActionsProvider);
      if (_editando) {
        await acciones.actualizar(
          citaId: widget.citaId!,
          mascotaIds: mascotas.toList(),
          fechaHora: fechaHora,
          duracionMin: _duracion,
          modalidad: modalidad,
          direccion: _dirCtrl.text.trim(),
          motivo: _motivoGuardado,
          notas: _notasCtrl.text.trim(),
        );
      } else {
        await acciones.crear(
          clienteId: _clienteId!,
          mascotaIds: mascotas.toList(),
          fechaHora: fechaHora,
          duracionMin: _duracion,
          modalidad: modalidad,
          direccion: _dirCtrl.text.trim(),
          motivo: _motivoGuardado,
          notas: _notasCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editando ? 'Cita actualizada' : 'Cita agendada'),
        ),
      );
      context.go(
        Uri(
          path: '/agenda',
          queryParameters: {'dia': _yyyyMmDd(_dia)},
        ).toString(),
      );
    } on CitaFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _yyyyMmDd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ----- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (_editando && !_prefilled) {
      final citaAsync = ref.watch(citaProvider(widget.citaId!));
      final cita = citaAsync.asData?.value;
      Widget centro(List<Widget> hijos) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: hijos),
        ),
      );
      final Widget cuerpo;
      if (cita != null && cita.estado.esTerminal) {
        cuerpo = centro([
          Text(
            'Solo se pueden editar citas pendientes o confirmadas.',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge,
          ),
        ]);
      } else if (cita != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _precargar(cita);
        });
        cuerpo = const Center(child: CircularProgressIndicator());
      } else if (citaAsync.hasError) {
        cuerpo = centro([
          Text(
            'No pudimos cargar la cita. Intenta de nuevo.',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Reintentar',
            variant: AppButtonVariant.outline,
            expand: false,
            onPressed: () => ref.invalidate(citaProvider(widget.citaId!)),
          ),
        ]);
      } else {
        cuerpo = const Center(child: CircularProgressIndicator());
      }
      return Scaffold(
        appBar: const AppTopBar(title: 'Editar cita'),
        body: cuerpo,
      );
    }

    final semana = ref.watch(agendaSemanaProvider(lunesDeSemana(_dia)));
    final clienteId = _clienteId;
    final clienteAsync = clienteId == null
        ? null
        : ref.watch(clienteProvider(clienteId));
    final mascotasAsync = clienteId == null
        ? null
        : ref.watch(mascotasDeClienteProvider(clienteId));
    final cliente = clienteAsync?.asData?.value;
    final mascotas = mascotasAsync?.asData?.value;
    final seleccion = _seleccionEfectiva(mascotas);
    final hora = _hora(semana);
    final minutos = hora.minutos;

    final dirFalta = _domicilio && _dirCtrl.text.trim().isEmpty;
    final puedeGuardar =
        !_loading &&
        clienteId != null &&
        seleccion.isNotEmpty &&
        minutos != null &&
        !dirFalta;

    Widget titulo(String t) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(t, style: textTheme.labelLarge),
    );

    return Scaffold(
      appBar: AppTopBar(title: _editando ? 'Editar cita' : 'Nueva cita'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titulo('Cliente'),
            if (clienteId == null)
              ClienteSearchField(
                onSeleccionar: _seleccionarCliente,
                onNuevoClienteYMascota: _nuevoClienteYMascota,
              )
            else
              _ClienteElegido(
                cliente: cliente,
                error: clienteAsync?.hasError ?? false,
                cargando: clienteAsync?.isLoading ?? false,
                soloLectura: _editando,
                cambiar: clienteId == widget.clienteIdInicial,
                onQuitar: _quitarCliente,
              ),
            if (clienteId != null) ...[
              const SizedBox(height: AppSpacing.lg),
              titulo('Mascotas'),
              if (mascotasAsync!.hasError)
                Text(
                  'No pudimos cargar las mascotas. Intenta de nuevo.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.destructive,
                  ),
                )
              else if (mascotas == null)
                const Center(child: CircularProgressIndicator())
              else
                MascotaMultiSelect(
                  mascotas: mascotas,
                  seleccionadas: seleccion,
                  mostrarError: _quitoUltima,
                  onCambio: (id, marcada) => setState(() {
                    final nueva = {...seleccion};
                    marcada ? nueva.add(id) : nueva.remove(id);
                    _mascotasSel = nueva;
                    _quitoUltima = nueva.isEmpty;
                  }),
                  onAgregarMascota: () => _agregarMascota(clienteId),
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
            titulo('Motivo'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final m in motivosCita)
                  AppFilterChip(
                    label: m.label,
                    selected: _motivo == m.label,
                    onTap: () => setState(() {
                      _motivo = m.label;
                      _duracion = duracionPorDefecto(m.label);
                    }),
                  ),
              ],
            ),
            if (_motivo == 'Otro') ...[
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: '¿Cuál es el motivo?',
                controller: _otroCtrl,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            titulo('Duración'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final d in duracionesCita)
                  AppFilterChip(
                    label: duracionTexto(d),
                    selected: _duracion == d,
                    onTap: () => setState(() => _duracion = d),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            titulo('Cuándo'),
            InkWell(
              onTap: _elegirFecha,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        fechaLarga(_dia),
                        style: textTheme.bodyLarge,
                      ),
                    ),
                    const Icon(Icons.calendar_today_outlined),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TimeStepper(
              minutos: minutos,
              habilitado: minutos != null,
              ayuda: hora.ayuda,
              fin: minutos == null
                  ? null
                  : 'Termina a las ${TimeStepper.formato(minutos + _duracion)}',
              onCambio: (v) => setState(() => _minutosManual = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            titulo('Dónde'),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Expanded(
                    child: Text('A domicilio', style: textTheme.bodyLarge),
                  ),
                  Switch(
                    value: _domicilio,
                    onChanged: (v) => _toggleDomicilio(v, cliente),
                  ),
                ],
              ),
            ),
            if (_domicilio) ...[
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Dirección',
                controller: _dirCtrl,
                helperText: 'Solo para esta cita',
                errorText: dirFalta
                    ? 'Escribe la dirección para la visita a domicilio.'
                    : null,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: () =>
                  setState(() => _notasExpandidas = !_notasExpandidas),
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.touchTarget,
                ),
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Agregar más detalles',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    Icon(
                      _notasExpandidas
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (_notasExpandidas) ...[
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Notas',
                controller: _notasCtrl,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            if (_error != null) ...[
              Text(
                _error!,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.destructive,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppButton(
              label: _editando ? 'Guardar cambios' : 'Guardar cita',
              isLoading: _loading,
              onPressed: puedeGuardar ? () => _submit(seleccion, minutos) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClienteElegido extends StatelessWidget {
  const _ClienteElegido({
    required this.cliente,
    required this.error,
    required this.cargando,
    required this.cambiar,
    required this.onQuitar,
    this.soloLectura = false,
  });

  /// Edición de cita: el cliente queda fijo (conserva el historial ligado).
  final bool soloLectura;

  final Cliente? cliente;
  final bool error;
  final bool cargando;

  /// Abierta desde una ficha: se ofrece "Cambiar" en vez de la X.
  final bool cambiar;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = cliente;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: c != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.nombre,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        normalizarTelefono(c.telefono).formateado,
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  )
                : Text(
                    error
                        ? 'No pudimos cargar el cliente.'
                        : cargando
                        ? 'Cargando cliente…'
                        : '',
                    style: textTheme.bodyMedium,
                  ),
          ),
          if (soloLectura)
            const SizedBox.shrink()
          else if (cambiar)
            TextButton(onPressed: onQuitar, child: const Text('Cambiar'))
          else
            IconButton(
              tooltip: 'Quitar cliente',
              icon: const Icon(Icons.close),
              onPressed: onQuitar,
            ),
        ],
      ),
    );
  }
}
