import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/supabase_client_provider.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../data/repositories/supabase_cita_repository.dart';
import '../../domain/entities/cita.dart';

final citaRepositoryProvider = Provider<SupabaseCitaRepository>((ref) {
  return SupabaseCitaRepository(ref.watch(supabaseClientProvider));
});

/// Citas de la semana LUN-DOM que empieza en [lunes] (un `DateTime.utc` de
/// la fecha de Bogotá), ordenadas por hora ascendente. Solo RLS aísla por
/// clínica — no hay filtro de clínica en el cliente.
final agendaSemanaProvider = FutureProvider.autoDispose
    .family<List<Cita>, DateTime>((ref, lunes) async {
  final rango = rangoSemanaUtc(lunes);
  final citas = await ref
      .watch(citaRepositoryProvider)
      .entre(rango.inicio, rango.fin);
  return [...citas]..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
});

/// Una cita por id (detalle de cita).
final citaProvider = FutureProvider.autoDispose.family<Cita, String>((
  ref,
  id,
) {
  return ref.watch(citaRepositoryProvider).obtener(id);
});
