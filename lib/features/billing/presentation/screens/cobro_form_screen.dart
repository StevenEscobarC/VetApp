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
import '../../../inventory/domain/entities/producto.dart';
import '../../../inventory/presentation/providers/inventario_providers.dart';
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
import '../widgets/producto_cobro_sheet.dart';
import '../widgets/servicio_chip.dart';
import '../widgets/tipo_cobro_toggle.dart';
import '../widgets/total_cobro_bar.dart';

/// Formulario de cuenta de cobro o cotización (UI-SPEC §3): nueva, editar
/// una cotización abierta, convertirla en cuenta de cobro (D-09) o emitir
/// una nueva desde una CC anulada (D-10). Todo el estado vive en
/// [borradorCobroProvider], incluida la clave de idempotencia que se crea al
/// abrir y se reutiliza en cada reintento (D-21). Solo se llega aquí después
/// de `asegurarEscritura`.
///
/// Tras un fallo sin conexión el servidor pudo haber confirmado: el borrador
/// queda bloqueado (líneas, cliente, mascota y tipo) y solo se ofrece
/// "Reintentar" o "Descartar" hasta que el servidor responda (CR-01). Así la
/// misma clave nunca viaja con otro contenido.
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
  String? _focoPrecio;
  String _anuncio = '';

  /// Productos que el servidor rechazó por archivados (IN002): sus pasos se
  /// deshabilitan hasta el próximo envío.
  final _noDisponibles = <String>{};

  /// Una clave por línea para llevar la vista a la primera línea inválida.
  final _clavesLinea = <String, GlobalKey>{};

  GlobalKey _claveLinea(String key) =>
      _clavesLinea.putIfAbsent(key, GlobalKey.new);

  /// Documento de origen ya copiado al borrador (editar, convertir, copiar).
  bool _origenCargado = false;
  bool _copiaProgramada = false;
  Cobro? _origen;

  /// La cotización ya no admite editar ni convertir (BC002 o una cotización
  /// que no está abierta): CTA deshabilitado y "Volver".
  bool _noUsable = false;
  bool _errorOrigen = false;

  /// El último envío falló sin red (CR-01): el contenido queda fijo hasta que
  /// un reintento obtenga respuesta del servidor.
  bool _pendienteReintento = false;

  /// Nada se edita mientras se envía o mientras hay un reintento pendiente.
  bool get _edicionBloqueada => _loading || _pendienteReintento;

  @override
  void initState() {
    super.initState();
    // El inventario puede llevar horas en caché si Inventario está montado en
    // otra rama: se relee al abrir para que las notas y avisos de stock usen
    // la cifra actual (WR-03). Fuera del build en curso.
    Future.microtask(() {
      if (mounted) ref.invalidate(productosProvider);
    });
  }

  PrefillCobro get _p => widget.prefill;
  BorradorCobroNotifier get _n => ref.read(borradorCobroProvider(_p).notifier);
  BorradorCobro get _b => ref.read(borradorCobroProvider(_p));

  bool get _editar => _p.modo == ModoFormCobro.editarCotizacion;
  bool get _convertir => _p.modo == ModoFormCobro.convertir;
  bool get _desdeOrigen =>
      _p.modo != ModoFormCobro.nuevo && _p.origenId != null;
  bool get _cargandoOrigen =>
      _desdeOrigen && !_origenCargado && !_noUsable && !_errorOrigen;

  String _titulo(TipoCobro tipo) {
    if (_editar) return 'Editar cotización';
    if (_convertir) {
      final o = _origen;
      return o == null ? 'Convertir cotización' : 'Convertir ${o.numeroTexto}';
    }
    return tipo == TipoCobro.cotizacion
        ? 'Nueva cotización'
        : 'Nueva cuenta de cobro';
  }

  String _cta(TipoCobro tipo) {
    if (_editar) return 'Guardar cambios';
    return tipo == TipoCobro.cotizacion
        ? 'Guardar cotización'
        : 'Emitir cuenta de cobro';
  }

  /// Editar y convertir solo valen sobre una cotización abierta; el servidor
  /// lo vuelve a exigir bajo bloqueo (BC002).
  bool _origenValido(Cobro o) =>
      _p.modo == ModoFormCobro.copiar || (o.esCotizacion && o.abierta);

  /// Observa el documento de origen hasta copiarlo una sola vez al borrador.
  /// Los productos solo se piden si el origen tiene líneas de producto.
  void _observarOrigen() {
    if (!_cargandoOrigen || _copiaProgramada) return;
    final async = ref.watch(cobroProvider(_p.origenId!));
    if (async.hasError && !async.hasValue) {
      _programar(() => _errorOrigen = true);
      return;
    }
    if (!async.hasValue) return;
    final origen = async.value;
    if (origen == null) {
      // Copiar sin origen: queda lo que trajo la ruta.
      _programar(
        () => _p.modo == ModoFormCobro.copiar
            ? _origenCargado = true
            : _noUsable = true,
      );
      return;
    }
    if (!_origenValido(origen)) {
      _programar(() => _noUsable = true);
      return;
    }
    var productos = const <Producto>[];
    var conInventario = true;
    if (origen.productoIds.isNotEmpty) {
      final p = ref.watch(productosProvider);
      // También espera la relectura de initState (WR-03).
      if (p.isLoading) return;
      productos = p.value ?? const [];
      // Sin inventario no se marca nada: el servidor decide al enviar.
      conInventario = p.hasValue;
    }
    final lista = productos;
    final marcar = conInventario;
    _programar(() {
      _n.cargarDesde(origen, productos: lista, marcarArchivados: marcar);
      _origen = origen;
      _origenCargado = true;
    });
  }

  /// Los cambios de estado salen del build en el siguiente cuadro.
  void _programar(VoidCallback cambio) {
    _copiaProgramada = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(cambio);
    });
  }

  void _volver() {
    setState(() => _descartado = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  String? _errorDescripcion(LineaBorrador l) =>
      _validar && l.tipo == TipoLinea.otro && l.descripcion.trim().isEmpty
      ? 'Escribe la descripción.'
      : null;

  String? _errorPrecio(LineaBorrador l) =>
      _validar && l.precioUnitarioCop == null
      ? 'Escribe el precio (puede ser 0).'
      : null;

  static String _mensajeStock(LineaBorrador l, int quedan) {
    if (quedan <= 0) return '${l.descripcion} está agotado.';
    final unidad = l.unidad?.etiqueta(quedan) ?? '';
    final verbo = quedan == 1 ? 'queda' : 'quedan';
    return 'Solo $verbo ${formatearMiles(quedan)} $unidad de ${l.descripcion}.';
  }

  /// Aviso local de existencias, solo en una cuenta de cobro (D-12). Las
  /// existencias locales pueden estar viejas, así que NO bloquea el envío: el
  /// servidor decide con IN001 y su respuesta marca la línea (WR-03).
  String? _avisoStockLocal(LineaBorrador l, TipoCobro tipo) {
    final stock = l.stock;
    if (tipo != TipoCobro.cuentaCobro ||
        l.tipo != TipoLinea.producto ||
        stock == null ||
        l.cantidad <= stock) {
      return null;
    }
    return _mensajeStock(l, stock);
  }

  bool _lineaInvalida(LineaBorrador l) =>
      _errorDescripcion(l) != null || _errorPrecio(l) != null;

  void _mostrarLinea(String key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _clavesLinea[key]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 250),
        );
      }
    });
  }

  Future<void> _agregarProducto() async {
    final esCc = _b.tipo == TipoCobro.cuentaCobro;
    final p = await showProductoCobroSheet(context, esCuentaCobro: esCc);
    if (p == null || !mounted) return;
    final nueva = !_b.lineas.any((l) => l.productoId == p.id);
    _n.agregarProducto(p);
    final l = _b.lineas.firstWhere((l) => l.productoId == p.id);
    setState(() {
      if (nueva && p.precioVentaCop == null) _focoPrecio = l.key;
      _anuncio = '${p.nombre} agregado. Total ${formatearCop(_b.totalCop)}.';
    });
  }

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
    final mala = b.lineas.where(_lineaInvalida).firstOrNull;
    if (mala != null) {
      _mostrarLinea(mala.key);
      return false;
    }
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
          AppButton(
            label: 'Revisar',
            variant: AppButtonVariant.text,
            expand: false,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            label: 'Emitir',
            expand: false,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// IN001 / IN002 con producto conocido: marca la línea exacta y refresca su
  /// nota de existencias. Devuelve `false` si no hay línea de ese producto.
  bool _marcarLineaStock(CobroFailure e) {
    final id = e.productoId;
    if (id == null) return false;
    final l = _b.lineas.where((l) => l.productoId == id).firstOrNull;
    if (l == null) return false;
    final quedan = e.quedan;
    final noDisponible = e.tipo == ErrorCobro.productoNoDisponible;
    final mensaje = noDisponible
        ? '${l.descripcion} ya no está disponible. Quítalo del cobro.'
        : quedan != null
        ? _mensajeStock(l, quedan)
        : e.message;
    _n.marcarErrorStock(id, quedan: quedan, mensaje: mensaje);
    if (noDisponible) _noDisponibles.add(id);
    _mostrarLinea(l.key);
    return true;
  }

  /// [lineaMarcada]: el rechazo de stock ya quedó en su línea (IN002 entonces
  /// no necesita banner).
  _Banner? _bannerPara(
    CobroFailure e,
    TipoCobro tipo, {
    bool lineaMarcada = false,
  }) => switch (e.tipo) {
    ErrorCobro.sinConexion => const _Banner(
      sinConexion: true,
      mensaje: 'Sin conexión, el cobro no se creó.',
      detalle: 'Tus datos siguen aquí. Inténtalo de nuevo cuando tengas señal.',
    ),
    ErrorCobro.stockInsuficiente => const _Banner(
      mensaje: 'Revisa las cantidades marcadas.',
    ),
    ErrorCobro.productoNoDisponible =>
      lineaMarcada ? null : _Banner(mensaje: e.message),
    ErrorCobro.visitaYaCobrada => _Banner(mensaje: e.message),
    _ => _Banner(
      mensaje: tipo == TipoCobro.cotizacion
          ? 'No pudimos guardar la cotización. Intenta de nuevo.'
          : 'No pudimos crear el cobro. Intenta de nuevo.',
    ),
  };

  /// Envía el borrador con SU clave: nunca se regenera tras un fallo, así un
  /// reintento después de una respuesta perdida no duplica (D-21, T-07-32).
  /// Un reintento tras "sin conexión" no vuelve a validar ni a preguntar: el
  /// contenido es el mismo que ya se confirmó (CR-01).
  Future<void> _emitir() async {
    if (_loading || _confirmando || _noUsable || _cargandoOrigen) return;
    final reintento = _pendienteReintento;
    if (!reintento && !_validarLocal()) return;
    if (_editar) return _guardarCambios();
    final b = _b;
    final esCc = b.tipo == TipoCobro.cuentaCobro;
    if (esCc && !reintento) {
      _confirmando = true;
      final ok = await _confirmarEmision(b);
      _confirmando = false;
      if (!ok || !mounted) return;
    }
    // Los rechazos de stock anteriores se limpian: el servidor vuelve a decidir
    // con el mismo borrador y la misma clave (D-12, D-21).
    _n.limpiarErroresStock();
    setState(() {
      _noDisponibles.clear();
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
      if (mounted) setState(() => _pendienteReintento = false);
      router.pushReplacement(rutaCobro(r.id));
      // La clave ya existía: el servidor devolvió el documento que creó antes
      // (respuesta perdida). No se anuncia como nuevo (CR-01).
      final texto = r.yaExistia
          ? (esCc
                ? 'Ya estaba emitida: $numero.'
                : 'Ya estaba guardada: $numero.')
          : (esCc
                ? 'Cuenta de cobro $numero emitida.'
                : 'Cotización $numero guardada.');
      messenger.showSnackBar(SnackBar(content: Text(texto)));
    } on CobroFailure catch (e) {
      // Sin red el servidor pudo confirmar: se bloquea el borrador. Cualquier
      // respuesta del servidor (rechazo incluido) resuelve el reintento.
      final sinRed = e.tipo == ErrorCobro.sinConexion;
      if (mounted) setState(() => _pendienteReintento = sinRed);
      // LP004: hoja del plan sobre el formulario; el borrador queda intacto.
      if (mounted && await manejarLimitePlan(context, ref, e)) return;
      if (!mounted) return;
      if (_marcarNoUsable(e)) return;
      final stock =
          e.tipo == ErrorCobro.stockInsuficiente ||
          e.tipo == ErrorCobro.productoNoDisponible;
      final marcada = stock && _marcarLineaStock(e);
      setState(() => _banner = _bannerPara(e, b.tipo, lineaMarcada: marcada));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// BC002 al convertir o editar: la cotización cambió en el servidor.
  bool _marcarNoUsable(CobroFailure e) {
    if (e.tipo != ErrorCobro.cotizacionNoDisponible ||
        !(_editar || _convertir)) {
      return false;
    }
    setState(() {
      _noUsable = true;
      _banner = null;
    });
    return true;
  }

  /// Editar una cotización abierta: sin diálogo y sin clave (el servidor
  /// reemplaza las líneas, repetirlo da lo mismo).
  Future<void> _guardarCambios() async {
    final b = _b;
    setState(() {
      _loading = true;
      _banner = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(cobrosActionsProvider)
          .editarCotizacion(
            id: _p.origenId!,
            clienteId: b.clienteId!,
            lineas: b.lineasNuevas(),
            mascotaId: b.mascotaId,
          );
      if (mounted) setState(() => _descartado = true);
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Cambios guardados.')),
      );
    } on CobroFailure catch (e) {
      if (mounted && await manejarLimitePlan(context, ref, e)) return;
      if (!mounted || _marcarNoUsable(e)) return;
      setState(() => _banner = _bannerPara(e, TipoCobro.cotizacion));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _alSalir(bool didPop, Object? _) async {
    if (didPop || _loading) return;
    await _descartar();
  }

  /// Pregunta y sale. Con un reintento pendiente avisa que el cobro pudo
  /// haberse creado (CR-01).
  Future<void> _descartar() async {
    if (_loading) return;
    final descartar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Descartar este cobro?'),
        content: Text(
          _pendienteReintento
              ? 'Se perderán las líneas que agregaste. Si alcanzó a crearse, '
                    'lo verás en Cobros.'
              : 'Se perderán las líneas que agregaste.',
        ),
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
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Agregar producto',
          variant: AppButtonVariant.outline,
          icon: Icons.inventory_2_outlined,
          onPressed: _agregarProducto,
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
        KeyedSubtree(key: _claveLinea(l.key), child: _linea(l, b.tipo)),
      ],
    ];
  }

  Widget _linea(LineaBorrador l, TipoCobro tipo) {
    final esProducto = l.tipo == TipoLinea.producto;
    final stock = l.stock;
    final unidad = l.unidad;
    return LineaCobroTile(
      key: ValueKey(l.key),
      linea: l,
      habilitado: !_edicionBloqueada,
      autofocusDescripcion: l.key == _focoOtro,
      autofocusPrecio: l.key == _focoPrecio,
      errorDescripcion: _errorDescripcion(l),
      errorPrecio: _errorPrecio(l),
      notaStock: esProducto && stock != null && unidad != null
          ? 'Quedan ${formatearMiles(stock)} ${unidad.etiqueta(stock)}'
          : null,
      pasosBloqueados: _noDisponibles.contains(l.productoId),
      ayudaPrecio: esProducto
          ? 'Este producto no tiene precio de venta. Escribe el precio.'
          : null,
      // El rechazo del servidor (IN001) es un error; el tope local, un aviso.
      errorStock: l.errorStock,
      avisoStock: l.errorStock == null ? _avisoStockLocal(l, tipo) : null,
      onCantidad: (n) => _n.cambiarCantidad(l.key, n),
      onPrecio: (v) => _n.cambiarPrecio(l.key, v),
      onDescripcion: (s) => _n.cambiarDescripcion(l.key, s),
      onQuitar: () => _n.quitar(l.key),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = ref.watch(borradorCobroProvider(_p));
    ref.listen(borradorCobroProvider(_p), (_, _) {
      if (_errorBarra != null) setState(() => _errorBarra = null);
    });
    _observarOrigen();
    final mostrarTipo =
        _p.modo == ModoFormCobro.nuevo || _p.modo == ModoFormCobro.copiar;
    final cargando = _cargandoOrigen;
    final bloqueado = cargando || _noUsable || _errorOrigen;
    final origen = _origen;

    final _Banner? banner = _noUsable
        ? const _Banner(
            mensaje: 'Esta cotización ya no se puede usar. Actualiza la lista.',
            volver: true,
          )
        : _errorOrigen
        ? const _Banner(
            mensaje: 'No pudimos cargar el cobro. Intenta de nuevo.',
            volver: true,
          )
        : _banner;

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
                  absorbing: _edicionBloqueada,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        liveRegion: true,
                        label: _anuncio,
                        child: const SizedBox.shrink(),
                      ),
                      if (_convertir && origen != null) ...[
                        Text(
                          'Desde la cotización ${origen.numeroTexto}. Revisa '
                          'los precios y cantidades antes de emitir.',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (mostrarTipo) ...[
                        TipoCobroToggle(
                          valor: b.tipo,
                          onChanged: _n.cambiarTipo,
                          etiquetaCot: 'Cotización',
                          etiquetaCc: 'Cuenta de cobro',
                          habilitado: !_edicionBloqueada,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (cargando)
                        const _EsqueletoOrigen(
                          key: ValueKey('esqueleto-origen'),
                        )
                      else ...[
                        _cliente(b),
                        ..._mascota(b),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _seccion('Agregar', [_servicios()]),
                      const SizedBox(height: AppSpacing.lg),
                      _seccion('Detalle', _lineas(b)),
                    ],
                  ),
                ),
              ),
            ),
            if (banner != null)
              _BannerCobro(
                banner: banner,
                onVolver: _volver,
                onDescartar: _pendienteReintento && !_loading
                    ? _descartar
                    : null,
              ),
            TotalCobroBar(
              totalCop: b.totalCop,
              etiquetaCta: _pendienteReintento ? 'Reintentar' : _cta(b.tipo),
              ayuda:
                  b.tipo == TipoCobro.cuentaCobro &&
                      b.lineas.any((l) => l.tipo == TipoLinea.producto)
                  ? 'Al emitirla se descuentan los productos del inventario.'
                  : null,
              habilitado:
                  !bloqueado && b.clienteId != null && b.lineas.isNotEmpty,
              onTapDeshabilitado: bloqueado ? null : _avisarFaltante,
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
    this.volver = false,
  });

  final String mensaje;
  final String? detalle;
  final bool sinConexion;

  /// Agrega el `TextButton` "Volver" (cotización ya no usable).
  final bool volver;
}

class _BannerCobro extends StatelessWidget {
  const _BannerCobro({
    required this.banner,
    required this.onVolver,
    this.onDescartar,
  });

  final _Banner banner;
  final VoidCallback onVolver;

  /// "Descartar" junto a un reintento pendiente (CR-01).
  final VoidCallback? onDescartar;

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
                    if (banner.volver)
                      TextButton(
                        onPressed: onVolver,
                        child: const Text('Volver'),
                      ),
                    if (onDescartar != null)
                      TextButton(
                        onPressed: onDescartar,
                        child: const Text('Descartar'),
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

/// Filas de cliente y mascota mientras llega el documento de origen.
class _EsqueletoOrigen extends StatelessWidget {
  const _EsqueletoOrigen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget fila() => Container(
      height: AppSpacing.touchTarget,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
    );
    return Semantics(
      label: 'Cargando',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          fila(),
          const SizedBox(height: AppSpacing.lg),
          fila(),
        ],
      ),
    );
  }
}
