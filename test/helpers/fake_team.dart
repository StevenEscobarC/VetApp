import 'package:vetapp/features/team/data/repositories/supabase_team_repository.dart';
import 'package:vetapp/features/team/domain/miembro.dart';

/// In-memory [SupabaseTeamRepository] stand-in; [error] is thrown by every
/// read so tests can exercise the error branch.
class FakeTeamRepository implements SupabaseTeamRepository {
  FakeTeamRepository({List<Miembro> miembrosFixture = const [], this.error})
    : miembrosFixture = List.of(miembrosFixture);

  final List<Miembro> miembrosFixture;
  Object? error;

  /// Número de llamadas a [miembros].
  int llamadas = 0;

  @override
  Future<List<Miembro>> miembros(String clinicaId) async {
    llamadas++;
    if (error != null) throw error!;
    return List.of(miembrosFixture);
  }
}

final miembroAna = Miembro(
  id: 'vet-1',
  nombre: 'Ana Ramírez',
  rolClinica: 'admin',
  activo: true,
  matricula: '12345',
  createdAt: DateTime(2026, 1, 1),
);

final miembroLuis = Miembro(
  id: 'vet-2',
  nombre: 'Luis Gómez',
  rolClinica: 'veterinario',
  activo: true,
  createdAt: DateTime(2026, 2, 1),
);

final miembroRetirado = Miembro(
  id: 'vet-3',
  nombre: 'Marta Ruiz',
  rolClinica: 'veterinario',
  activo: false,
  createdAt: DateTime(2026, 3, 1),
);
