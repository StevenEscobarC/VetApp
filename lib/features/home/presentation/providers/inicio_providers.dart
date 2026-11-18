import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/clock_provider.dart';
import '../../../../core/data/inicio_revision.dart';
import '../../../../core/data/supabase_client_provider.dart';
import '../../../appointments/domain/entities/cita.dart';
import '../../../appointments/presentation/providers/citas_providers.dart';
import '../../../inventory/data/repositories/supabase_inventario_repository.dart'
    show esErrorDeRed;
import '../../data/supabase_inicio_repository.dart';
import '../../domain/inicio_failure.dart';
import '../../domain/resumen_inicio.dart';

const String kErrorProximasCitas = 'No pudimos cargar las próximas citas.';

final inicioRepositoryProvider = Provider<SupabaseInicioRepository>((ref) {
  return SupabaseInicioRepository(ref.watch(supabaseClientProvider));
});

/// Cifras del mes para Inicio (DASH-01). Se relee al volver la app a primer
/// plano y cada vez que otra feature incrementa [inicioRevisionProvider]
/// (D-13). Sin polling ni timers.
final inicioResumenProvider = FutureProvider.autoDispose<ResumenInicio>((ref) {
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(lifecycle.dispose);
  ref.watch(inicioRevisionProvider);
  return ref.watch(inicioRepositoryProvider).resumen();
});

/// Las 5 próximas citas vivas desde "ahora" ([clockProvider]) para Inicio
/// (DASH-02). Además de la revisión de Inicio y el regreso a primer plano,
/// escucha [citasRevisionProvider] para reflejar cualquier escritura de
/// citas. Todo error sale como [InicioFailure], así el bloque de la UI solo
/// conoce un tipo de fallo (UI-SPEC §7).
final proximasCitasProvider = FutureProvider.autoDispose<List<Cita>>((
  ref,
) async {
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(lifecycle.dispose);
  ref.watch(inicioRevisionProvider);
  ref.watch(citasRevisionProvider);
  final ahora = ref.watch(clockProvider)();
  final repo = ref.watch(citaRepositoryProvider);
  try {
    return await repo.proximas(desdeUtc: ahora, limite: 5);
  } catch (e) {
    if (esErrorDeRed(e)) {
      throw const InicioFailure(kMensajeSinConexionLectura, sinConexion: true);
    }
    throw const InicioFailure(kErrorProximasCitas);
  }
});
