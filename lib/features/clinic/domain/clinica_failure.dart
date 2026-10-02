/// Error de dominio de la clínica con mensaje ya traducido para el usuario.
class ClinicaFailure implements Exception {
  const ClinicaFailure(this.message);

  final String message;

  @override
  String toString() => 'ClinicaFailure: $message';
}
