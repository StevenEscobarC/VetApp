import '../../../core/errors/limite_plan.dart';

/// Error de datos de vacunación con mensaje ya traducido al español. La capa
/// de datos ([SupabaseVacunaRepository]) traduce `PostgrestException` a este
/// tipo — mismo patrón que `CitaFailure`. [limite] lleva el límite de plan
/// (`LP003`/`LP004`) que lo originó, si lo hubo.
class VacunaFailure implements Exception, ConLimitePlan {
  const VacunaFailure(this.message, {this.limite});

  final String message;

  @override
  final LimitePlan? limite;

  @override
  String toString() => message;
}
