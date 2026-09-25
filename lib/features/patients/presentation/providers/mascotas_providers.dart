import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/supabase_client_provider.dart';
import '../../data/repositories/supabase_mascota_repository.dart';
import '../../domain/entities/mascota.dart';

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
