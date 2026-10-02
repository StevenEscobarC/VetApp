import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/formato.dart';
import '../../domain/entities/carne.dart';
import '../../domain/entities/protocolo.dart';
import '../../domain/fecha_bd.dart';
import '../../domain/vacuna_failure.dart';

/// Acceso concreto a Supabase para vacunación y desparasitación.
///
/// Solo-append: no existe ningún método `actualizar`/`eliminar`; la única
/// corrección es [anularDosis] (D-08), reflejo de que `dosis_aplicadas` no
/// tiene políticas update/delete. La próxima dosis y el estado los deriva
/// el servidor (D-02): este repositorio nunca calcula fechas. Toda escritura
/// pasa por RPC. La RPC pública del carné es solo de la Edge Function
/// (service_role) y nunca se llama desde la app.
class SupabaseVacunaRepository {
  SupabaseVacunaRepository(this._client);

  final SupabaseClient _client;

  Future<T> _run<T>(Future<T> Function() op, String generico) async {
    try {
      return await op();
    } on PostgrestException catch (e) {
      throw VacunaFailure(mensajeErrorVacuna(e));
    } catch (_) {
      throw VacunaFailure(generico);
    }
  }

  List<Map<String, dynamic>> _filas(Object? r) => [
    for (final f in (r as List? ?? const [])) f as Map<String, dynamic>,
  ];

  /// Catálogo efectivo (semillas + personalizados de la clínica).
  Future<List<Protocolo>> protocolos({
    String? especie,
    bool incluirInactivos = false,
  }) => _run(() async {
    final r = await _client.rpc(
      'protocolos_efectivos',
      params: {'p_especie': especie, 'p_incluir_inactivos': incluirInactivos},
    );
    return _filas(r).map(Protocolo.desdeFila).toList();
  }, 'No pudimos cargar los protocolos. Intenta de nuevo.');

  Future<Carne> carne(String mascotaId) => _run(() async {
    final r = await _client.rpc(
      'carne_de_mascota',
      params: {'p_mascota_id': mascotaId},
    );
    return Carne.desdeJson(r as Map<String, dynamic>);
  }, 'No pudimos cargar el carné. Intenta de nuevo.');

  /// Vista previa de la próxima dosis; `null` si el servidor no devuelve fila.
  Future<PrevisualizacionDosis?> previsualizar({
    required String mascotaId,
    required String codigo,
    required DateTime fecha,
    int? duracionDias,
    bool sinRefuerzo = false,
    bool esRefuerzo = false,
    bool iniciaSerie = false,
  }) => _run(() async {
    final r = await _client.rpc(
      'previsualizar_dosis',
      params: {
        'p_mascota_id': mascotaId,
        'p_codigo_protocolo': codigo,
        'p_fecha_aplicacion': fechaABd(fecha),
        'p_duracion_elegida_dias': duracionDias,
        'p_sin_refuerzo': sinRefuerzo,
        'p_es_refuerzo': esRefuerzo,
        'p_inicia_serie': iniciaSerie,
      },
    );
    final filas = _filas(r);
    return filas.isEmpty ? null : PrevisualizacionDosis.desdeFila(filas.first);
  }, 'No pudimos calcular la próxima dosis. Intenta de nuevo.');

  @visibleForTesting
  static Map<String, Object?> paramsRegistrarDosis({
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
  }) => {
    'p_mascota_id': mascotaId,
    'p_codigo_protocolo': codigo,
    'p_biologico_nombre': biologicoNombre.trim(),
    'p_fecha_aplicacion': fechaABd(fecha),
    'p_duracion_elegida_dias': duracionDias,
    'p_sin_refuerzo': sinRefuerzo,
    'p_es_refuerzo': esRefuerzo,
    'p_inicia_serie': iniciaSerie,
    'p_externa': externa,
    'p_clinica_externa': blancoANull(clinicaExterna),
    'p_producto': blancoANull(producto),
    'p_lote': blancoANull(lote),
    'p_observaciones': blancoANull(observaciones),
    'p_cita_id': citaId,
    'p_guardar_en_catalogo': guardarEnCatalogo,
  };

  /// Registra una dosis (VAC-01); devuelve su id.
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
  }) => _run(() async {
    final r = await _client.rpc(
      'registrar_dosis',
      params: paramsRegistrarDosis(
        mascotaId: mascotaId,
        codigo: codigo,
        biologicoNombre: biologicoNombre,
        fecha: fecha,
        duracionDias: duracionDias,
        sinRefuerzo: sinRefuerzo,
        esRefuerzo: esRefuerzo,
        iniciaSerie: iniciaSerie,
        externa: externa,
        clinicaExterna: clinicaExterna,
        producto: producto,
        lote: lote,
        observaciones: observaciones,
        citaId: citaId,
        guardarEnCatalogo: guardarEnCatalogo,
      ),
    );
    return r as String;
  }, 'No pudimos guardar la dosis. Intenta de nuevo.');

  Future<void> anularDosis({
    required String dosisId,
    required String motivo,
  }) => _run(() async {
    await _client.rpc(
      'anular_dosis',
      params: {'p_dosis_id': dosisId, 'p_motivo': motivo.trim()},
    );
  }, 'No pudimos anular la dosis. Intenta de nuevo.');

  /// Últimos productos/lotes usados (para autocompletar), máx. 5 distintos.
  Future<List<({String producto, String? lote})>> productosRecientes() =>
      _run(() async {
        final r = await _client
            .from('dosis_aplicadas')
            .select('producto, lote, created_at')
            .not('producto', 'is', null)
            .order('created_at', ascending: false)
            .limit(30);
        return dedupeProductos(_filas(r));
      }, 'No pudimos cargar los productos recientes.');

  /// Filas ya ordenadas de más reciente a más antigua; conserva el lote más
  /// reciente de cada producto (sin distinguir mayúsculas), máximo 5.
  @visibleForTesting
  static List<({String producto, String? lote})> dedupeProductos(
    List<Map<String, dynamic>> filas,
  ) {
    final vistos = <String>{};
    final out = <({String producto, String? lote})>[];
    for (final f in filas) {
      final p = (f['producto'] as String?)?.trim();
      if (p == null || p.isEmpty) continue;
      if (!vistos.add(p.toLowerCase())) continue;
      out.add((producto: p, lote: f['lote'] as String?));
      if (out.length == 5) break;
    }
    return out;
  }

  Future<List<PendienteVacuna>> pendientes() => _run(() async {
    final r = await _client.rpc('vacunas_pendientes');
    return _filas(r).map(PendienteVacuna.desdeFila).toList();
  }, 'No pudimos cargar los pendientes. Intenta de nuevo.');

  Future<ResumenVacunas> resumen() => _run(() async {
    final r = _filas(await _client.rpc('vacunas_resumen'));
    if (r.isEmpty) {
      return const ResumenVacunas(vencidas: 0, proximas: 0, ocultasAntiguas: 0);
    }
    final f = r.first;
    return ResumenVacunas(
      vencidas: (f['vencidas'] as int?) ?? 0,
      proximas: (f['proximas'] as int?) ?? 0,
      ocultasAntiguas: (f['ocultas_antiguas'] as int?) ?? 0,
    );
  }, 'No pudimos cargar el resumen de vacunas. Intenta de nuevo.');

  Future<Map<String, ResumenVacunasMascota>> resumenPorMascota() =>
      _run(() async {
        final r = await _client.rpc('vacunas_resumen_mascotas');
        return {
          for (final f in _filas(r))
            f['mascota_id'] as String: ResumenVacunasMascota(
              vencidas: (f['vencidas'] as int?) ?? 0,
              proximas: (f['proximas'] as int?) ?? 0,
            ),
        };
      }, 'No pudimos cargar las alertas de vacunas.');

  Future<void> gestionarAlerta({
    required String dosisRefId,
    required AccionAlerta accion,
    String? motivo,
    int? dias,
  }) => _run(() async {
    await _client.rpc(
      'gestionar_alerta_vacuna',
      params: {
        'p_dosis_ref_id': dosisRefId,
        'p_accion': accion.name,
        'p_motivo': blancoANull(motivo),
        'p_dias': dias,
      },
    );
  }, 'No pudimos actualizar la alerta. Intenta de nuevo.');

  Future<String> enlaceCarne(String mascotaId) => _run(() async {
    final r = await _client.rpc(
      'obtener_o_crear_enlace_carne',
      params: {'p_mascota_id': mascotaId},
    );
    return r as String;
  }, 'No pudimos obtener el enlace del carné. Intenta de nuevo.');

  Future<String> regenerarEnlace(String mascotaId) => _run(() async {
    final r = await _client.rpc(
      'regenerar_enlace_carne',
      params: {'p_mascota_id': mascotaId},
    );
    return r as String;
  }, 'No pudimos regenerar el enlace. Intenta de nuevo.');

  /// Crea o actualiza un protocolo de la clínica; devuelve su código.
  Future<String> guardarProtocolo({
    String? codigo,
    required String nombre,
    required TipoDosis tipo,
    required List<String> especies,
    required int dosisSerie,
    int? intervaloSerieDias,
    int? intervaloRefuerzoDias,
    required List<int> opcionesDuracionDias,
  }) => _run(() async {
    final r = await _client.rpc(
      'guardar_protocolo',
      params: {
        'p_codigo': codigo,
        'p_nombre': nombre.trim(),
        'p_tipo': tipoDosisABd(tipo),
        'p_especies': especies,
        'p_dosis_serie': dosisSerie,
        'p_intervalo_serie_dias': intervaloSerieDias,
        'p_intervalo_refuerzo_dias': intervaloRefuerzoDias,
        'p_opciones_duracion_dias': opcionesDuracionDias,
      },
    );
    return r as String;
  }, 'No pudimos guardar el protocolo. Intenta de nuevo.');

  Future<void> restablecerProtocolo(String codigo) => _run(() async {
    await _client.rpc('restablecer_protocolo', params: {'p_codigo': codigo});
  }, 'No pudimos restablecer el protocolo. Intenta de nuevo.');

  Future<void> desactivarProtocolo(String codigo) => _run(() async {
    await _client.rpc('desactivar_protocolo', params: {'p_codigo': codigo});
  }, 'No pudimos desactivar el protocolo. Intenta de nuevo.');

  /// Biológicos registrados (no anulados) en una cita, por mascota.
  Future<List<({String mascotaId, String biologicoNombre})>> dosisDeCita(
    String citaId,
  ) => _run(() async {
    final r = await _client
        .from('dosis_aplicadas')
        .select('mascota_id, biologico_nombre')
        .eq('cita_id', citaId)
        .eq('anulada', false);
    return [
      for (final f in _filas(r))
        (
          mascotaId: f['mascota_id'] as String,
          biologicoNombre: f['biologico_nombre'] as String,
        ),
    ];
  }, 'No pudimos cargar las vacunas de la cita.');
}

/// Traducciones centralizadas de `PostgrestException.code` a mensajes en
/// español — nunca se muestra el texto crudo del servidor.
@visibleForTesting
String mensajeErrorVacuna(PostgrestException e) {
  switch (e.code) {
    case '42501':
      return 'No tienes permiso para hacer esto en esta clínica.';
    case '23503':
      return 'La mascota, la cita o el biológico ya no existe. Actualiza e intenta de nuevo.';
    case '23514':
      return 'Revisa los datos: la fecha no puede ser futura y los valores deben ser válidos.';
    case '23505':
      return 'Ya existe un registro igual.';
    default:
      return 'No pudimos completar la operación. Intenta de nuevo.';
  }
}
