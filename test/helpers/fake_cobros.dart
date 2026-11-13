import 'dart:async';

import 'package:vetapp/features/billing/data/repositories/supabase_cobros_repository.dart';
import 'package:vetapp/features/billing/domain/cobro_failure.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/domain/entities/cobro_item.dart';
import 'package:vetapp/features/billing/domain/entities/servicio.dart';

Cobro cobroDePrueba({
  String id = 'c1',
  TipoCobro tipo = TipoCobro.cuentaCobro,
  int numero = 12,
  EstadoCobro estado = EstadoCobro.pendiente,
  String clienteNombre = 'Laura Gómez',
  String? clienteId = 'cli1',
  String? clienteCedula,
  String? mascotaId = 'm1',
  String? mascotaNombre = 'Rocky',
  String? citaId,
  String? consultaId,
  List<CobroItem>? items,
  String creadoPor = 'vet1',
  String? autorNombre = 'Ana',
  DateTime? fecha,
  DateTime? validaHasta,
  MetodoPago? metodoPago,
  DateTime? pagadaEl,
  String? cotizacionOrigenId,
  int? cotizacionOrigenNumero,
  String? convertidaEnId,
  int? convertidaEnNumero,
  DateTime? anuladaAt,
  String? anuladaPorNombre,
  String? motivoAnulacion,
}) {
  final lineas =
      items ??
      const [
        CobroItem(
          orden: 1,
          tipo: TipoLinea.servicio,
          descripcion: 'Consulta',
          cantidad: 1,
          precioUnitarioCop: 50000,
          servicioId: 's1',
        ),
      ];
  final f = fecha ?? DateTime.utc(2026, 11, 1);
  return Cobro(
    id: id,
    tipo: tipo,
    numero: numero,
    estado: estado,
    fecha: f,
    clienteId: clienteId,
    clienteNombre: clienteNombre,
    clienteCedula: clienteCedula,
    mascotaId: mascotaId,
    mascotaNombre: mascotaNombre,
    citaId: citaId,
    consultaId: consultaId,
    items: lineas,
    totalCop: lineas.fold(0, (s, i) => s + i.subtotalCop),
    metodoPago: metodoPago,
    pagadaEl: pagadaEl ?? (metodoPago == null ? null : f),
    validaHasta:
        validaHasta ??
        (tipo == TipoCobro.cotizacion ? f.add(const Duration(days: 15)) : null),
    cotizacionOrigenId: cotizacionOrigenId,
    cotizacionOrigenNumero: cotizacionOrigenNumero,
    convertidaEnId: convertidaEnId,
    convertidaEnNumero: convertidaEnNumero,
    creadoPor: creadoPor,
    autorNombre: autorNombre,
    anuladaAt: anuladaAt,
    anuladaPorNombre: anuladaPorNombre,
    motivoAnulacion: motivoAnulacion,
  );
}

Servicio servicioDePrueba({
  String id = 's1',
  String nombre = 'Consulta',
  int precioCop = 50000,
}) => Servicio(id: id, nombre: nombre, precioCop: precioCop);

ClinicaCobroPdf clinicaPdfDePrueba() => const ClinicaCobroPdf(
  nombre: 'Clínica Sol',
  ciudad: 'Medellín',
  direccion: 'Cra 1 # 2-3',
  telefono: '3001234567',
  nit: '900123456-7',
);

/// Reemplazo en memoria de [SupabaseCobrosRepository] con estado: numera por
/// tipo desde 1, repite la misma respuesta para una clave ya usada (como la
/// idempotencia del servidor), calcula totales desde las líneas, registra
/// [llamadas] y permite errores por método.
class FakeCobrosRepository implements SupabaseCobrosRepository {
  FakeCobrosRepository({
    List<Cobro>? cobros,
    List<Servicio>? servicios,
    this.resumenData,
    this.clinica,
    this.vinculado,
    this.error,
    this.errorCobros,
    this.errorCobro,
    this.errorResumen,
    this.errorCrear,
    this.errorCotizacion,
    this.errorEditar,
    this.errorPagar,
    this.errorAnular,
    this.errorServicios,
    this.errorGuardarServicio,
    this.errorArchivarServicio,
    this.errorPdf,
  }) : _cobros = [...?cobros],
       _servicios = [...?servicios];

  final List<Cobro> _cobros;
  final List<Servicio> _servicios;
  final ResumenCobros? resumenData;
  final ClinicaCobroPdf? clinica;
  final CobroVinculado? vinculado;

  /// Error para cualquier método sin error propio.
  final Object? error;
  final Object? errorCobros;
  final Object? errorCobro;
  final Object? errorResumen;
  final Object? errorCrear;
  final Object? errorCotizacion;
  final Object? errorEditar;
  final Object? errorPagar;
  final Object? errorAnular;
  final Object? errorServicios;
  final Object? errorGuardarServicio;
  final Object? errorArchivarServicio;
  final Object? errorPdf;

  final llamadas = <({String metodo, Map<String, Object?> args})>[];

  /// Si se asigna, crear (cuenta de cobro o cotización) espera aquí antes de
  /// aplicar el cambio.
  Completer<void>? bloqueoCrear;

  final _porClave = <String, ResultadoCobro>{};
  final _ultimo = <TipoCobro, int>{};
  int _seq = 0;

  /// Documentos guardados (para inspección en tests).
  List<Cobro> get guardados => List.unmodifiable(_cobros);

  void _log(String metodo, [Map<String, Object?> args = const {}]) =>
      llamadas.add((metodo: metodo, args: args));

  void _falla(Object? propio) {
    final e = propio ?? error;
    if (e != null) throw e;
  }

  int _indice(String id) => _cobros.indexWhere((c) => c.id == id);

  List<CobroItem> _items(List<LineaCobroNueva> lineas) => [
    for (var i = 0; i < lineas.length; i++)
      CobroItem(
        orden: i + 1,
        tipo: lineas[i].tipo,
        descripcion: lineas[i].descripcion.trim(),
        cantidad: lineas[i].cantidad,
        precioUnitarioCop: lineas[i].precioUnitarioCop,
        productoId: lineas[i].productoId,
        servicioId: lineas[i].servicioId,
      ),
  ];

  Future<ResultadoCobro> _crear({
    required TipoCobro tipo,
    required String clave,
    required String clienteId,
    required List<LineaCobroNueva> lineas,
    String? mascotaId,
    String? citaId,
    String? consultaId,
    String? cotizacionId,
  }) async {
    final gate = bloqueoCrear;
    if (gate != null) await gate.future;
    final previo = _porClave[clave];
    if (previo != null) {
      return (id: previo.id, numero: previo.numero, yaExistia: true);
    }
    final numero = (_ultimo[tipo] ?? 0) + 1;
    _ultimo[tipo] = numero;
    final id = 'cobro-${++_seq}';
    int? origenNumero;
    if (cotizacionId != null) {
      final i = _indice(cotizacionId);
      if (i >= 0) {
        origenNumero = _cobros[i].numero;
        _cobros[i] = _cobros[i].copyWith(
          estado: EstadoCobro.convertida,
          convertidaEnId: id,
          convertidaEnNumero: numero,
        );
      }
    }
    final items = _items(lineas);
    _cobros.insert(
      0,
      Cobro(
        id: id,
        tipo: tipo,
        numero: numero,
        estado: tipo == TipoCobro.cotizacion
            ? EstadoCobro.abierta
            : EstadoCobro.pendiente,
        fecha: DateTime.utc(2026, 11, 13),
        clienteId: clienteId,
        clienteNombre: 'Laura Gómez',
        mascotaId: mascotaId,
        citaId: citaId,
        consultaId: consultaId,
        items: items,
        totalCop: items.fold(0, (s, i) => s + i.subtotalCop),
        validaHasta: tipo == TipoCobro.cotizacion
            ? DateTime.utc(2026, 11, 28)
            : null,
        cotizacionOrigenId: cotizacionId,
        cotizacionOrigenNumero: origenNumero,
        creadoPor: 'vet1',
        autorNombre: 'Ana',
      ),
    );
    final r = (id: id, numero: numero, yaExistia: false);
    _porClave[clave] = r;
    return r;
  }

  @override
  Future<List<Cobro>> cobros(TipoCobro tipo) async {
    _log('cobros', {'tipo': tipo});
    _falla(errorCobros);
    return [..._cobros.where((c) => c.tipo == tipo)];
  }

  @override
  Future<Cobro?> cobro(String id) async {
    _log('cobro', {'id': id});
    _falla(errorCobro);
    final i = _indice(id);
    return i < 0 ? null : _cobros[i];
  }

  @override
  Future<ResumenCobros> resumen() async {
    _log('resumen');
    _falla(errorResumen);
    final fijo = resumenData;
    if (fijo != null) return fijo;
    final pendientes = _cobros.where((c) => c.esCuentaCobro && c.pendiente);
    return ResumenCobros(
      cobradoMes: _cobros
          .where((c) => c.esCuentaCobro && c.pagada)
          .fold(0, (s, c) => s + c.totalCop),
      porCobrar: pendientes.fold(0, (s, c) => s + c.totalCop),
      pendientes: pendientes.length,
    );
  }

  @override
  Future<CobroVinculado?> cobroVinculado({
    String? citaId,
    String? consultaId,
  }) async {
    _log('cobroVinculado', {'citaId': citaId, 'consultaId': consultaId});
    _falla(errorCobro);
    final fijo = vinculado;
    if (fijo != null) return fijo;
    for (final c in _cobros) {
      if (!c.esCuentaCobro || c.anulada) continue;
      if ((citaId != null && c.citaId == citaId) ||
          (consultaId != null && c.consultaId == consultaId)) {
        return CobroVinculado(id: c.id, numero: c.numero, estado: c.estado);
      }
    }
    return null;
  }

  @override
  Future<ResultadoCobro> crearCuentaCobro({
    required String clave,
    required String clienteId,
    required List<LineaCobroNueva> lineas,
    String? mascotaId,
    String? citaId,
    String? consultaId,
    String? cotizacionId,
  }) async {
    _log('crearCuentaCobro', {
      'clave': clave,
      'clienteId': clienteId,
      'lineas': lineas,
      'mascotaId': mascotaId,
      'citaId': citaId,
      'consultaId': consultaId,
      'cotizacionId': cotizacionId,
    });
    _falla(errorCrear);
    return _crear(
      tipo: TipoCobro.cuentaCobro,
      clave: clave,
      clienteId: clienteId,
      lineas: lineas,
      mascotaId: mascotaId,
      citaId: citaId,
      consultaId: consultaId,
      cotizacionId: cotizacionId,
    );
  }

  @override
  Future<ResultadoCobro> crearCotizacion({
    required String clave,
    required String clienteId,
    required List<LineaCobroNueva> lineas,
    String? mascotaId,
  }) async {
    _log('crearCotizacion', {
      'clave': clave,
      'clienteId': clienteId,
      'lineas': lineas,
      'mascotaId': mascotaId,
    });
    _falla(errorCotizacion);
    return _crear(
      tipo: TipoCobro.cotizacion,
      clave: clave,
      clienteId: clienteId,
      lineas: lineas,
      mascotaId: mascotaId,
    );
  }

  @override
  Future<void> editarCotizacion({
    required String id,
    required String clienteId,
    required List<LineaCobroNueva> lineas,
    String? mascotaId,
  }) async {
    _log('editarCotizacion', {
      'id': id,
      'clienteId': clienteId,
      'lineas': lineas,
      'mascotaId': mascotaId,
    });
    _falla(errorEditar);
    final i = _indice(id);
    if (i < 0 || !_cobros[i].abierta) {
      throw const CobroFailure(
        'Esta cotización ya no se puede usar. Actualiza la lista.',
        tipo: ErrorCobro.cotizacionNoDisponible,
      );
    }
    final items = _items(lineas);
    _cobros[i] = _cobros[i].copyWith(
      clienteId: clienteId,
      mascotaId: mascotaId,
      items: items,
      totalCop: items.fold<int>(0, (s, it) => s + it.subtotalCop),
    );
  }

  @override
  Future<void> marcarPagado({
    required String id,
    required MetodoPago metodo,
    DateTime? fecha,
  }) async {
    _log('marcarPagado', {'id': id, 'metodo': metodo, 'fecha': fecha});
    _falla(errorPagar);
    final i = _indice(id);
    if (i < 0 || _cobros[i].anulada || !_cobros[i].esCuentaCobro) {
      throw const CobroFailure(
        'Esta cuenta de cobro cambió. Actualiza para ver su estado.',
        tipo: ErrorCobro.estadoInvalido,
      );
    }
    if (_cobros[i].pagada) return;
    _cobros[i] = _cobros[i].copyWith(
      estado: EstadoCobro.pagada,
      metodoPago: metodo,
      pagadaEl: fecha ?? DateTime.utc(2026, 11, 13),
    );
  }

  @override
  Future<void> anular({required String id, required String motivo}) async {
    _log('anular', {'id': id, 'motivo': motivo});
    _falla(errorAnular);
    final i = _indice(id);
    if (i < 0 || _cobros[i].anulada) {
      throw const CobroFailure(
        'Esta cuenta de cobro cambió. Actualiza para ver su estado.',
        tipo: ErrorCobro.estadoInvalido,
      );
    }
    _cobros[i] = _cobros[i].copyWith(
      estado: EstadoCobro.anulada,
      anuladaAt: DateTime(2026, 11, 13, 10),
      anuladaPorNombre: 'Ana',
      motivoAnulacion: motivo.trim(),
    );
  }

  @override
  Future<List<Servicio>> servicios() async {
    _log('servicios');
    _falla(errorServicios);
    return [..._servicios];
  }

  @override
  Future<String> guardarServicio({
    String? id,
    required String nombre,
    required int precioCop,
  }) async {
    _log('guardarServicio', {
      'id': id,
      'nombre': nombre,
      'precioCop': precioCop,
    });
    _falla(errorGuardarServicio);
    final nuevo = Servicio(
      id: id ?? 'servicio-${++_seq}',
      nombre: nombre.trim(),
      precioCop: precioCop,
    );
    final i = _servicios.indexWhere((s) => s.id == nuevo.id);
    if (i >= 0) {
      _servicios[i] = nuevo;
    } else {
      _servicios.add(nuevo);
    }
    return nuevo.id;
  }

  @override
  Future<void> archivarServicio(String id) async {
    _log('archivarServicio', {'id': id});
    _falla(errorArchivarServicio);
    _servicios.removeWhere((s) => s.id == id);
  }

  @override
  Future<({Cobro cobro, ClinicaCobroPdf clinica})> datosPdf(String id) async {
    _log('datosPdf', {'id': id});
    _falla(errorPdf);
    final i = _indice(id);
    if (i < 0) {
      throw const CobroFailure(
        'Esta cuenta de cobro cambió. Actualiza para ver su estado.',
        tipo: ErrorCobro.estadoInvalido,
      );
    }
    return (cobro: _cobros[i], clinica: clinica ?? clinicaPdfDePrueba());
  }
}
