import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/soporte_config.dart';
import '../../../../core/data/supabase_client_provider.dart';
import '../../../../core/utils/telefono_co.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/supabase_plan_repository.dart';
import '../../domain/mi_plan.dart';

final planRepositoryProvider = Provider<SupabasePlanRepository>((ref) {
  return SupabasePlanRepository(ref.watch(supabaseClientProvider));
});

/// Plan de la clínica del veterinario activo. `null` si el perfil no es un
/// veterinario activo con clínica, o si Supabase no está disponible (modo
/// degradado / tests sin override): así no se programan reintentos. Los
/// errores del RPC siguen siendo [AsyncError].
final miPlanProvider = FutureProvider.autoDispose<MiPlan?>((ref) async {
  final perfil = await ref.watch(authProfileProvider.future);
  if (perfil == null ||
      !perfil.esVeterinario ||
      !perfil.activo ||
      perfil.clinicaId == null) {
    return null;
  }
  final SupabasePlanRepository repo;
  try {
    repo = ref.watch(planRepositoryProvider);
  } catch (_) {
    return null;
  }
  return repo.miPlan();
});

/// `false` solo cuando el servidor dice que el usuario está en solo lectura;
/// `true` mientras carga o ante error (el servidor es la autoridad, los
/// triggers rechazan la escritura de todos modos).
final puedeEscribirProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(miPlanProvider).value?.puedeEscribir ?? true,
);

/// Número de soporte listo para `wa.me` (solo dígitos) o `null` si el build no
/// lo trae o no es válido: entonces no se muestran número ni botón.
final soporteWhatsappProvider = Provider<String?>(
  (_) => numeroWhatsApp(kSoporteWhatsapp),
);
