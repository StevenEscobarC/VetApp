/// Error de datos de citas con mensaje ya traducido al español para
/// mostrar en UI. La capa de datos ([SupabaseCitaRepository]) traduce las
/// excepciones de Supabase (`PostgrestException`) a este tipo, así la
/// presentación nunca depende del SDK — mismo patrón que [ConsultaFailure].
class CitaFailure implements Exception {
  const CitaFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
