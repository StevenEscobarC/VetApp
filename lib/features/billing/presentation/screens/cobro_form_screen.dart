import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/chips/app_filter_chip.dart';
import '../../../clients/domain/entities/cliente.dart';
import '../../../clients/presentation/providers/clientes_providers.dart';
import '../../../patients/presentation/providers/mascotas_providers.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../domain/cobro_failure.dart';
import '../../domain/entities/cobro.dart';
import '../../domain/entities/cobro_item.dart';
import '../../domain/entities/servicio.dart';
import '../../domain/numeracion.dart';
import '../cobros_rutas.dart';
import '../providers/borrador_cobro_provider.dart';
import '../providers/cobros_providers.dart';
import '../widgets/elegir_cliente_sheet.dart';
import '../widgets/linea_cobro_tile.dart';
import '../widgets/servicio_chip.dart';
import '../widgets/tipo_cobro_toggle.dart';
import '../widgets/total_cobro_bar.dart';

/// Formulario de cuenta de cobro o cotización nueva (UI-SPEC §3). Todo el
/// estado vive en [borradorCobroProvider], incluida la clave de
/// idempotencia que se crea al abrir y se reutiliza en cada reintento
/// (D-21). Solo se llega aquí después de `asegurarEscritura`.
class CobroFormScreen extends ConsumerStatefulWidget {
  const CobroFormScreen({super.key, required this.prefill});

  final PrefillCobro prefill;

  @override
  ConsumerState<CobroFormScreen> createState() => _CobroFormScreenState();
}

class _CobroFormScreenState extends ConsumerState<CobroFormScreen> {
  bool _loading = false;
  bool _descartado = false;

  /// Diálogo de emisión abierto: ignora un segundo toque al CTA.
  bool _confirmando = false;
  _Banner? _banner;
  bool _validar = false;
  String? _errorBarra;
  Cliente? _clienteElegido;
  String? _focoOtro;
  String _anuncio = '';

  PrefillCobro get _p => widget.prefill;
  BorradorCobroNotifier get _n => ref.read(borradorCobroProvider(_p).notifier);
  BorradorCobro get _b => ref.read(borradorCobroProvider(_p));

  String _titulo(TipoCobro tipo) => tipo == TipoCobro.cotizacion
      ? 'Nueva cotización'
      : 'Nueva cuenta de cobro';

  String _cta(TipoCobro tipo) => tipo == TipoCobro.cotizacion
      ? 'Guardar cotización'
      : 'Emitir cuenta de cobro';

  String? _errorDescripcion(LineaBorrador l) =>
      _validar && l.tipo == TipoLinea.otro && l.descripcion.trim().isEmpty
      ? 'Escribe la descripción.'
      : null;

  String? _errorPrecio(LineaBorrador l) =>
      _validar && l.precioUnitarioCop == null
      ? 'Escribe el precio (puede ser 0).'
      : null;

  Future<void> _elegirCliente() async {
    final c = await mostrarElegirClienteSheet(context);
    if (c == null || !mounted) return;
    setState(() => _clienteElegido = c);
    _n.elegirCliente(c.id);
  }

  void _agregarServicio(Servicio s) {
    _n.agregarServicio(s);
    setState(
      () => _anuncio =
          '${s.nombre} agregada. Total ${formatearCop(_b.totalCop)}.',
    );
  }

  void _agregarOtro() {
    _n.agregarOtro();
    setState(() => _focoOtro = _b.lineas.last.key);
  }

  void _avisarFaltante() {
    setState(
      () => _errorBarra = _b.clienteId == null
          ? 'Elige el cliente.'
          : 'Agrega al menos un servicio o producto.',
    );
  }

  /// Validaciones locales antes de enviar; marca las líneas y la barra.
  bool _validarLocal() {
    final b = _b;
    setState(() {
      _validar = true;
      _errorBarra = null;
    });
    if (b.clienteId == null || b.lineas.isEmpty) {
      _avisarFaltante();
      return false;
    }
    final lineasMal = b.lineas.any(
      (l) => _errorDescripcion(l) != null || _errorPrecio(l) != null,
    );
    if (lineasMal) return false;
    if (b.totalCop <= 0) {
      setState(() => _errorBarra = 'El total debe ser mayor que \$ 0.');
      return false;
    }
    if (b.totalCop > kTotalMaximoCop) {
      setState(() => _errorBarra = 'El total es demasiado alto.');
      return false;
    }
    return true;
  }

  String _nombreCliente(String id) {
    final elegido = _clienteElegido;
    if (elegido != null && elegido.id == id) return elegido.nombre;
    return ref.read(clienteProvider(id)).value?.nombre ?? 'el cliente';
  }

  Future<bool> _confirmarEmision(BorradorCobro b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Emitir la cuenta de cobro?'),
        content: Text(
          'Total ${formatearCop(b.totalCop)} para '
          '${_nombreCliente(b.clienteId!)}. Después no se puede editar: si '
          'hay un error, la anulas y emites otra.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Revisar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(
                AppSpacing.touchTarget,
                AppSpacing.touchTarget,
              ),
            ),
            child: const Text('Emitir'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  _Banner _bannerPara(CobroFailure e, TipoCobro tipo) => switch (e.tipo) {
    ErrorCobro.sinConexion => const _Banner(
      sinConexion: true,
      mensaje: 'Sin conexión, el cobro no se creó.',
      detalle: 'Tus datos siguen aquí. Inténtalo de nuevo cuando tengas señal.',
    ),
    ErrorCobro.stockInsuficiente => const _Banner(
      mensaje: 'Revisa las cantidades marcadas.',
    ),
    ErrorCobro.visitaYaCobrada => _Banner(mensaje: e.message),
    _ => _Banner(
      mensaje: tipo == TipoCobro.cotizacion
          ? 'No pudimos guardar la cotización. Intenta de nuevo.'
          : 'No pudimos crear el cobro. Intenta de nuevo.',
    ),
  };

  /// Envía el borrador con SU clave: nunca se regenera tras un fallo, así un
  /// reintento después de una respuesta perdida no duplica (D-21, T-07-32).
  Future<void> _emitir() async {
    if (_loading || _confirmando) return;
    if (!_validarLocal()) return;
    final b = _b;
    final esCc = b.tipo == TipoCobro.cuentaCobro;
    if (esCc) {
      _confirmando = true;
      final ok = await _confirmarEmision(b);
      _confirmando = false;
      if (!ok || !mounted) return;
    }
    setState(() {
      _loading = true;
      _banner = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final acciones = ref.read(cobrosActionsProvider);
    try {
      final r = esCc
          ? await acciones.emitirCuentaCobro(
              clave: b.clave,
              clienteId: b.clienteId!,
              lineas: b.lineasNuevas(),
              mascotaId: b.mascotaId,
              citaId: b.citaId,
              consultaId: b.consultaId,
              cotizacionId: b.cotizacionId,
            )
          : await acciones.guardarCotizacion(
              clave: b.clave,
              clienteId: b.clienteId!,
              lineas: b.lineasNuevas(),
              mascotaId: b.mascotaId,
            );
      final numero = formatearNumeroCobro(b.tipo, r.numero);
      router.pushReplacement(rutaCobro(r.id));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            esCc
                ? 'Cuenta de cobro $numero emitida.'
                : 'Cotización $numero guardada.',
          ),
        ),
      );
    } on CobroFailure catch (e) {
      // LP004: hoja del plan sobre el formulario; el borrador queda intacto.
      if (mounted && await manejarLimitePlan(context, ref, e)) return;
      if (mounted) setState(() => _banner = _bannerPara(e, b.tipo));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _alSalir(bool didPop, Object? _) async {
    if (didPop || _loading) return;
    final descartar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Descartar este cobro?'),
        content: const Text('Se perderán las líneas que agregaste.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Seguir editando'),
          ),
          AppButton(
            label: 'Descartar',
            variant: AppButtonVariant.destructive,
            expand: false,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (descartar != true || !mounted) return;
    setState(() => _descartado = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Widget _seccion(String titulo, List<Widget> hijos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...hijos,
      ],
    );
  }

  Widget _filaSoloLectura({
    required String etiqueta,
    required String valor,
    Widget? accion,
  }) {
    final t = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: t.labelLarge?.copyWith(color: AppColors.textMuted),
                ),
                Text(valor, style: t.bodyLarge),
              ],
            ),
          ),
          ?accion,
        ],
      ),
    );
  }

  Widget _cliente(BorradorCobro b) {
    final t = Theme.of(context).textTheme;
    final id = b.clienteId;
    if (id == null) {
      return InkWell(
        onTap: _elegirCliente,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cliente', style: t.labelLarge),
                    Text(
                      'Elige el cliente',
                      style: t.bodyLarge?.copyWith(
                        color: AppColors.placeholder,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      );
    }
    final elegido = _clienteElegido;
    final nombre = elegido != null && elegido.id == id
        ? elegido.nombre
        : ref.watch(clienteProvider(id)).value?.nombre ?? '';
    return _filaSoloLectura(
      etiqueta: 'Cliente',
      valor: nombre,
      accion: b.vinculado
          ? null
          : TextButton(onPressed: _elegirCliente, child: const Text('Cambiar')),
    );
  }

  List<Widget> _mascota(BorradorCobro b) {
    final id = b.clienteId;
    if (id == null) return const [];
    final mascotas = ref.watch(mascotasDeClienteProvider(id)).value ?? [];
    if (b.vinculado && b.mascotaId != null) {
      final m = mascotas.where((m) => m.id == b.mascotaId).firstOrNull;
      if (m == null) return const [];
      return [
        const SizedBox(height: AppSpacing.lg),
        _filaSoloLectura(etiqueta: 'Mascota', valor: m.nombre),
      ];
    }
    if (mascotas.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.lg),
      Text('Mascota (opcional)', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final m in mascotas)
            Semantics(
              selected: b.mascotaId == m.id,
              child: AppFilterChip(
                label: m.nombre,
                selected: b.mascotaId == m.id,
                onTap: () =>
                    _n.elegirMascota(b.mascotaId == m.id ? null : m.id),
              ),
            ),
        ],
      ),
    ];
  }

  Widget _servicios() {
    final t = Theme.of(context).textTheme;
    final servicios = ref.watch(serviciosProvider);
    final admin = ref.watch(puedeAdministrarServiciosProvider);
    final lista = [
      ...?servicios.value,
    ]..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    final otro = ServicioChip(nombre: 'Otro', onTap: _agregarOtro);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Servicios', style: t.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        if (servicios.isLoading && !servicios.hasValue)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: LinearProgressIndicator(),
          )
        else if (servicios.hasError && !servicios.hasValue)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'No pudimos cargar los servicios.',
              style: t.labelLarge?.copyWith(color: AppColors.textMuted),
            ),
          )
        else if (lista.isEmpty) ...[
          Text(
            'Aún no hay servicios guardados.',
            style: t.labelLarge?.copyWith(color: AppColors.textMuted),
          ),
          if (admin)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () async {
                  await context.push(kRutaServicios);
                  if (mounted) ref.invalidate(serviciosProvider);
                },
                child: const Text('Agregar servicios'),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final s in lista)
              ServicioChip(
                nombre: s.nombre,
                precio: formatearCop(s.precioCop),
                onTap: () => _agregarServicio(s),
              ),
            otro,
          ],
        ),
      ],
    );
  }

  List<Widget> _lineas(BorradorCobro b) {
    if (b.lineas.isEmpty) {
      return [
        Text(
          'Agrega al menos un servicio o producto.',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
        ),
      ];
    }
    return [
      for (final (i, l) in b.lineas.indexed) ...[
        if (i > 0) const SizedBox(height: AppSpacing.sm),
        LineaCobroTile(
          key: ValueKey(l.key),
          linea: l,
          habilitado: !_loading,
          autofocusDescripcion: l.key == _focoOtro,
          errorDescripcion: _errorDescripcion(l),
          errorPrecio: _errorPrecio(l),
          errorStock: l.errorStock,
          onCantidad: (n) => _n.cambiarCantidad(l.key, n),
          onPrecio: (v) => _n.cambiarPrecio(l.key, v),
          onDescripcion: (s) => _n.cambiarDescripcion(l.key, s),
          onQuitar: () => _n.quitar(l.key),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final b = ref.watch(borradorCobroProvider(_p));
    ref.listen(borradorCobroProvider(_p), (_, _) {
      if (_errorBarra != null) setState(() => _errorBarra = null);
    });
    final mostrarTipo =
        _p.modo == ModoFormCobro.nuevo || _p.modo == ModoFormCobro.copiar;

    final banner = _banner;

    return PopScope(
      canPop: _descartado || (!b.sucio && !_loading),
      onPopInvokedWithResult: _alSalir,
      child: Scaffold(
        appBar: AppTopBar(title: _titulo(b.tipo)),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AbsorbPointer(
                  absorbing: _loading,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        liveRegion: true,
                        label: _anuncio,
                        child: const SizedBox.shrink(),
                      ),
                      if (mostrarTipo) ...[
                        TipoCobroToggle(
                          valor: b.tipo,
                          onChanged: _n.cambiarTipo,
                          etiquetaCot: 'Cotización',
                          etiquetaCc: 'Cuenta de cobro',
                          habilitado: !_loading,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      _cliente(b),
                      ..._mascota(b),
                      const SizedBox(height: AppSpacing.lg),
                      _seccion('Agregar', [_servicios()]),
                      const SizedBox(height: AppSpacing.lg),
                      _seccion('Detalle', _lineas(b)),
                    ],
                  ),
                ),
              ),
            ),
            if (banner != null) _BannerCobro(banner: banner),
            TotalCobroBar(
              totalCop: b.totalCop,
              etiquetaCta: _cta(b.tipo),
              habilitado: b.clienteId != null && b.lineas.isNotEmpty,
              onTapDeshabilitado: _avisarFaltante,
              onPressed: _emitir,
              isLoading: _loading,
              error: _errorBarra,
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallo del último envío. [sinConexion] usa `warningBg` y `wifi_off`; los
/// rechazos usan `surface` con borde `destructive` (UI-SPEC §3 Failures).
class _Banner {
  const _Banner({
    required this.mensaje,
    this.detalle,
    this.sinConexion = false,
  });

  final String mensaje;
  final String? detalle;
  final bool sinConexion;
}

class _BannerCobro extends StatelessWidget {
  const _BannerCobro({required this.banner});

  final _Banner banner;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final detalle = banner.detalle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: banner.sinConexion ? AppColors.warningBg : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: banner.sinConexion
                ? null
                : Border.all(color: AppColors.destructive),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                banner.sinConexion ? Icons.wifi_off : Icons.error_outline,
                color: banner.sinConexion
                    ? AppColors.primaryText
                    : AppColors.destructive,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(banner.mensaje, style: t.bodyLarge),
                    if (detalle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        detalle,
                        style: t.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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
