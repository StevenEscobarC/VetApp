import 'package:vetapp/features/team/data/repositories/supabase_team_repository.dart';
import 'package:vetapp/features/team/domain/invitacion.dart';
import 'package:vetapp/features/team/domain/miembro.dart';

/// In-memory [SupabaseTeamRepository] stand-in; [error] is thrown by every
/// read so tests can exercise the error branch.
class FakeTeamRepository implements SupabaseTeamRepository {
  FakeTeamRepository({List<Miembro> miembrosFixture = const [], this.error})
    : miembrosFixture = List.of(miembrosFixture);

  final List<Miembro> miembrosFixture;
  Object? error;

  /// Invitación vigente en memoria; [generarInvitacion] la reemplaza.
  Invitacion? invitacion;

  /// Error para [generarInvitacion] / [revocarInvitacion].
  Object? errorInvitacion;
  int generadas = 0;
  final List<String> revocadas = [];

  /// Número de llamadas a [miembros].
  int llamadas = 0;

  @override
  Future<List<Miembro>> miembros(String clinicaId) async {
    llamadas++;
    if (error != null) throw error!;
    return List.of(miembrosFixture);
  }

  @override
  Future<Invitacion?> invitacionVigente(String clinicaId) async {
    llamadas++;
    if (error != null) throw error!;
    return invitacion;
  }

  @override
  Future<Invitacion> generarInvitacion() async {
    if (errorInvitacion != null) throw errorInvitacion!;
    generadas++;
    return invitacion = Invitacion(
      id: 'inv-${generadas + 1}',
      codigo: 'K7MQ4P2X',
      expiraEn: invitacionFixture.expiraEn,
    );
  }

  /// Citas abiertas que devuelve [contarCitasAbiertas].
  int citasAbiertas = 0;

  /// Error para [retirarMiembro] / [cambiarRol] / [contarCitasAbiertas].
  Object? errorCambio;
  final List<(String, String?)> retiradas = [];
  final List<(String, String)> rolesCambiados = [];

  @override
  Future<int> contarCitasAbiertas(String veterinarioId, DateTime desde) async {
    if (errorCambio != null) throw errorCambio!;
    return citasAbiertas;
  }

  @override
  Future<int> retirarMiembro(String miembroId, {String? reasignarA}) async {
    if (errorCambio != null) throw errorCambio!;
    retiradas.add((miembroId, reasignarA));
    return citasAbiertas;
  }

  @override
  Future<void> cambiarRol(String miembroId, String rol) async {
    if (errorCambio != null) throw errorCambio!;
    rolesCambiados.add((miembroId, rol));
  }

  @override
  Future<void> revocarInvitacion(String id) async {
    if (errorInvitacion != null) throw errorInvitacion!;
    revocadas.add(id);
    invitacion = null;
  }
}

final invitacionFixture = Invitacion(
  id: 'inv-1',
  codigo: 'K7MQ4P2X',
  expiraEn: DateTime.utc(2026, 10, 4, 20, 15),
);

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
