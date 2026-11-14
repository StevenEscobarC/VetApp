import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/limite_plan_postgrest.dart';
import '../../../../core/errors/limite_plan.dart';
import '../../../../core/utils/formato.dart';
import '../../domain/clinica.dart';
import '../../domain/clinica_failure.dart';

/// Lectura de la clínica propia y escritura exclusiva vía el RPC
/// `actualizar_clinica` (admin-only; no existe policy UPDATE en `clinicas`).
class SupabaseClinicaRepository {
  SupabaseClinicaRepository(this._client);

  final SupabaseClient _client;

  /// Columnas que lee [miClinica] (incluye `nit`, D-04).
  static const columnasClinica =
      'id, nombre, ciudad, direccion, telefono, logo_path, nit';

  Future<Clinica> miClinica(String clinicaId) async {
    try {
      final fila = await _client
          .from('clinicas')
          .select(columnasClinica)
          .eq('id', clinicaId)
          .single();
      return Clinica.desdeJson(fila);
    } catch (_) {
      throw const ClinicaFailure('No pudimos cargar los datos de la clínica.');
    }
  }

  static Map<String, dynamic> paramsActualizarClinica({
    required String nombre,
    required String ciudad,
    required String direccion,
    required String telefono,
    String? logoPath,
    String? nit,
  }) => {
    'p_nombre': nombre.trim(),
    'p_ciudad': ciudad.trim(),
    'p_direccion': direccion.trim(),
    'p_telefono': telefono.trim(),
    'p_logo_path': logoPath,
    // Siempre se envía (función de 6 argumentos de 07-04); null lo borra.
    'p_nit': normalizarNit(nit ?? '').valor,
  };

  /// Reemplazo completo: [logoPath] con la ruta actual la conserva, null la
  /// quita. Igual con [nit].
  Future<Clinica> actualizar({
    required String nombre,
    required String ciudad,
    required String direccion,
    required String telefono,
    String? logoPath,
    String? nit,
  }) async {
    try {
      final r = await _client.rpc(
        'actualizar_clinica',
        params: paramsActualizarClinica(
          nombre: nombre,
          ciudad: ciudad,
          direccion: direccion,
          telefono: telefono,
          logoPath: logoPath,
          nit: nit,
        ),
      );
      return Clinica.desdeJson(Map<String, dynamic>.from(r as Map));
    } on PostgrestException catch (e) {
      throw ClinicaFailure(mensajeErrorClinica(e), limite: limitePlanDe(e));
    } catch (_) {
      throw const ClinicaFailure(
        'No pudimos guardar los datos de la clínica. Intenta de nuevo.',
      );
    }
  }
}

String mensajeErrorClinica(PostgrestException e) {
  switch (limitePlanDe(e)) {
    case LimitePlan.funcion:
      return 'El logo es parte de Pro y Clínica.';
    case LimitePlan.soloLectura:
      return 'Tu cuenta está en solo lectura. Pide al administrador que active el plan.';
    case _:
      break;
  }
  switch (e.code) {
    case '42501':
      return 'Solo los administradores pueden cambiar los datos de la clínica.';
    case '23514':
      return 'Revisa los datos: el nombre es obligatorio y el logo debe ser una imagen válida.';
    default:
      return 'No pudimos guardar los datos de la clínica. Intenta de nuevo.';
  }
}
