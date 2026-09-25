/// Error de datos de clientes con mensaje ya traducido al español para
/// mostrar en UI. La capa de datos ([SupabaseClienteRepository]) traduce las
/// excepciones de Supabase (`PostgrestException`) a este tipo, así la
/// presentación nunca depende del SDK — mismo patrón que [AuthFailure].
class ClienteFailure implements Exception {
  const ClienteFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
