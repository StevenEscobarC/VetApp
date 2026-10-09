import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/mi_plan.dart';
import '../../domain/plan_failure.dart';

/// Acceso concreto a Supabase para el plan de la clínica. Solo lee `mi_plan()`:
/// el servidor resuelve la clínica desde el JWT, nunca por parámetro.
class SupabasePlanRepository {
  SupabasePlanRepository(this._client);

  final SupabaseClient _client;

  Future<MiPlan> miPlan() async {
    try {
      final r = await _client.rpc('mi_plan');
      return MiPlan.desdeJson(Map<String, dynamic>.from(r as Map));
    } on PostgrestException catch (e) {
      throw PlanFailure(
        e.code == '42501'
            ? 'Tu cuenta no tiene acceso a un plan de clínica.'
            : _fallback,
      );
    } catch (_) {
      throw const PlanFailure(_fallback);
    }
  }
}

const String _fallback = 'No pudimos cargar tu plan. Intenta de nuevo.';
