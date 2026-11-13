import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/limite_plan_postgrest.dart';
import '../../../../core/errors/limite_plan.dart';
import '../../../inventory/data/repositories/supabase_inventario_repository.dart'
    show esErrorDeRed;
import '../../../inventory/domain/entities/producto.dart';
import '../../../vaccination/domain/fecha_bd.dart';
import '../../domain/cobro_failure.dart';
import '../../domain/entities/cobro.dart';
import '../../domain/entities/cobro_item.dart';
import '../../domain/entities/servicio.dart';
import '../../domain/numeracion.dart';

const String kMensajeSinConexionCobro = 'Sin conexión, el cobro no se creó.';
const String kMensajeSinConexionCotizacion =
    'Sin conexión, la cotización no se guardó.';
const String kMensajeSinConexionPago =
    'Sin conexión, el pago no se guardó. Inténtalo de nuevo cuando tengas '
    'señal.';
const String kMensajeSinConexionAnulacion =
    'Sin conexión, la anulación no se guardó. Inténtalo de nuevo cuando '
    'tengas señal.';
const String kMensajeSinConexionServicio =
    'Sin conexión. No se guardaron los cambios. Inténtalo de nuevo cuando '
    'tengas señal.';

const String _kErrorLectura = 'No pudimos cargar los cobros. Intenta de nuevo.';
const String _kErrorCotizacion =
    'No pudimos guardar la cotización. Intenta de nuevo.';
const String _kErrorServicio =
    'No pudimos guardar el servicio. Intenta de nuevo.';

/// Acceso concreto a Supabase para cotizaciones, cuentas de cobro y el
/// catálogo de servicios.
///
/// Toda escritura es una RPC: el servidor asigna el número, calcula el total,
/// copia nombres y descuenta stock en la misma transacción. Desde aquí solo
/// viajan ids, la clave de idempotencia y las líneas. No se filtra por clínica
/// en Dart: la RLS aísla.
class SupabaseCobrosRepository {
  SupabaseCobrosRepository(this._client);

  final SupabaseClient _client;

  static const String kSelectCobro =
      '*, cobro_items(*), '
      'autor:perfiles!cobros_creado_por_perfil_fkey(nombre), '
      'anulador:perfiles!cobros_anulada_por_perfil_fkey(nombre), '
      'convertida:cobros!cobros_convertida_en_fkey(numero), '
      'origen:cobros!cobros_cotizacion_origen_fkey(numero)';

  Future<T> _run<T>(
    Future<T> Function() op,
    String generico, {
    String sinConexion = kMensajeSinConexionServicio,
  }) async {
    try {
      return await op();
    } on PostgrestException catch (e) {
      throw cobroFailureDe(e);
    } catch (e) {
      if (esErrorDeRed(e)) {
        throw CobroFailure(sinConexion, tipo: ErrorCobro.sinConexion);
      }
      throw CobroFailure(generico);
    }
  }

  List<Map<String, dynamic>> _filas(Object? r) => [
    for (final f in (r as List? ?? const [])) f as Map<String, dynamic>,
  ];

  ResultadoCobro _resultado(Object? r) {
    final f = _filas(r).first;
    return (
      id: f['id'] as String,
      numero: f['numero'] as int,
      yaExistia: (f['ya_existia'] as bool?) ?? false,
    );
  }

  /// Documentos del [tipo], del más reciente al más antiguo.
  Future<List<Cobro>> cobros(TipoCobro tipo) => _run(() async {
    final r = await _client
        .from('cobros')
        .select(kSelectCobro)
        .eq('tipo', tipo.bd)
        .order('fecha', ascending: false)
        .order('numero', ascending: false)
        .limit(kCobrosLista);
    return _filas(r).map(cobroDesdeFila).toList();
  }, _kErrorLectura);

  /// `null` si no existe o no es visible.
  Future<Cobro?> cobro(String id) => _run(() async {
    final f = await _client
        .from('cobros')
        .select(kSelectCobro)
        .eq('id', id)
        .maybeSingle();
    return f == null ? null : cobroDesdeFila(f);
  }, _kErrorLectura);

  Future<ResumenCobros> resumen() => _run(() async {
    final r = _filas(await _client.rpc('cobros_resumen'));
    if (r.isEmpty) return const ResumenCobros();
    final f = r.first;
    return ResumenCobros(
      cobradoMes: (f['cobrado_mes'] as num?)?.toInt() ?? 0,
      porCobrar: (f['por_cobrar'] as num?)?.toInt() ?? 0,
      pendientes: (f['pendientes'] as num?)?.toInt() ?? 0,
    );
  }, _kErrorLectura);

  /// Cuenta de cobro activa de la visita. Con solo [consultaId] se busca
  /// también por la cita de esa consulta, porque el cobro pudo nacer de la
  /// cita.
  Future<CobroVinculado?> cobroVinculado({
    String? citaId,
    String? consultaId,
  }) => _run(() async {
    var cita = citaId;
    if (cita == null && consultaId != null) {
      final c = await _client
          .from('consultas')
          .select('cita_id')
          .eq('id', consultaId)
          .maybeSingle();
      cita = c?['cita_id'] as String?;
    }
    final partes = [
      if (cita != null) 'cita_id.eq.$cita',
      if (consultaId != null) 'consulta_id.eq.$consultaId',
    ];
    if (partes.isEmpty) return null;
    final r = await _client
        .from('cobros')
        .select('id, numero, estado')
        .eq('tipo', TipoCobro.cuentaCobro.bd)
        .neq('estado', EstadoCobro.anulada.bd)
        .or(partes.join(','))
        .limit(1);
    final filas = _filas(r);
    if (filas.isEmpty) return null;
    final f = filas.first;
    return CobroVinculado(
      id: f['id'] as String,
      numero: f['numero'] as int,
      estado: EstadoCobro.desdeBd(f['estado'] as String),
    );
  }, _kErrorLectura);

  Future<ResultadoCobro> crearCuentaCobro({
    required String clave,
    required String clienteId,
    required List<LineaCobroNueva> lineas,
    String? mascotaId,
    String? citaId,
    String? consultaId,
    String? cotizacionId,
  }) => _run(
    () async {
      final p = paramsCrearCuentaCobro(
        clave: clave,
        clienteId: clienteId,
        lineas: lineas,
        mascotaId: mascotaId,
        citaId: citaId,
        consultaId: consultaId,
        cotizacionId: cotizacionId,
      );
      return _resultado(await _client.rpc('crear_cuenta_cobro', params: p));
    },
    'No pudimos crear el cobro. Intenta de nuevo.',
    sinConexion: kMensajeSinConexionCobro,
  );

  Future<ResultadoCobro> crearCotizacion({
    required String clave,
    required String clienteId,
    required List<LineaCobroNueva> lineas,
    String? mascotaId,
  }) => _run(
    () async => _resultado(
      await _client.rpc(
        'crear_cotizacion',
        params: paramsCrearCotizacion(
          clave: clave,
          clienteId: clienteId,
          lineas: lineas,
          mascotaId: mascotaId,
        ),
      ),
    ),
    _kErrorCotizacion,
    sinConexion: kMensajeSinConexionCotizacion,
  );

  Future<void> editarCotizacion({
    required String id,
    required String clienteId,
    required List<LineaCobroNueva> lineas,
    String? mascotaId,
  }) => _run(
    () async {
      await _client.rpc(
        'editar_cotizacion',
        params: paramsEditarCotizacion(
          id: id,
          clienteId: clienteId,
          lineas: lineas,
          mascotaId: mascotaId,
        ),
      );
    },
    _kErrorCotizacion,
    sinConexion: kMensajeSinConexionCotizacion,
  );

  /// Sin [fecha] el servidor usa hoy en Bogotá.
  Future<void> marcarPagado({
    required String id,
    required MetodoPago metodo,
    DateTime? fecha,
  }) => _run(
    () async {
      await _client.rpc(
        'marcar_cobro_pagado',
        params: paramsMarcarPagado(id: id, metodo: metodo, fecha: fecha),
      );
    },
    'No pudimos guardar el pago. Intenta de nuevo.',
    sinConexion: kMensajeSinConexionPago,
  );

  Future<void> anular({required String id, required String motivo}) => _run(
    () async {
      await _client.rpc(
        'anular_cobro',
        params: paramsAnular(id: id, motivo: motivo),
      );
    },
    'No pudimos anular. Intenta de nuevo.',
    sinConexion: kMensajeSinConexionAnulacion,
  );

  /// Servicios activos de la clínica, por nombre.
  Future<List<Servicio>> servicios() => _run(() async {
    final r = await _client
        .from('clinica_servicios')
        .select()
        .isFilter('archivado_at', null)
        .order('nombre');
    return _filas(r).map(servicioDesdeFila).toList();
  }, _kErrorLectura);

  /// Crea (sin [id]) o actualiza un servicio; devuelve su id.
  Future<String> guardarServicio({
    String? id,
    required String nombre,
    required int precioCop,
  }) => _run(
    () async {
      final r = await _client.rpc(
        'guardar_servicio',
        params: paramsGuardarServicio(
          id: id,
          nombre: nombre,
          precioCop: precioCop,
        ),
      );
      return r as String;
    },
    _kErrorServicio,
    sinConexion: kMensajeSinConexionServicio,
  );

  Future<void> archivarServicio(String id) => _run(
    () async {
      await _client.rpc('archivar_servicio', params: {'p_id': id});
    },
    _kErrorServicio,
    sinConexion: kMensajeSinConexionServicio,
  );

  /// Documento, ítems y encabezado de la clínica para generar el PDF.
  Future<({Cobro cobro, ClinicaCobroPdf clinica})> datosPdf(String id) =>
      _run(() async {
        final r =
            await _client.rpc('cobro_para_pdf', params: {'p_id': id})
                as Map<String, dynamic>;
        final cobro = cobroDesdeFila({
          ...(r['cobro'] as Map<String, dynamic>),
          'cobro_items': r['items'] ?? const [],
        });
        final c = r['clinica'] as Map<String, dynamic>;
        return (
          cobro: cobro,
          clinica: ClinicaCobroPdf(
            nombre: c['nombre'] as String,
            ciudad: c['ciudad'] as String?,
            direccion: c['direccion'] as String?,
            telefono: c['telefono'] as String?,
            nit: c['nit'] as String?,
            logoPath: c['logo_path'] as String?,
          ),
        );
      }, 'No pudimos preparar el PDF. Intenta de nuevo.');

  @visibleForTesting
  static Map<String, Object?> paramsCrearCuentaCobro({
    required String clave,
    required String clienteId,
    required List<LineaCobroNueva> lineas,
    String? mascotaId,
    String? citaId,
    String? consultaId,
    String? cotizacionId,
  }) => {
    'p_clave': clave,
    'p_cliente_id': clienteId,
    'p_items': [for (final l in lineas) lineaAJson(l)],
    'p_mascota_id': mascotaId,
    'p_cita_id': citaId,
    'p_consulta_id': consultaId,
    'p_cotizacion_id': cotizacionId,
  };

  @visibleForTesting
  static Map<String, Object?> paramsCrearCotizacion({
    required String clave,
    required String clienteId,
    required List<LineaCobroNueva> lineas,
    String? mascotaId,
  }) => {
    'p_clave': clave,
    'p_cliente_id': clienteId,
    'p_items': [for (final l in lineas) lineaAJson(l)],
    'p_mascota_id': mascotaId,
  };

  @visibleForTesting
  static Map<String, Object?> paramsEditarCotizacion({
    required String id,
    required String clienteId,
    required List<LineaCobroNueva> lineas,
    String? mascotaId,
  }) => {
    'p_id': id,
    'p_cliente_id': clienteId,
    'p_items': [for (final l in lineas) lineaAJson(l)],
    'p_mascota_id': mascotaId,
  };

  @visibleForTesting
  static Map<String, Object?> paramsMarcarPagado({
    required String id,
    required MetodoPago metodo,
    DateTime? fecha,
  }) => {
    'p_id': id,
    'p_metodo': metodo.bd,
    'p_fecha': fecha == null ? null : fechaABd(fecha),
  };

  @visibleForTesting
  static Map<String, Object?> paramsAnular({
    required String id,
    required String motivo,
  }) => {'p_id': id, 'p_motivo': motivo.trim()};

  @visibleForTesting
  static Map<String, Object?> paramsGuardarServicio({
    String? id,
    required String nombre,
    required int precioCop,
  }) => {'p_id': id, 'p_nombre': nombre.trim(), 'p_precio_cop': precioCop};
}

/// Línea tal como la espera `_total_items_cobro` en el servidor.
@visibleForTesting
Map<String, Object?> lineaAJson(LineaCobroNueva l) => {
  'tipo': l.tipo.bd,
  'producto_id': l.productoId,
  'servicio_id': l.servicioId,
  'descripcion': l.descripcion.trim(),
  'cantidad': l.cantidad,
  'precio_unitario_cop': l.precioUnitarioCop,
};

String? _nombreEmbed(Object? embed) =>
    embed is Map ? embed['nombre'] as String? : null;

int? _numeroEmbed(Object? embed) =>
    embed is Map ? (embed['numero'] as num?)?.toInt() : null;

DateTime? _fecha(Object? v) => v == null ? null : fechaDeBd(v as String);

/// Acepta la fila de PostgREST (embeds `autor`, `anulador`, `convertida`,
/// `origen`) y la forma plana de `cobro_para_pdf` (`autor_nombre`, ...).
@visibleForTesting
Cobro cobroDesdeFila(Map<String, dynamic> f) {
  final items = [
    for (final i in (f['cobro_items'] as List? ?? const []))
      _itemDesdeFila(i as Map<String, dynamic>),
  ]..sort((a, b) => a.orden.compareTo(b.orden));
  final metodo = f['metodo_pago'] as String?;
  final anuladaAt = f['anulada_at'] as String?;
  return Cobro(
    id: f['id'] as String,
    tipo: TipoCobro.desdeBd(f['tipo'] as String),
    numero: f['numero'] as int,
    estado: EstadoCobro.desdeBd(f['estado'] as String),
    fecha: fechaDeBd(f['fecha'] as String),
    clienteId: f['cliente_id'] as String?,
    clienteNombre: f['cliente_nombre'] as String,
    clienteCedula: f['cliente_cedula'] as String?,
    mascotaId: f['mascota_id'] as String?,
    mascotaNombre: f['mascota_nombre'] as String?,
    citaId: f['cita_id'] as String?,
    consultaId: f['consulta_id'] as String?,
    items: items,
    totalCop: f['total_cop'] as int,
    metodoPago: metodo == null ? null : MetodoPago.desdeBd(metodo),
    pagadaEl: _fecha(f['pagada_el']),
    validaHasta: _fecha(f['valida_hasta']),
    cotizacionOrigenId: f['cotizacion_origen_id'] as String?,
    cotizacionOrigenNumero:
        _numeroEmbed(f['origen']) ??
        (f['cotizacion_origen_numero'] as num?)?.toInt(),
    convertidaEnId: f['convertida_en_id'] as String?,
    convertidaEnNumero:
        _numeroEmbed(f['convertida']) ??
        (f['convertida_en_numero'] as num?)?.toInt(),
    creadoPor: f['creado_por'] as String,
    autorNombre: _nombreEmbed(f['autor']) ?? f['autor_nombre'] as String?,
    anuladaAt: anuladaAt == null ? null : DateTime.parse(anuladaAt).toLocal(),
    anuladaPorNombre:
        _nombreEmbed(f['anulador']) ?? f['anulada_por_nombre'] as String?,
    motivoAnulacion: f['motivo_anulacion'] as String?,
  );
}

CobroItem _itemDesdeFila(Map<String, dynamic> f) => CobroItem(
  orden: f['orden'] as int,
  tipo: TipoLinea.desdeBd(f['tipo'] as String),
  descripcion: f['descripcion'] as String,
  cantidad: f['cantidad'] as int,
  precioUnitarioCop: f['precio_unitario_cop'] as int,
  productoId: f['producto_id'] as String?,
  servicioId: f['servicio_id'] as String?,
);

@visibleForTesting
Servicio servicioDesdeFila(Map<String, dynamic> f) => Servicio(
  id: f['id'] as String,
  nombre: f['nombre'] as String,
  precioCop: f['precio_cop'] as int,
);

/// Detalle json del error (`detail` del `raise`), o `null` si no es legible.
Map<String, dynamic>? _detalle(PostgrestException e) {
  final d = e.details;
  if (d is Map<String, dynamic>) return d;
  if (d is! String) return null;
  try {
    final j = jsonDecode(d);
    return j is Map<String, dynamic> ? j : null;
  } on FormatException {
    return null;
  }
}

ErrorCobro _tipoDe(PostgrestException e, LimitePlan? limite) {
  if (limite == LimitePlan.soloLectura) return ErrorCobro.soloLectura;
  return switch (e.code) {
    'IN001' => ErrorCobro.stockInsuficiente,
    'IN002' => ErrorCobro.productoNoDisponible,
    'BC001' => ErrorCobro.estadoInvalido,
    'BC002' => ErrorCobro.cotizacionNoDisponible,
    'BC003' => ErrorCobro.visitaYaCobrada,
    '23505' => ErrorCobro.nombreDuplicado,
    '42501' => ErrorCobro.sinPermiso,
    '23514' => ErrorCobro.datosInvalidos,
    _ => ErrorCobro.otro,
  };
}

/// Única traducción de errores de cobros: tipo, mensaje y datos del detalle
/// se arman aquí. El texto crudo del servidor nunca llega a la UI.
@visibleForTesting
CobroFailure cobroFailureDe(PostgrestException e) {
  final limite = limitePlanDe(e);
  final tipo = _tipoDe(e, limite);
  final d = _detalle(e);
  final productoId = d?['producto_id'];
  final quedan = d?['quedan'];
  final numero = d?['numero'];
  return CobroFailure(
    _mensaje(tipo, d),
    tipo: tipo,
    limite: limite,
    productoId:
        (tipo == ErrorCobro.stockInsuficiente ||
                tipo == ErrorCobro.productoNoDisponible) &&
            productoId is String
        ? productoId
        : null,
    quedan: tipo == ErrorCobro.stockInsuficiente && quedan is int
        ? quedan
        : null,
    numeroExistente: tipo == ErrorCobro.visitaYaCobrada && numero is String
        ? numero
        : null,
  );
}

@visibleForTesting
String mensajeErrorCobro(PostgrestException e) => cobroFailureDe(e).message;

String _mensaje(ErrorCobro tipo, Map<String, dynamic>? d) {
  final producto = d?['producto'];
  switch (tipo) {
    case ErrorCobro.soloLectura:
      return 'Tu cuenta está en solo lectura. Pide al administrador que '
          'active el plan.';
    case ErrorCobro.stockInsuficiente:
      final quedan = d?['quedan'];
      final unidad = d?['unidad'];
      if (producto is! String || quedan is! int || unidad is! String) {
        return 'No hay suficiente stock para esta cuenta de cobro.';
      }
      if (quedan <= 0) return '$producto está agotado.';
      final etiqueta = Unidad.desdeBd(unidad).etiqueta(quedan);
      final verbo = quedan == 1 ? 'queda' : 'quedan';
      return 'Solo $verbo $quedan $etiqueta de $producto.';
    case ErrorCobro.productoNoDisponible:
      return producto is String
          ? '$producto ya no está disponible. Quítalo del cobro.'
          : 'Ese producto ya no está disponible. Quítalo del cobro.';
    case ErrorCobro.estadoInvalido:
      return 'Esta cuenta de cobro cambió. Actualiza para ver su estado.';
    case ErrorCobro.cotizacionNoDisponible:
      return 'Esta cotización ya no se puede usar. Actualiza la lista.';
    case ErrorCobro.visitaYaCobrada:
      final numero = d?['numero'];
      return numero is String
          ? 'Esta visita ya tiene la cuenta de cobro $numero.'
          : 'Esta visita ya tiene una cuenta de cobro.';
    case ErrorCobro.nombreDuplicado:
      return 'Ya tienes un servicio con ese nombre.';
    case ErrorCobro.sinPermiso:
      return 'Solo el administrador o quien la emitió puede hacer esto.';
    case ErrorCobro.datosInvalidos:
      return 'Revisa los datos del cobro.';
    case ErrorCobro.sinConexion:
    case ErrorCobro.otro:
      return 'No pudimos completar la operación. Intenta de nuevo.';
  }
}
