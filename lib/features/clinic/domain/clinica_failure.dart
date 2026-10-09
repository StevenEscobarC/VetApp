import '../../../core/errors/limite_plan.dart';

/// Error de dominio de la clínica con mensaje ya traducido para el usuario.
/// [limite] lleva el límite de plan (`LP003`/`LP004`) que lo originó, si lo
/// hubo, para que la presentación abra la hoja explicativa.
class ClinicaFailure implements Exception, ConLimitePlan {
  const ClinicaFailure(this.message, {this.limite});

  final String message;

  @override
  final LimitePlan? limite;

  @override
  String toString() => 'ClinicaFailure: $message';
}
