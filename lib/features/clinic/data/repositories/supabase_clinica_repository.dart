import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/clinica.dart';
import '../../domain/clinica_failure.dart';

/// Lectura de la clínica propia y escritura exclusiva vía el RPC
/// `actualizar_clinica` (admin-only; no existe policy UPDATE en `clinicas`).
class SupabaseClinicaRepository {
  SupabaseClinicaRepository(this._client);

  final SupabaseClient _client;

  Future<Clinica> miClinica(String clinicaId) async {
    try {
      final fila = await _client
          .from('clinicas')
          .select('id, nombre, ciudad, direccion, telefono, logo_path')
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
  }) => {
    'p_nombre': nombre.trim(),
    'p_ciudad': ciudad.trim(),
    'p_direccion': direccion.trim(),
    'p_telefono': telefono.trim(),
    'p_logo_path': logoPath,
  };

  /// Reemplazo completo: [logoPath] con la ruta actual la conserva, null la
  /// quita.
  Future<Clinica> actualizar({
    required String nombre,
    required String ciudad,
    required String direccion,
    required String telefono,
    String? logoPath,
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
        ),
      );
      return Clinica.desdeJson(Map<String, dynamic>.from(r as Map));
    } on PostgrestException catch (e) {
      throw ClinicaFailure(mensajeErrorClinica(e));
    } catch (_) {
      throw const ClinicaFailure(
        'No pudimos guardar los datos de la clínica. Intenta de nuevo.',
      );
    }
  }
}

String mensajeErrorClinica(PostgrestException e) {
  switch (e.code) {
    case '42501':
      return 'Solo los administradores pueden cambiar los datos de la clínica.';
    case '23514':
      return 'Revisa los datos: el nombre es obligatorio y el logo debe ser una imagen válida.';
    default:
      return 'No pudimos guardar los datos de la clínica. Intenta de nuevo.';
  }
}
