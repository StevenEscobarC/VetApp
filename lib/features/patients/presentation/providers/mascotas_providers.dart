import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/supabase_client_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/supabase_mascota_repository.dart';
import '../../domain/entities/mascota.dart';
import '../../domain/entities/peso_registro.dart';

final mascotaRepositoryProvider = Provider<SupabaseMascotaRepository>((ref) {
  return SupabaseMascotaRepository(ref.watch(supabaseClientProvider));
});

/// Mascotas de un cliente (CLI-04), consumido por `ClienteDetailScreen`
/// (Plan 07). `autoDispose.family` — se recalcula por clienteId y se
/// libera cuando ninguna pantalla lo observa.
final mascotasDeClienteProvider = FutureProvider.autoDispose
    .family<List<Mascota>, String>((ref, clienteId) {
      return ref.watch(mascotaRepositoryProvider).porCliente(clienteId);
    });

/// Una mascota por id, consumido por `MascotaDetailScreen` (Plan 08).
/// `autoDispose.family` — solo vive mientras la ficha está montada.
final mascotaProvider = FutureProvider.autoDispose.family<Mascota, String>((
  ref,
  mascotaId,
) {
  return ref.watch(mascotaRepositoryProvider).obtener(mascotaId);
});

/// Historial de peso de una mascota (PAT-05), más reciente primero —
/// consumido por `MascotaDetailScreen` (Plan 08).
final pesosProvider = FutureProvider.autoDispose
    .family<List<PesoRegistro>, String>((ref, mascotaId) {
      return ref.watch(mascotaRepositoryProvider).pesos(mascotaId);
    });

/// Búsqueda instantánea de mascotas (PAT-04, D-06): cada tecla llama a
/// [search], que hace debounce internamente 350ms antes de disparar la
/// consulta real — la pantalla nunca maneja su propio [Timer]. Un número de
/// secuencia descarta respuestas que llegan fuera de orden. Mirrors
/// `ClientesNotifier` exactamente (mismo patrón, misma razón — ver su doc
/// comment en `lib/features/clients/presentation/providers/clientes_providers.dart`).
class MascotasNotifier extends AsyncNotifier<List<Mascota>> {
  Timer? _debounce;
  int _sequence = 0;
  String _query = '';

  static const debounce = Duration(milliseconds: 350);

  String get query => _query;

  @override
  Future<List<Mascota>> build() async {
    ref.onDispose(() => _debounce?.cancel());
    // `await ref.watch(authProfileProvider.future)` (no la instantánea
    // síncrona `.value`) — ver la misma nota en ClientesNotifier.build().
    final clinicaId = (await ref.watch(authProfileProvider.future))?.clinicaId;
    if (clinicaId == null) return [];
    return ref.watch(mascotaRepositoryProvider).buscar(
      _query,
      clinicaId: clinicaId,
    );
  }

  /// Llamado en cada `onChanged` del campo de búsqueda de la pantalla.
  /// Deliberadamente no pone `state` en `AsyncLoading` mientras espera la
  /// respuesta — ver la misma nota en `ClientesNotifier.search()`.
  void search(String query) {
    _query = query;
    _debounce?.cancel();
    _debounce = Timer(debounce, () async {
      if (!ref.mounted) return;
      final clinicaId = ref.read(authProfileProvider).value?.clinicaId;
      if (clinicaId == null) {
        state = const AsyncData<List<Mascota>>([]);
        return;
      }
      final sequence = ++_sequence;
      final result = await AsyncValue.guard(
        () => ref
            .read(mascotaRepositoryProvider)
            .buscar(query, clinicaId: clinicaId),
      );
      if (!ref.mounted || sequence != _sequence) return;
      state = result;
    });
  }

  /// Vuelve a ejecutar la búsqueda ACTUAL ([_query], sin reiniciarla) —
  /// misma razón que `ClientesNotifier.refrescar()` (ver su doc comment):
  /// evita que `ref.invalidate(mascotasProvider)` desde una pantalla ajena
  /// resetee `_query` a `''` y deje el buscador con texto pero la lista sin
  /// filtrar (WR-02).
  Future<void> refrescar() async {
    final clinicaId = ref.read(authProfileProvider).value?.clinicaId;
    if (clinicaId == null) {
      state = const AsyncData<List<Mascota>>([]);
      return;
    }
    final sequence = ++_sequence;
    final result = await AsyncValue.guard(
      () => ref
          .read(mascotaRepositoryProvider)
          .buscar(_query, clinicaId: clinicaId),
    );
    if (!ref.mounted || sequence != _sequence) return;
    state = result;
  }
}

final mascotasProvider =
    AsyncNotifierProvider<MascotasNotifier, List<Mascota>>(
      MascotasNotifier.new,
    );
