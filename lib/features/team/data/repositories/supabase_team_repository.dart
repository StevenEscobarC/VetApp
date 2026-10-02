import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/miembro.dart';
import '../../domain/team_failure.dart';

/// Acceso concreto a Supabase para el equipo de la clínica. Mismo patrón de
/// errores en dos niveles que los demás repositorios.
class SupabaseTeamRepository {
  SupabaseTeamRepository(this._client);

  final SupabaseClient _client;

  /// Veterinarios de [clinicaId] (activos y retirados) por antigüedad. El
  /// filtro de clínica es obligatorio: `perfiles_select` también devuelve
  /// autores de otras clínicas (D-13) que no son miembros.
  Future<List<Miembro>> miembros(String clinicaId) async {
    try {
      final rows = await _client
          .from('perfiles')
          .select('id, nombre, rol_clinica, activo, matricula, created_at')
          .eq('clinica_id', clinicaId)
          .eq('rol', 'VETERINARIO')
          .order('created_at');
      return (rows as List).map((r) {
        final row = r as Map<String, dynamic>;
        return Miembro(
          id: row['id'] as String,
          nombre: row['nombre'] as String? ?? '',
          rolClinica: row['rol_clinica'] as String? ?? 'veterinario',
          activo: row['activo'] as bool? ?? true,
          matricula: row['matricula'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw TeamFailure(_messageFor(e));
    } catch (_) {
      throw const TeamFailure('No pudimos cargar el equipo. Intenta de nuevo.');
    }
  }

  String _messageFor(PostgrestException error) {
    if (error.code == '42501') return 'Solo un administrador puede hacer esto.';
    return 'No pudimos cargar el equipo. Intenta de nuevo.';
  }
}
