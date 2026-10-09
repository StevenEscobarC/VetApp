/// Error de dominio del plan de la clínica: la capa de datos traduce los
/// errores de Postgrest a este tipo con un mensaje ya en español para que la
/// presentación nunca dependa del SDK de Supabase.
class PlanFailure implements Exception {
  const PlanFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
