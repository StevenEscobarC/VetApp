import 'package:vetapp/features/vaccination/data/repositories/supabase_vacuna_repository.dart';
import 'package:vetapp/features/vaccination/domain/entities/carne.dart';
import 'package:vetapp/features/vaccination/domain/entities/protocolo.dart';

/// Reemplazo en memoria de [SupabaseVacunaRepository]: datos fijos o error
/// fijo más un registro de llamadas ([llamadas]) para afirmar qué se envió.
class FakeVacunaRepository implements SupabaseVacunaRepository {
  FakeVacunaRepository({
    Map<String, Carne> carnes = const {},
    this.protocolosData = const [],
    this.pendientesData = const [],
    this.resumenData = const ResumenVacunas(
      vencidas: 0,
      proximas: 0,
      ocultasAntiguas: 0,
    ),
    this.resumenPorMascotaData = const {},
    this.preview,
    this.productos = const [],
    this.token = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    this.dosisDeCitaData = const [],
    this.error,
    this.errorRegistrar,
    this.errorAnular,
    this.errorEnlace,
    this.errorGestionar,
    this.errorGuardarProtocolo,
  }) : carnes = Map.of(carnes);

  final Map<String, Carne> carnes;
  final List<Protocolo> protocolosData;
  final List<PendienteVacuna> pendientesData;
  final ResumenVacunas resumenData;
  final Map<String, ResumenVacunasMascota> resumenPorMascotaData;
  final PrevisualizacionDosis? preview;
  final List<({String producto, String? lote})> productos;
  final String token;
  final List<({String mascotaId, String biologicoNombre})> dosisDeCitaData;

  /// Error genérico para cualquier método sin error propio.
  final Object? error;
  final Object? errorRegistrar;
  final Object? errorAnular;
  final Object? errorEnlace;
  final Object? errorGestionar;
  final Object? errorGuardarProtocolo;

  final llamadas = <({String metodo, Map<String, Object?> args})>[];
  int _regeneraciones = 0;

  void _log(String metodo, [Map<String, Object?> args = const {}]) =>
      llamadas.add((metodo: metodo, args: args));

  void _falla([Object? especifico]) {
    final e = especifico ?? error;
    if (e != null) throw e;
  }

  @override
  Future<List<Protocolo>> protocolos({
    String? especie,
    bool incluirInactivos = false,
  }) async {
    _log('protocolos', {'especie': especie, 'incluirInactivos': incluirInactivos});
    _falla();
    return protocolosData
        .where((p) => especie == null || p.especies.contains(especie))
        .toList();
  }

  @override
  Future<Carne> carne(String mascotaId) async {
    _log('carne', {'mascotaId': mascotaId});
    _falla();
    return carnes[mascotaId]!;
  }

  @override
  Future<PrevisualizacionDosis?> previsualizar({
    required String mascotaId,
    required String codigo,
    required DateTime fecha,
    int? duracionDias,
    bool sinRefuerzo = false,
    bool esRefuerzo = false,
    bool iniciaSerie = false,
  }) async {
    _log('previsualizar', {
      'mascotaId': mascotaId,
      'codigo': codigo,
      'fecha': fecha,
      'duracionDias': duracionDias,
      'sinRefuerzo': sinRefuerzo,
      'esRefuerzo': esRefuerzo,
      'iniciaSerie': iniciaSerie,
    });
    _falla();
    return preview;
  }

  @override
  Future<String> registrarDosis({
    required String mascotaId,
    required String codigo,
    required String biologicoNombre,
    required DateTime fecha,
    int? duracionDias,
    bool sinRefuerzo = false,
    bool esRefuerzo = false,
    bool iniciaSerie = false,
    bool externa = false,
    String? clinicaExterna,
    String? producto,
    String? lote,
    String? observaciones,
    String? citaId,
    bool guardarEnCatalogo = false,
  }) async {
    _log('registrarDosis', {
      'mascotaId': mascotaId,
      'codigo': codigo,
      'biologicoNombre': biologicoNombre,
      'fecha': fecha,
      'duracionDias': duracionDias,
      'sinRefuerzo': sinRefuerzo,
      'esRefuerzo': esRefuerzo,
      'iniciaSerie': iniciaSerie,
      'externa': externa,
      'clinicaExterna': clinicaExterna,
      'producto': producto,
      'lote': lote,
      'observaciones': observaciones,
      'citaId': citaId,
      'guardarEnCatalogo': guardarEnCatalogo,
    });
    _falla(errorRegistrar);
    return 'dosis-nueva';
  }

  @override
  Future<void> anularDosis({
    required String dosisId,
    required String motivo,
  }) async {
    _log('anularDosis', {'dosisId': dosisId, 'motivo': motivo});
    _falla(errorAnular);
  }

  @override
  Future<List<({String producto, String? lote})>> productosRecientes() async {
    _log('productosRecientes');
    _falla();
    return productos;
  }

  @override
  Future<List<PendienteVacuna>> pendientes() async {
    _log('pendientes');
    _falla();
    return pendientesData;
  }

  @override
  Future<ResumenVacunas> resumen() async {
    _log('resumen');
    _falla();
    return resumenData;
  }

  @override
  Future<Map<String, ResumenVacunasMascota>> resumenPorMascota() async {
    _log('resumenPorMascota');
    _falla();
    return resumenPorMascotaData;
  }

  @override
  Future<void> gestionarAlerta({
    required String dosisRefId,
    required AccionAlerta accion,
    String? motivo,
    int? dias,
  }) async {
    _log('gestionarAlerta', {
      'dosisRefId': dosisRefId,
      'accion': accion,
      'motivo': motivo,
      'dias': dias,
    });
    _falla(errorGestionar);
  }

  @override
  Future<String> enlaceCarne(String mascotaId) async {
    _log('enlaceCarne', {'mascotaId': mascotaId});
    _falla(errorEnlace);
    return token;
  }

  @override
  Future<String> regenerarEnlace(String mascotaId) async {
    _log('regenerarEnlace', {'mascotaId': mascotaId});
    _falla(errorEnlace);
    _regeneraciones++;
    return '${_regeneraciones.toRadixString(16)}${token.substring(1)}';
  }

  @override
  Future<String> guardarProtocolo({
    String? codigo,
    required String nombre,
    required TipoDosis tipo,
    required List<String> especies,
    required int dosisSerie,
    int? intervaloSerieDias,
    int? intervaloRefuerzoDias,
    required List<int> opcionesDuracionDias,
  }) async {
    _log('guardarProtocolo', {
      'codigo': codigo,
      'nombre': nombre,
      'tipo': tipo,
      'especies': especies,
      'dosisSerie': dosisSerie,
      'intervaloSerieDias': intervaloSerieDias,
      'intervaloRefuerzoDias': intervaloRefuerzoDias,
      'opcionesDuracionDias': opcionesDuracionDias,
    });
    _falla(errorGuardarProtocolo);
    return codigo ?? 'custom:${nombre.toLowerCase()}';
  }

  @override
  Future<void> restablecerProtocolo(String codigo) async {
    _log('restablecerProtocolo', {'codigo': codigo});
    _falla(errorGuardarProtocolo);
  }

  @override
  Future<void> desactivarProtocolo(String codigo) async {
    _log('desactivarProtocolo', {'codigo': codigo});
    _falla(errorGuardarProtocolo);
  }

  @override
  Future<List<({String mascotaId, String biologicoNombre})>> dosisDeCita(
    String citaId,
  ) async {
    _log('dosisDeCita', {'citaId': citaId});
    _falla();
    return dosisDeCitaData;
  }
}
