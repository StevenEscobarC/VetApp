import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/formato.dart';
import '../../domain/consulta_failure.dart';
import '../../domain/entities/consulta.dart';

/// Acceso concreto a Supabase para `consultas`. Sigue el mismo patrón de
/// manejo de errores en dos niveles que `SupabaseMascotaRepository` — sin
/// una interfaz `domain/repositories/`, por consistencia con el resto del
/// código ya construido en fases anteriores.
///
/// Deliberadamente no existe ningún método `actualizar`/`eliminar` — la
/// historia clínica es de solo-append (HIST-04); esto refleja que
/// `consultas` no tiene política `update`/`delete` en Postgres (Plan
/// 03-01). Tampoco existe un insert directo a la tabla — toda escritura
/// pasa por la RPC `registrar_consulta`, para que un peso capturado en la
/// consulta nunca se registre dos veces (D-02).
class SupabaseConsultaRepository {
  SupabaseConsultaRepository(this._client);

  final SupabaseClient _client;

  /// Historia clínica de [mascotaId], más reciente primero (HIST-02).
  Future<List<Consulta>> porMascota(String mascotaId) async {
    try {
      final rows = await _client
          .from('consultas')
          .select(
            '*, veterinario:perfiles!consultas_veterinario_perfil_fkey(nombre, activo)',
          )
          .eq('mascota_id', mascotaId)
          .order('fecha', ascending: false);
      return (rows as List)
          .map((row) => consultaDesdeFila(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ConsultaFailure(_messageFor(e));
    } catch (_) {
      throw const ConsultaFailure(
        'No pudimos cargar la historia clínica. Intenta de nuevo.',
      );
    }
  }

  /// Registra una consulta nueva (HIST-01, D-03: solo diagnóstico y
  /// tratamiento son obligatorios) en una sola llamada atómica a
  /// `registrar_consulta` — si [pesoKg] llega, la misma RPC alimenta
  /// `mascota_pesos` (D-02), nunca un [registrarPeso] separado. Todos los
  /// `p_` keys van siempre presentes (null permitido) para que PostgREST
  /// resuelva la firma de la función sin ambigüedad.
  Future<String> registrarConsulta({
    required String mascotaId,
    required String diagnostico,
    required String tratamiento,
    String? anamnesis,
    String? evolucion,
    double? pesoKg,
    double? temperaturaC,
    int? frecuenciaCardiaca,
    int? frecuenciaRespiratoria,
    String? mucosas,
    String? citaId,
  }) async {
    try {
      final id = await _client.rpc(
        'registrar_consulta',
        params: {
          'p_mascota_id': mascotaId,
          'p_diagnostico': diagnostico.trim(),
          'p_tratamiento': tratamiento.trim(),
          'p_anamnesis': blancoANull(anamnesis),
          'p_evolucion': blancoANull(evolucion),
          'p_peso_kg': pesoKg,
          'p_temperatura_c': temperaturaC,
          'p_frecuencia_cardiaca': frecuenciaCardiaca,
          'p_frecuencia_respiratoria': frecuenciaRespiratoria,
          'p_mucosas': blancoANull(mucosas),
          'p_cita_id': citaId,
        },
      );
      return id as String;
    } on PostgrestException catch (e) {
      throw ConsultaFailure(_messageFor(e));
    } catch (_) {
      throw const ConsultaFailure(
        'No pudimos guardar la consulta. Intenta de nuevo.',
      );
    }
  }

  String _messageFor(PostgrestException e) => mensajeErrorConsulta(e);
}

/// Traducciones centralizadas de `PostgrestException.code` a mensajes en
/// español — agregar nuevos códigos aquí, nunca inline en un call site.
@visibleForTesting
String mensajeErrorConsulta(PostgrestException e) {
  switch (e.code) {
    case '42501':
      return 'No tienes permiso para realizar esta acción.';
    case '23503':
      return e.message.toLowerCase().contains('pertenece')
          ? 'La mascota no pertenece a esta cita.'
          : 'La mascota no existe en tu clínica.';
    case '23505':
      return 'Ya registraste una consulta para esta mascota en esta cita.';
    case '23514':
      // registrar_consulta rechaza citas canceladas, "no asistió" o
      // solicitudes.
      if (e.message.toLowerCase().contains('no admite consultas')) {
        return 'Esta cita ya no admite consultas.';
      }
      return 'Revisa los datos ingresados.';
    case '23502':
    case '22003':
      return 'Revisa los datos ingresados.';
    default:
      return 'No pudimos guardar la consulta. Intenta de nuevo.';
  }
}

/// Fila de `consultas` (con el autor embebido) a [Consulta].
@visibleForTesting
Consulta consultaDesdeFila(Map<String, dynamic> row) {
  final autor = row['veterinario'] as Map<String, dynamic>?;
  return Consulta(
    id: row['id'] as String,
    mascotaId: row['mascota_id'] as String,
    veterinarioId: row['veterinario_id'] as String,
    fecha: DateTime.parse(row['fecha'] as String).toLocal(),
    diagnostico: row['diagnostico'] as String,
    tratamiento: row['tratamiento'] as String,
    anamnesis: row['anamnesis'] as String?,
    evolucion: row['evolucion'] as String?,
    veterinarioNombre: autor?['nombre'] as String?,
    veterinarioActivo: autor?['activo'] as bool?,
    examenFisico: ExamenFisico(
      pesoKg: (row['peso_kg'] as num?)?.toDouble(),
      temperaturaC: (row['temperatura_c'] as num?)?.toDouble(),
      frecuenciaCardiaca: row['frecuencia_cardiaca'] as int?,
      frecuenciaRespiratoria: row['frecuencia_respiratoria'] as int?,
      mucosas: row['mucosas'] as String?,
    ),
  );
}
