import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../inventory/domain/entities/producto.dart';
import '../../domain/clave_idempotencia.dart';
import '../../domain/entities/cobro.dart';
import '../../domain/entities/cobro_item.dart';
import '../../domain/entities/servicio.dart';

/// Cómo se abrió el formulario de cobro. 07-15 implementa editar, convertir
/// y copiar sobre este mismo borrador.
enum ModoFormCobro { nuevo, editarCotizacion, convertir, copiar }

/// Datos con los que se abre el formulario (desde la ruta). Es el argumento
/// de la familia: un mismo prefill reutiliza el mismo borrador mientras la
/// pantalla viva.
typedef PrefillCobro = ({
  ModoFormCobro modo,
  TipoCobro tipo,
  String? clienteId,
  String? mascotaId,
  String? citaId,
  String? consultaId,
  String? origenId,
});

const Object _sinCambio = Object();

/// Línea del borrador, todavía editable. [precioUnitarioCop] `null` es el
/// campo vacío (se envía como 0 solo si la validación lo permite).
/// [precioBaseCop] es la tarifa del servicio o producto al agregarla: la
/// línea puede cambiar su precio, la tarifa nunca cambia desde aquí (D-07).
class LineaBorrador {
  const LineaBorrador({
    required this.key,
    required this.tipo,
    required this.descripcion,
    this.cantidad = 1,
    this.precioUnitarioCop,
    this.precioBaseCop,
    this.servicioId,
    this.productoId,
    this.stock,
    this.unidad,
    this.errorStock,
  });

  /// Identificador local, estable mientras la línea exista.
  final String key;
  final TipoLinea tipo;
  final String descripcion;
  final int cantidad;
  final int? precioUnitarioCop;
  final int? precioBaseCop;
  final String? servicioId;
  final String? productoId;
  final int? stock;
  final Unidad? unidad;
  final String? errorStock;

  int get subtotalCop => cantidad * (precioUnitarioCop ?? 0);

  LineaBorrador copyWith({
    String? descripcion,
    int? cantidad,
    Object? precioUnitarioCop = _sinCambio,
    Object? stock = _sinCambio,
    Object? errorStock = _sinCambio,
  }) => LineaBorrador(
    key: key,
    tipo: tipo,
    descripcion: descripcion ?? this.descripcion,
    cantidad: cantidad ?? this.cantidad,
    precioUnitarioCop: identical(precioUnitarioCop, _sinCambio)
        ? this.precioUnitarioCop
        : precioUnitarioCop as int?,
    precioBaseCop: precioBaseCop,
    servicioId: servicioId,
    productoId: productoId,
    stock: identical(stock, _sinCambio) ? this.stock : stock as int?,
    unidad: unidad,
    errorStock: identical(errorStock, _sinCambio)
        ? this.errorStock
        : errorStock as String?,
  );
}

/// Borrador de una cuenta de cobro o cotización. [clave] es la clave de
/// idempotencia (D-21): se crea una vez al abrir y viaja igual en cada
/// reintento. [clienteInicialId] es el cliente del prefill, para saber si el
/// usuario lo cambió ([sucio]).
class BorradorCobro {
  const BorradorCobro({
    required this.clave,
    required this.tipo,
    this.clienteId,
    this.mascotaId,
    this.citaId,
    this.consultaId,
    this.cotizacionId,
    this.lineas = const [],
    this.clienteInicialId,
  });

  final String clave;
  final TipoCobro tipo;
  final String? clienteId;
  final String? mascotaId;
  final String? citaId;
  final String? consultaId;
  final String? cotizacionId;
  final List<LineaBorrador> lineas;
  final String? clienteInicialId;

  /// Vinculado a una cita o consulta: el vínculo fija cliente y mascota.
  bool get vinculado => citaId != null || consultaId != null;

  /// Vista previa; el servidor recalcula el total (T-07-33).
  int get totalCop => lineas.fold(0, (s, l) => s + l.subtotalCop);

  bool get sucio => lineas.isNotEmpty || clienteId != clienteInicialId;

  List<LineaCobroNueva> lineasNuevas() => [
    for (final l in lineas)
      LineaCobroNueva(
        tipo: l.tipo,
        descripcion: l.descripcion.trim(),
        cantidad: l.cantidad,
        precioUnitarioCop: l.precioUnitarioCop ?? 0,
        servicioId: l.servicioId,
        productoId: l.productoId,
      ),
  ];

  BorradorCobro copyWith({
    TipoCobro? tipo,
    Object? clienteId = _sinCambio,
    Object? mascotaId = _sinCambio,
    List<LineaBorrador>? lineas,
  }) => BorradorCobro(
    clave: clave,
    tipo: tipo ?? this.tipo,
    clienteId: identical(clienteId, _sinCambio)
        ? this.clienteId
        : clienteId as String?,
    mascotaId: identical(mascotaId, _sinCambio)
        ? this.mascotaId
        : mascotaId as String?,
    citaId: citaId,
    consultaId: consultaId,
    cotizacionId: cotizacionId,
    lineas: lineas ?? this.lineas,
    clienteInicialId: clienteInicialId,
  );
}

/// Generador de la clave de idempotencia; costura para tests.
final claveIdempotenciaProvider = Provider<String Function()>(
  (ref) => generarClaveIdempotencia,
);

final borradorCobroProvider = NotifierProvider.autoDispose
    .family<BorradorCobroNotifier, BorradorCobro, PrefillCobro>(
      BorradorCobroNotifier.new,
    );

/// Estado del formulario de cobro. Vive mientras la pantalla lo observe;
/// al liberarse, el siguiente borrador trae otra clave.
class BorradorCobroNotifier extends Notifier<BorradorCobro> {
  BorradorCobroNotifier(this.prefill);

  final PrefillCobro prefill;
  int _siguiente = 0;

  @override
  BorradorCobro build() {
    final clave = ref.read(claveIdempotenciaProvider)();
    return BorradorCobro(
      clave: clave,
      tipo: prefill.tipo,
      clienteId: prefill.clienteId,
      mascotaId: prefill.mascotaId,
      citaId: prefill.citaId,
      consultaId: prefill.consultaId,
      cotizacionId: prefill.modo == ModoFormCobro.convertir
          ? prefill.origenId
          : null,
      clienteInicialId: prefill.clienteId,
    );
  }

  String _nuevaKey() => 'l${++_siguiente}';

  void _lineas(List<LineaBorrador> lineas) =>
      state = state.copyWith(lineas: lineas);

  void _editar(String key, LineaBorrador Function(LineaBorrador) f) =>
      _lineas([for (final l in state.lineas) l.key == key ? f(l) : l]);

  void cambiarTipo(TipoCobro tipo) => state = state.copyWith(tipo: tipo);

  /// Sin vínculo, cambiar de cliente borra la mascota (era del anterior).
  void elegirCliente(String id) {
    state = state.vinculado
        ? state.copyWith(clienteId: id)
        : state.copyWith(clienteId: id, mascotaId: null);
  }

  void elegirMascota(String? id) => state = state.copyWith(mascotaId: id);

  /// El mismo servicio otra vez suma 1 a su línea en vez de duplicarla.
  void agregarServicio(Servicio s) {
    final i = state.lineas.indexWhere((l) => l.servicioId == s.id);
    if (i >= 0) {
      final l = state.lineas[i];
      _editar(l.key, (l) => l.copyWith(cantidad: l.cantidad + 1));
      return;
    }
    _lineas([
      ...state.lineas,
      LineaBorrador(
        key: _nuevaKey(),
        tipo: TipoLinea.servicio,
        descripcion: s.nombre,
        precioUnitarioCop: s.precioCop,
        precioBaseCop: s.precioCop,
        servicioId: s.id,
      ),
    ]);
  }

  void agregarOtro() => _lineas([
    ...state.lineas,
    LineaBorrador(key: _nuevaKey(), tipo: TipoLinea.otro, descripcion: ''),
  ]);

  void cambiarCantidad(String key, int n) =>
      _editar(key, (l) => l.copyWith(cantidad: n < 1 ? 1 : n));

  void cambiarPrecio(String key, int? cop) =>
      _editar(key, (l) => l.copyWith(precioUnitarioCop: cop));

  void cambiarDescripcion(String key, String texto) =>
      _editar(key, (l) => l.copyWith(descripcion: texto));

  void quitar(String key) => _lineas([
    for (final l in state.lineas)
      if (l.key != key) l,
  ]);
}
