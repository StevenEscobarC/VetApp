/// Error de datos de consultas con mensaje ya traducido al español para
/// mostrar en UI. La capa de datos ([SupabaseConsultaRepository]) traduce
/// las excepciones de Supabase (`PostgrestException`) a este tipo, así la
/// presentación nunca depende del SDK — mismo patrón que [MascotaFailure].
class ConsultaFailure implements Exception {
  const ConsultaFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
