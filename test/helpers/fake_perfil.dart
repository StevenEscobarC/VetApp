import 'package:vetapp/features/team/data/repositories/supabase_perfil_repository.dart';

/// In-memory [SupabasePerfilRepository]; [error] is thrown by every call and
/// [llamadas] logs each update payload.
class FakePerfilRepository implements SupabasePerfilRepository {
  FakePerfilRepository({this.error});

  Object? error;

  final List<({String id, String nombre, String telefono, String? matricula})>
  llamadas = [];

  @override
  Future<void> actualizarMiPerfil({
    required String id,
    required String nombre,
    required String telefono,
    String? matricula,
  }) async {
    if (error != null) throw error!;
    llamadas.add((
      id: id,
      nombre: nombre,
      telefono: telefono,
      matricula: matricula,
    ));
  }
}
