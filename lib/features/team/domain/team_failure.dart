import '../../../core/errors/limite_plan.dart';

/// Error de dominio del equipo de la clínica: la capa de datos traduce los
/// errores de Postgrest a este tipo con un mensaje ya en español para que la
/// presentación nunca dependa del SDK de Supabase. [limite] lleva el límite de
/// plan que lo originó (p. ej. `LP002`, sin cupo de veterinarios) para que la
/// pantalla abra la hoja explicativa en vez de un mensaje suelto.
class TeamFailure implements Exception, ConLimitePlan {
  const TeamFailure(this.message, {this.limite});

  final String message;

  @override
  final LimitePlan? limite;

  @override
  String toString() => message;
}
