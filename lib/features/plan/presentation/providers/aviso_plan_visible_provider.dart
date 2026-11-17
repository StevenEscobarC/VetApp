import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../aviso_plan.dart';
import 'plan_providers.dart';

/// Aviso de plan que se ve ahora mismo, o `null` (cargando, error, sin aviso o
/// descartado). Mismo criterio que [PlanBanner]; Inicio lo usa para no dejar un
/// hueco cuando no hay aviso.
final avisoPlanVisibleProvider = Provider.autoDispose<AvisoPlan?>((ref) {
  final plan = ref.watch(miPlanProvider).value;
  if (plan == null) return null;
  final esAdmin =
      ref.watch(authProfileProvider).asData?.value?.esAdmin ?? false;
  final descartados = ref.watch(avisosDescartadosProvider);

  final aviso = avisoPlanPara(plan, esAdmin: esAdmin);
  if (aviso == null ||
      (aviso.descartable && descartados.contains(aviso.tipo))) {
    return null;
  }
  return aviso;
});
