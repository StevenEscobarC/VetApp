import '../../vaccination/domain/fecha_bd.dart';

/// Plan efectivo de la clínica (`mi_plan().plan`).
enum PlanTipo { gratis, pro, clinica, beta }

/// De dónde sale el plan efectivo (`mi_plan().origen`).
enum OrigenPlan { gratis, pagado, pruebaPro, pruebaClinica, beta }

/// Estado de vigencia (`mi_plan().estado`): sin fecha, dentro de la fecha o
/// pasada la fecha pero dentro de los días de gracia.
enum EstadoPlan { sinVencimiento, vigente, gracia }

PlanTipo _planDe(String? v) => switch (v) {
  'pro' => PlanTipo.pro,
  'clinica' => PlanTipo.clinica,
  'beta' => PlanTipo.beta,
  _ => PlanTipo.gratis,
};

OrigenPlan? _origenDe(String? v) => switch (v) {
  'pagado' => OrigenPlan.pagado,
  'prueba_pro' => OrigenPlan.pruebaPro,
  'prueba_clinica' => OrigenPlan.pruebaClinica,
  'beta' => OrigenPlan.beta,
  'gratis' => OrigenPlan.gratis,
  _ => null,
};

EstadoPlan _estadoDe(String? v) => switch (v) {
  'vigente' => EstadoPlan.vigente,
  'gracia' => EstadoPlan.gracia,
  _ => EstadoPlan.sinVencimiento,
};

DateTime? _fecha(Object? v) => v == null ? null : fechaDeBd(v as String);

/// Plan vigente de la clínica calculado en el servidor (mi_plan, PLAN-01).
/// Dart solo mapea: nunca recalcula fechas ni límites.
class MiPlan {
  const MiPlan({
    required this.plan,
    required this.origen,
    required this.estado,
    required this.fundador,
    this.vigenteHasta,
    this.graciaHasta,
    this.diasRestantes,
    this.ultimoVencimiento,
    this.ultimoOrigen,
    required this.pacientesCount,
    this.pacientesMax,
    required this.veterinariosActivos,
    this.miembrosMax,
    required this.logoPermitido,
    required this.logoGuardado,
    required this.protocolosPropiosPermitidos,
    required this.puedeEscribir,
    required this.pruebaClinicaDisponible,
    required this.pruebaClinicaMiembros,
    required this.hayColegas,
    required this.clinicaNombre,
  });

  /// Mapea las 21 llaves de `mi_plan()`. Un valor de enum desconocido cae a
  /// gratis / sin vencimiento para que una adición del servidor no rompa la
  /// app.
  factory MiPlan.desdeJson(Map<String, dynamic> json) => MiPlan(
    plan: _planDe(json['plan'] as String?),
    origen: _origenDe(json['origen'] as String?) ?? OrigenPlan.gratis,
    estado: _estadoDe(json['estado'] as String?),
    fundador: json['fundador'] as bool? ?? false,
    vigenteHasta: _fecha(json['vigente_hasta']),
    graciaHasta: _fecha(json['gracia_hasta']),
    diasRestantes: json['dias_restantes'] as int?,
    ultimoVencimiento: _fecha(json['ultimo_vencimiento']),
    ultimoOrigen: _origenDe(json['ultimo_origen'] as String?),
    pacientesCount: json['pacientes_count'] as int? ?? 0,
    pacientesMax: json['pacientes_max'] as int?,
    veterinariosActivos: json['veterinarios_activos'] as int? ?? 0,
    miembrosMax: json['miembros_max'] as int?,
    logoPermitido: json['logo_permitido'] as bool? ?? false,
    logoGuardado: json['logo_guardado'] as bool? ?? false,
    protocolosPropiosPermitidos:
        json['protocolos_propios_permitidos'] as bool? ?? false,
    puedeEscribir: json['puede_escribir'] as bool? ?? true,
    pruebaClinicaDisponible:
        json['prueba_clinica_disponible'] as bool? ?? false,
    pruebaClinicaMiembros: json['prueba_clinica_miembros'] as int? ?? 5,
    hayColegas: json['hay_colegas'] as bool? ?? false,
    clinicaNombre: json['clinica_nombre'] as String? ?? '',
  );

  final PlanTipo plan;
  final OrigenPlan origen;
  final EstadoPlan estado;
  final bool fundador;

  /// Último día incluido del plan; `null` si no vence.
  final DateTime? vigenteHasta;
  final DateTime? graciaHasta;

  /// Días que quedan (vigente) o de gracia que quedan (gracia), según el
  /// servidor; `null` si no vence.
  final int? diasRestantes;
  final DateTime? ultimoVencimiento;
  final OrigenPlan? ultimoOrigen;
  final int pacientesCount;

  /// `null` = sin límite.
  final int? pacientesMax;
  final int veterinariosActivos;

  /// `null` = sin tope (Beta).
  final int? miembrosMax;
  final bool logoPermitido;
  final bool logoGuardado;
  final bool protocolosPropiosPermitidos;
  final bool puedeEscribir;
  final bool pruebaClinicaDisponible;
  final int pruebaClinicaMiembros;
  final bool hayColegas;
  final String clinicaNombre;

  /// El plan efectivo es una prueba (Pro o Clínica).
  bool get esPrueba =>
      origen == OrigenPlan.pruebaPro || origen == OrigenPlan.pruebaClinica;

  /// Se alcanzó el límite de pacientes del plan.
  bool get pacientesAlTope =>
      pacientesMax != null && pacientesCount >= pacientesMax!;

  /// No queda cupo de veterinarios activos.
  bool get sinCupoMiembros =>
      miembrosMax != null && veterinariosActivos >= miembrosMax!;

  /// Copia con campos reemplazados. Los campos anulables solo pueden
  /// cambiarse a un valor, no a `null`.
  MiPlan copyWith({
    PlanTipo? plan,
    OrigenPlan? origen,
    EstadoPlan? estado,
    bool? fundador,
    DateTime? vigenteHasta,
    DateTime? graciaHasta,
    int? diasRestantes,
    DateTime? ultimoVencimiento,
    OrigenPlan? ultimoOrigen,
    int? pacientesCount,
    int? pacientesMax,
    int? veterinariosActivos,
    int? miembrosMax,
    bool? logoPermitido,
    bool? logoGuardado,
    bool? protocolosPropiosPermitidos,
    bool? puedeEscribir,
    bool? pruebaClinicaDisponible,
    int? pruebaClinicaMiembros,
    bool? hayColegas,
    String? clinicaNombre,
  }) => MiPlan(
    plan: plan ?? this.plan,
    origen: origen ?? this.origen,
    estado: estado ?? this.estado,
    fundador: fundador ?? this.fundador,
    vigenteHasta: vigenteHasta ?? this.vigenteHasta,
    graciaHasta: graciaHasta ?? this.graciaHasta,
    diasRestantes: diasRestantes ?? this.diasRestantes,
    ultimoVencimiento: ultimoVencimiento ?? this.ultimoVencimiento,
    ultimoOrigen: ultimoOrigen ?? this.ultimoOrigen,
    pacientesCount: pacientesCount ?? this.pacientesCount,
    pacientesMax: pacientesMax ?? this.pacientesMax,
    veterinariosActivos: veterinariosActivos ?? this.veterinariosActivos,
    miembrosMax: miembrosMax ?? this.miembrosMax,
    logoPermitido: logoPermitido ?? this.logoPermitido,
    logoGuardado: logoGuardado ?? this.logoGuardado,
    protocolosPropiosPermitidos:
        protocolosPropiosPermitidos ?? this.protocolosPropiosPermitidos,
    puedeEscribir: puedeEscribir ?? this.puedeEscribir,
    pruebaClinicaDisponible:
        pruebaClinicaDisponible ?? this.pruebaClinicaDisponible,
    pruebaClinicaMiembros: pruebaClinicaMiembros ?? this.pruebaClinicaMiembros,
    hayColegas: hayColegas ?? this.hayColegas,
    clinicaNombre: clinicaNombre ?? this.clinicaNombre,
  );
}
