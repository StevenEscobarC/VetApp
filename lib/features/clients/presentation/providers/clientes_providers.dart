import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/supabase_client_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/supabase_cliente_repository.dart';
import '../../domain/entities/cliente.dart';

final clienteRepositoryProvider = Provider<SupabaseClienteRepository>((ref) {
  return SupabaseClienteRepository(ref.watch(supabaseClientProvider));
});

/// Búsqueda instantánea de clientes (CLI-03, D-06): cada tecla llama a
/// [search], que hace debounce internamente 350ms antes de disparar la
/// consulta real — la pantalla nunca maneja su propio [Timer]. Un número de
/// secuencia descarta respuestas que llegan fuera de orden (T-02-16).
class ClientesNotifier extends AsyncNotifier<List<Cliente>> {
  Timer? _debounce;
  int _sequence = 0;
  String _query = '';

  static const debounce = Duration(milliseconds: 350);

  String get query => _query;

  @override
  Future<List<Cliente>> build() async {
    ref.onDispose(() => _debounce?.cancel());
    // `await ref.watch(authProfileProvider.future)` (not the synchronous
    // `.value` snapshot) — authProfileProvider is itself an AsyncNotifier,
    // so reading `.value` synchronously here would race its own pending
    // build (still AsyncLoading, `.value == null`) instead of waiting for
    // it to resolve, causing every clientesProvider build to spuriously see
    // clinicaId as null on the vet's very first app-session read.
    final clinicaId = (await ref.watch(authProfileProvider.future))?.clinicaId;
    if (clinicaId == null) return [];
    return ref.watch(clienteRepositoryProvider).buscar(
      _query,
      clinicaId: clinicaId,
    );
  }

  /// Llamado en cada `onChanged` del campo de búsqueda de la pantalla.
  /// Deliberadamente no pone `state` en `AsyncLoading` mientras espera la
  /// respuesta — `AsyncValue.copyWithPrevious` es `@internal` en riverpod
  /// 3.3.2 (no debe usarse fuera del propio paquete) — así que la lista
  /// previa se sigue mostrando tal cual hasta que la nueva búsqueda resuelve,
  /// lo que además logra el "re-renderizar en su lugar" sin estado
  /// intermedio.
  void search(String query) {
    _query = query;
    _debounce?.cancel();
    _debounce = Timer(debounce, () async {
      if (!ref.mounted) return;
      final clinicaId = ref.read(authProfileProvider).value?.clinicaId;
      if (clinicaId == null) {
        state = const AsyncData<List<Cliente>>([]);
        return;
      }
      final sequence = ++_sequence;
      final result = await AsyncValue.guard(
        () => ref
            .read(clienteRepositoryProvider)
            .buscar(query, clinicaId: clinicaId),
      );
      if (!ref.mounted || sequence != _sequence) return;
      state = result;
    });
  }
}

final clientesProvider =
    AsyncNotifierProvider<ClientesNotifier, List<Cliente>>(
      ClientesNotifier.new,
    );
