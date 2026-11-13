import '../numeracion.dart';
import 'cobro_item.dart';

/// Clase de documento (D-01): la cotización no cobra ni toca el inventario;
/// la cuenta de cobro sí.
enum TipoCobro {
  cotizacion('cotizacion', 'Cotización', 'COT'),
  cuentaCobro('cuenta_cobro', 'Cuenta de cobro', 'CC');

  const TipoCobro(this.bd, this.etiqueta, this.prefijo);

  final String bd;
  final String etiqueta;

  /// Prefijo del número visible ('CC-0012', 'COT-0004').
  final String prefijo;

  static TipoCobro desdeBd(String v) => TipoCobro.values.firstWhere(
    (t) => t.bd == v,
    orElse: () => TipoCobro.cuentaCobro,
  );
}

/// Estados válidos: cotización abierta/convertida/anulada; cuenta de cobro
/// pendiente/pagada/anulada. El servidor impone la combinación.
enum EstadoCobro {
  abierta,
  convertida,
  pendiente,
  pagada,
  anulada;

  String get bd => name;

  String get etiqueta => switch (this) {
    EstadoCobro.abierta => 'Abierta',
    EstadoCobro.convertida => 'Convertida',
    EstadoCobro.pendiente => 'Pendiente',
    EstadoCobro.pagada => 'Pagada',
    EstadoCobro.anulada => 'Anulada',
  };

  static EstadoCobro desdeBd(String v) => EstadoCobro.values.firstWhere(
    (e) => e.name == v,
    orElse: () => EstadoCobro.pendiente,
  );
}

/// Métodos de pago en el orden de los chips (D-15).
enum MetodoPago {
  efectivo('efectivo', 'Efectivo'),
  nequi('nequi', 'Nequi'),
  daviplata('daviplata', 'Daviplata'),
  transferencia('transferencia', 'Transferencia'),
  tarjeta('tarjeta', 'Tarjeta'),
  otro('otro', 'Otro');

  const MetodoPago(this.bd, this.etiqueta);

  final String bd;
  final String etiqueta;

  static MetodoPago desdeBd(String v) => MetodoPago.values.firstWhere(
    (m) => m.bd == v,
    orElse: () => MetodoPago.otro,
  );
}

/// Cotización o cuenta de cobro de la clínica.
///
/// El servidor es dueño del número y del total: el cliente nunca los calcula
/// ni los envía. Una cuenta de cobro emitida es solo-append (D-10): no se
/// edita, solo se marca pagada o se anula con motivo, y anular devuelve el
/// stock. Las líneas copian descripción y precio al emitir (D-14) para que el
/// documento no cambie si luego cambia el catálogo. Todo en pesos enteros.
class Cobro {
  const Cobro({
    required this.id,
    required this.tipo,
    required this.numero,
    required this.estado,
    required this.fecha,
    this.clienteId,
    required this.clienteNombre,
    this.clienteCedula,
    this.mascotaId,
    this.mascotaNombre,
    this.citaId,
    this.consultaId,
    required this.items,
    required this.totalCop,
    this.metodoPago,
    this.pagadaEl,
    this.validaHasta,
    this.cotizacionOrigenId,
    this.cotizacionOrigenNumero,
    this.convertidaEnId,
    this.convertidaEnNumero,
    required this.creadoPor,
    this.autorNombre,
    this.anuladaAt,
    this.anuladaPorNombre,
    this.motivoAnulacion,
  });

  final String id;
  final TipoCobro tipo;
  final int numero;
  final EstadoCobro estado;
  final DateTime fecha;
  final String? clienteId;

  /// Copia del nombre al emitir: sobrevive si el cliente se borra.
  final String clienteNombre;
  final String? clienteCedula;
  final String? mascotaId;
  final String? mascotaNombre;
  final String? citaId;
  final String? consultaId;
  final List<CobroItem> items;
  final int totalCop;
  final MetodoPago? metodoPago;
  final DateTime? pagadaEl;
  final DateTime? validaHasta;
  final String? cotizacionOrigenId;
  final int? cotizacionOrigenNumero;
  final String? convertidaEnId;
  final int? convertidaEnNumero;
  final String creadoPor;
  final String? autorNombre;
  final DateTime? anuladaAt;
  final String? anuladaPorNombre;
  final String? motivoAnulacion;

  String get numeroTexto => formatearNumeroCobro(tipo, numero);

  bool get esCotizacion => tipo == TipoCobro.cotizacion;
  bool get esCuentaCobro => tipo == TipoCobro.cuentaCobro;
  bool get anulada => estado == EstadoCobro.anulada;
  bool get pagada => estado == EstadoCobro.pagada;
  bool get pendiente => estado == EstadoCobro.pendiente;
  bool get abierta => estado == EstadoCobro.abierta;
  bool get convertida => estado == EstadoCobro.convertida;

  /// Cotización abierta cuya validez ya pasó, en días calendario. Solo se
  /// muestra (D-23): una cotización vencida se puede convertir igual.
  /// [hoyBogota] viene del reloj inyectado, nunca del reloj del sistema.
  bool vencida(DateTime hoyBogota) {
    final v = validaHasta;
    if (!esCotizacion || !abierta || v == null) return false;
    final limite = DateTime.utc(v.year, v.month, v.day);
    final hoy = DateTime.utc(hoyBogota.year, hoyBogota.month, hoyBogota.day);
    return limite.isBefore(hoy);
  }

  /// Primera descripción y '+n' si hay más líneas (meta de la lista).
  String get resumenLineas {
    if (items.isEmpty) return '';
    final primera = items.first.descripcion;
    return items.length == 1 ? primera : '$primera +${items.length - 1}';
  }

  /// Productos del documento, para refrescar su inventario tras mutar.
  Set<String> get productoIds => {
    for (final i in items)
      if (i.tipo == TipoLinea.producto && i.productoId != null) i.productoId!,
  };

  Cobro copyWith({
    EstadoCobro? estado,
    String? clienteId,
    String? clienteNombre,
    String? clienteCedula,
    String? mascotaId,
    String? mascotaNombre,
    List<CobroItem>? items,
    int? totalCop,
    MetodoPago? metodoPago,
    DateTime? pagadaEl,
    DateTime? validaHasta,
    String? convertidaEnId,
    int? convertidaEnNumero,
    String? autorNombre,
    DateTime? anuladaAt,
    String? anuladaPorNombre,
    String? motivoAnulacion,
  }) => Cobro(
    id: id,
    tipo: tipo,
    numero: numero,
    estado: estado ?? this.estado,
    fecha: fecha,
    clienteId: clienteId ?? this.clienteId,
    clienteNombre: clienteNombre ?? this.clienteNombre,
    clienteCedula: clienteCedula ?? this.clienteCedula,
    mascotaId: mascotaId ?? this.mascotaId,
    mascotaNombre: mascotaNombre ?? this.mascotaNombre,
    citaId: citaId,
    consultaId: consultaId,
    items: items ?? this.items,
    totalCop: totalCop ?? this.totalCop,
    metodoPago: metodoPago ?? this.metodoPago,
    pagadaEl: pagadaEl ?? this.pagadaEl,
    validaHasta: validaHasta ?? this.validaHasta,
    cotizacionOrigenId: cotizacionOrigenId,
    cotizacionOrigenNumero: cotizacionOrigenNumero,
    convertidaEnId: convertidaEnId ?? this.convertidaEnId,
    convertidaEnNumero: convertidaEnNumero ?? this.convertidaEnNumero,
    creadoPor: creadoPor,
    autorNombre: autorNombre ?? this.autorNombre,
    anuladaAt: anuladaAt ?? this.anuladaAt,
    anuladaPorNombre: anuladaPorNombre ?? this.anuladaPorNombre,
    motivoAnulacion: motivoAnulacion ?? this.motivoAnulacion,
  );
}

/// Cifras de la tarjeta de Inicio y del encabezado de la lista (D-17).
class ResumenCobros {
  const ResumenCobros({
    this.cobradoMes = 0,
    this.porCobrar = 0,
    this.pendientes = 0,
  });

  final int cobradoMes;
  final int porCobrar;
  final int pendientes;
}

/// Cuenta de cobro activa ligada a una cita o consulta (siempre CC).
class CobroVinculado {
  const CobroVinculado({
    required this.id,
    required this.numero,
    required this.estado,
  });

  final String id;
  final int numero;
  final EstadoCobro estado;

  String get numeroTexto => formatearNumeroCobro(TipoCobro.cuentaCobro, numero);
}

/// Encabezado de la clínica para el PDF. [logoPath] llega `null` si el plan
/// no permite logo.
class ClinicaCobroPdf {
  const ClinicaCobroPdf({
    required this.nombre,
    this.ciudad,
    this.direccion,
    this.telefono,
    this.nit,
    this.logoPath,
  });

  final String nombre;
  final String? ciudad;
  final String? direccion;
  final String? telefono;
  final String? nit;
  final String? logoPath;
}

/// Respuesta de crear: [yaExistia] es `true` cuando la clave de idempotencia
/// ya se había usado (reintento seguro).
typedef ResultadoCobro = ({String id, int numero, bool yaExistia});
