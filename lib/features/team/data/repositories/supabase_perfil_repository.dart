import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/team_failure.dart';

/// Edición del propio perfil. Solo envía `nombre`, `telefono` y `matricula`:
/// los grants por columna de Postgres rechazan cualquier otra (42501), así que
/// un usuario no puede escalar su rol por esta vía (T1).
class SupabasePerfilRepository {
  SupabasePerfilRepository(this._client);

  final SupabaseClient _client;

  /// Actualiza el perfil [id]. [matricula] nula borra el valor. Cero filas
  /// actualizadas se trata como fallo (RLS filtra en silencio).
  Future<void> actualizarMiPerfil({
    required String id,
    required String nombre,
    required String telefono,
    String? matricula,
  }) async {
    try {
      final rows = await _client
          .from('perfiles')
          .update({
            'nombre': nombre.trim(),
            'telefono': telefono.trim(),
            'matricula': matricula,
          })
          .eq('id', id)
          .select('id');
      if ((rows as List).isEmpty) {
        throw const TeamFailure(
          'No pudimos guardar tu perfil. Intenta de nuevo.',
        );
      }
    } on TeamFailure {
      rethrow;
    } on PostgrestException catch (e) {
      throw TeamFailure(
        e.code == '23514'
            ? 'La matrícula es demasiado larga.'
            : 'No pudimos guardar tu perfil. Intenta de nuevo.',
      );
    } catch (_) {
      throw const TeamFailure(
        'No pudimos guardar tu perfil. Intenta de nuevo.',
      );
    }
  }
}
