/// Límites del plan de la clínica que el servidor puede rechazar (triggers
/// `LP001`..`LP004`). Dart puro: las `*Failure` del dominio lo usan sin
/// depender del SDK de Supabase; la traducción desde `PostgrestException`
/// vive en `core/data/limite_plan_postgrest.dart`.
enum LimitePlan {
  /// `LP001`: el plan Gratis llegó a su tope de pacientes.
  pacientes,

  /// `LP002`: el plan no tiene cupo para más veterinarios activos.
  miembros,

  /// `LP003`: función exclusiva de Pro o Clínica (logo, protocolos propios).
  funcion,

  /// `LP004`: la cuenta está en solo lectura.
  soloLectura,
}

/// Error de dominio que puede llevar el [LimitePlan] que lo originó, para que
/// la presentación abra la hoja explicativa en vez de un mensaje suelto.
abstract interface class ConLimitePlan {
  /// `null` si el error no es un límite de plan.
  LimitePlan? get limite;
}

/// Límite de plan asociado a [error], o `null` si no es un [ConLimitePlan]
/// con límite.
LimitePlan? limiteDe(Object error) =>
    error is ConLimitePlan ? error.limite : null;
