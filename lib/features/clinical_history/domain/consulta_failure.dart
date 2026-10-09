import '../../../core/errors/limite_plan.dart';

/// Error de datos de consultas con mensaje ya traducido al español para
/// mostrar en UI. La capa de datos ([SupabaseConsultaRepository]) traduce
/// las excepciones de Supabase (`PostgrestException`) a este tipo, así la
/// presentación nunca depende del SDK — mismo patrón que [MascotaFailure].
/// Si el servidor rechazó la escritura por un límite del plan (`LP004` solo
/// lectura, ...), [limite] lo indica y la UI abre la hoja explicativa en vez
/// de mostrar solo [message].
class ConsultaFailure implements Exception, ConLimitePlan {
  const ConsultaFailure(this.message, {this.limite});

  final String message;

  @override
  final LimitePlan? limite;

  @override
  String toString() => message;
}
