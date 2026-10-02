/// Error de datos de vacunación con mensaje ya traducido al español. La capa
/// de datos ([SupabaseVacunaRepository]) traduce `PostgrestException` a este
/// tipo — mismo patrón que `CitaFailure`.
class VacunaFailure implements Exception {
  const VacunaFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
