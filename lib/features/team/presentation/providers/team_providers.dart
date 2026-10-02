import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/supabase_client_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/supabase_team_repository.dart';
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
