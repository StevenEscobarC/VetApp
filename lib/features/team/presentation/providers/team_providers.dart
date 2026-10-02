import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/supabase_client_provider.dart';
import '../../../../core/data/clock_provider.dart';
import '../../../appointments/presentation/providers/citas_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/supabase_team_repository.dart';
import '../../domain/invitacion.dart';
import '../../domain/miembro.dart';

final teamRepositoryProvider = Provider<SupabaseTeamRepository>((ref) {
  return SupabaseTeamRepository(ref.watch(supabaseClientProvider));
});

/// Todos los veterinarios de la clínica (activos y retirados), por antigüedad.
final teamProvider = FutureProvider.autoDispose<List<Miembro>>((ref) async {
  final clinicaId = (await ref.watch(authProfileProvider.future))?.clinicaId;
  if (clinicaId == null) return [];
  return ref.watch(teamRepositoryProvider).miembros(clinicaId);
});

/// Miembros activos; vacío mientras carga o ante error.
final miembrosActivosProvider = Provider.autoDispose<List<Miembro>>((ref) {
  final todos = ref.watch(teamProvider).value ?? const <Miembro>[];
  return todos.where((m) => m.activo).toList();
});

/// Única puerta (D-00) para todo elemento de UI multi-veterinario: `true`
/// solo con 2 o más veterinarios activos; `false` al cargar o ante error.
final esClinicaMultiVetProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(miembrosActivosProvider).length >= 2,
);

/// Índice de color (0-3) por id de veterinario, calculado sobre TODOS los
/// miembros (incluidos retirados) ordenados por `createdAt`, para que el color
/// de una persona no cambie al retirarse un colega.
final indicesColorVetProvider = Provider.autoDispose<Map<String, int>>((ref) {
  final todos = [...(ref.watch(teamProvider).value ?? const <Miembro>[])]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return {for (final m in todos) m.id: indiceColorVet(todos, m.id)};
});

/// Código de invitación vigente; `null` si no hay o si el usuario no es
/// administrador (no consulta el repositorio en ese caso).
final invitacionVigenteProvider = FutureProvider.autoDispose<Invitacion?>((
  ref,
) async {
  final perfil = await ref.watch(authProfileProvider.future);
  if (perfil == null || !perfil.esAdmin || perfil.clinicaId == null) {
    return null;
  }
  return ref.watch(teamRepositoryProvider).invitacionVigente(perfil.clinicaId!);
});

/// Acciones de administración del equipo. Sostiene el [Ref] para sobrevivir
/// al cierre de diálogos y hojas.
class TeamActions {
  TeamActions(this._ref);

  final Ref _ref;

  Future<Invitacion> generarInvitacion() async {
    final inv = await _ref.read(teamRepositoryProvider).generarInvitacion();
    _ref.invalidate(invitacionVigenteProvider);
    return inv;
  }

  Future<void> revocarInvitacion(String id) async {
    await _ref.read(teamRepositoryProvider).revocarInvitacion(id);
    _ref.invalidate(invitacionVigenteProvider);
  }

  Future<int> contarCitasAbiertas(String miembroId) {
    return _ref
        .read(teamRepositoryProvider)
        .contarCitasAbiertas(miembroId, _ref.read(clockProvider)());
  }

  /// Retira a [miembroId] y devuelve cuántas citas se reasignaron. Las citas
  /// movidas obligan a resincronizar agenda y recordatorios locales (D-09).
  Future<int> retirar(String miembroId, {String? reasignarA}) async {
    final n = await _ref
        .read(teamRepositoryProvider)
        .retirarMiembro(miembroId, reasignarA: reasignarA);
    _refrescar(miembroId);
    return n;
  }

  Future<void> cambiarRol(String miembroId, String rol) async {
    await _ref.read(teamRepositoryProvider).cambiarRol(miembroId, rol);
    _refrescar(miembroId);
  }

  Future<void> crearMiClinica(String nombre) async {
    await _ref.read(teamRepositoryProvider).crearMiClinica(nombre);
    _refrescarPerfil();
  }

  Future<void> unirseAClinica(String codigo) async {
    await _ref.read(teamRepositoryProvider).unirseAClinica(codigo);
    _refrescarPerfil();
  }

  void _refrescarPerfil() {
    _ref.invalidate(teamProvider);
    _ref.invalidate(agendaSemanaProvider);
    _ref.invalidate(authProfileProvider);
  }

  void _refrescar(String miembroId) {
    _ref.invalidate(teamProvider);
    _ref.invalidate(agendaSemanaProvider);
    _ref.read(citasRevisionProvider.notifier).incrementar();
    if (_ref.read(authProfileProvider).value?.id == miembroId) {
      _ref.invalidate(authProfileProvider);
    }
  }
}

final teamActionsProvider = Provider<TeamActions>((ref) => TeamActions(ref));
