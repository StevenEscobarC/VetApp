import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/supabase_client_provider.dart';
import '../../data/repositories/supabase_vacuna_repository.dart';
import '../../domain/entities/carne.dart';
import '../../domain/entities/protocolo.dart';

final vacunaRepositoryProvider = Provider<SupabaseVacunaRepository>((ref) {
  return SupabaseVacunaRepository(ref.watch(supabaseClientProvider));
});

/// Carné de una mascota (por id); solo vive mientras la ficha está montada.
final carneProvider = FutureProvider.autoDispose.family<Carne, String>((
  ref,
  mascotaId,
) {
  return ref.watch(vacunaRepositoryProvider).carne(mascotaId);
});

/// Catálogo efectivo filtrado por especie (null = todas).
final protocolosProvider = FutureProvider.autoDispose
    .family<List<Protocolo>, String?>((ref, especie) {
      return ref
          .watch(vacunaRepositoryProvider)
          .protocolos(especie: especie);
    });

/// Conteos de vencidas/próximas por mascota (insignias de la lista).
final resumenVacunasMascotasProvider =
    FutureProvider.autoDispose<Map<String, ResumenVacunasMascota>>((ref) {
      return ref.watch(vacunaRepositoryProvider).resumenPorMascota();
    });
