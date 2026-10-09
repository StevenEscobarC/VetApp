import '../../../core/errors/limite_plan.dart';

/// Error de datos de citas con mensaje ya traducido al español para
/// mostrar en UI. La capa de datos ([SupabaseCitaRepository]) traduce las
/// excepciones de Supabase (`PostgrestException`) a este tipo, así la
/// presentación nunca depende del SDK — mismo patrón que [ConsultaFailure].
/// Si el servidor rechazó la escritura por un límite del plan (`LP004` solo
/// lectura, ...), [limite] lo indica y la UI abre la hoja explicativa.
class CitaFailure implements Exception, ConLimitePlan {
  const CitaFailure(this.message, {this.limite});

  final String message;

  @override
  final LimitePlan? limite;

  @override
  String toString() => message;
}
