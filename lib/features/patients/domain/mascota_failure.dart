/// Error de datos de mascotas con mensaje ya traducido al español para
/// mostrar en UI. La capa de datos ([SupabaseMascotaRepository]) traduce las
/// excepciones de Supabase (`PostgrestException`) a este tipo, así la
/// presentación nunca depende del SDK — mismo patrón que [ClienteFailure].
class MascotaFailure implements Exception {
  const MascotaFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
