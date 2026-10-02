enum TipoDosis { vacuna, desparasitacionInterna, desparasitacionExterna }

/// Valor de la columna `tipo` en Postgres.
TipoDosis tipoDosisDe(String s) => switch (s) {
  'desparasitacion_interna' => TipoDosis.desparasitacionInterna,
  'desparasitacion_externa' => TipoDosis.desparasitacionExterna,
  _ => TipoDosis.vacuna,
};

String tipoDosisABd(TipoDosis t) => switch (t) {
  TipoDosis.vacuna => 'vacuna',
  TipoDosis.desparasitacionInterna => 'desparasitacion_interna',
  TipoDosis.desparasitacionExterna => 'desparasitacion_externa',
};

/// Protocolo efectivo del catálogo (semilla global o personalizado de la
/// clínica). Solo describe la regla; la próxima dosis y el estado los deriva
/// el servidor (D-02) — este modelo nunca calcula fechas.
class Protocolo {
  const Protocolo({
    required this.codigo,
    required this.nombre,
    required this.tipo,
    required this.especies,
    this.edadMinDias,
    required this.dosisSerie,
    this.intervaloSerieDias,
    this.intervaloRefuerzoDias,
    required this.opcionesDuracionDias,
    required this.personalizado,
    required this.esSemilla,
    required this.activo,
  });

  factory Protocolo.desdeFila(Map<String, dynamic> f) => Protocolo(
    codigo: f['codigo'] as String,
    nombre: f['nombre'] as String,
    tipo: tipoDosisDe(f['tipo'] as String),
    especies: List<String>.from(f['especies'] as List),
    edadMinDias: f['edad_min_dias'] as int?,
    dosisSerie: f['dosis_serie'] as int,
    intervaloSerieDias: f['intervalo_serie_dias'] as int?,
    intervaloRefuerzoDias: f['intervalo_refuerzo_dias'] as int?,
    opcionesDuracionDias: List<int>.from(
      (f['opciones_duracion_dias'] as List?) ?? const [],
    ),
    personalizado: f['personalizado'] as bool? ?? false,
    esSemilla: f['es_semilla'] as bool? ?? false,
    activo: f['activo'] as bool? ?? true,
  );

  final String codigo;
  final String nombre;
  final TipoDosis tipo;
  final List<String> especies;
  final int? edadMinDias;
  final int dosisSerie;
  final int? intervaloSerieDias;
  final int? intervaloRefuerzoDias;
  final List<int> opcionesDuracionDias;
  final bool personalizado;
  final bool esSemilla;
  final bool activo;

  bool get esOtro => codigo.startsWith('otro:');
}
