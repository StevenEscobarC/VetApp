/// Error de autenticación con mensaje ya traducido al español para mostrar en UI.
/// La capa de datos ([SupabaseAuthRepository]) traduce las excepciones de Supabase
/// (`AuthException`) a este tipo, así la presentación nunca depende del SDK.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
