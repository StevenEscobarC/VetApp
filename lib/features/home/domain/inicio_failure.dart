/// Error de Inicio con un mensaje en español listo para la UI. La capa de
/// datos traduce los errores de Supabase y de red a este tipo, así la
/// presentación nunca depende del SDK. [sinConexion] distingue la falta de
/// señal (D-14) de un fallo del servidor.
class InicioFailure implements Exception {
  const InicioFailure(this.message, {this.sinConexion = false});

  final String message;
  final bool sinConexion;

  @override
  String toString() => message;
}
