/// Error de autenticación con mensaje ya traducido para mostrar en UI.
/// La capa de datos traduce los códigos de Firebase a este tipo para que
/// el dominio/presentación nunca dependa de `firebase_auth` directamente.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
