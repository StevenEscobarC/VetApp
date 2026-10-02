import '../fecha_bd.dart';
import 'protocolo.dart';

enum EstadoCarne { alDia, proxima, vencida, completo }

EstadoCarne estadoCarneDe(String s) => switch (s) {
  'proxima' => EstadoCarne.proxima,
  'vencida' => EstadoCarne.vencida,
  'completo' => EstadoCarne.completo,
  _ => EstadoCarne.alDia,
};

enum AccionAlerta { descartar, posponer, recordado, restaurar }

DateTime? _fecha(Object? v) => v == null ? null : fechaDeBd(v as String);
DateTime? _instante(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toUtc();

/// Estado de un biológico en el carné. La próxima fecha, la etiqueta y el
/// estado los deriva el servidor (`_carne_filas`, D-02): Dart solo los mapea.
class BiologicoCarne {
  const BiologicoCarne({
    required this.codigoProtocolo,
    required this.biologicoNombre,
    required this.tipo,
    required this.ultimaDosisId,
    required this.ultimaFecha,
    required this.posicion,
    required this.dosisSerie,
    this.proximaFecha,
    required this.etiquetaProxima,
    required this.estado,
    required this.diasVencida,
    required this.ventanaDias,
    required this.sugerirReiniciar,
  });

  factory BiologicoCarne.desdeJson(Map<String, dynamic> j) => BiologicoCarne(
    codigoProtocolo: j['codigo_protocolo'] as String,
    biologicoNombre: j['biologico_nombre'] as String,
    tipo: tipoDosisDe(j['tipo'] as String),
    ultimaDosisId: j['ultima_dosis_id'] as String,
    ultimaFecha: fechaDeBd(j['ultima_fecha'] as String),
    posicion: j['posicion'] as int,
    dosisSerie: j['dosis_serie'] as int,
    proximaFecha: _fecha(j['proxima_fecha']),
    etiquetaProxima: (j['etiqueta_proxima'] as String?) ?? '',
    estado: estadoCarneDe(j['estado'] as String),
    diasVencida: (j['dias_vencida'] as int?) ?? 0,
    ventanaDias: (j['ventana_dias'] as int?) ?? 0,
    sugerirReiniciar: (j['sugerir_reiniciar'] as bool?) ?? false,
  );

  final String codigoProtocolo;
  final String biologicoNombre;
  final TipoDosis tipo;
  final String ultimaDosisId;
  final DateTime ultimaFecha;
  final int posicion;
  final int dosisSerie;
  final DateTime? proximaFecha;
  final String etiquetaProxima;
  final EstadoCarne estado;
  final int diasVencida;
  final int ventanaDias;
  final bool sugerirReiniciar;
}

/// Veterinario que aplicó la dosis (snapshot; puede estar inactivo, D-09).
class VeterinarioDosis {
  const VeterinarioDosis({
    required this.nombre,
    this.matricula,
    required this.activo,
  });

  final String nombre;
  final String? matricula;
  final bool activo;
}

/// Dosis aplicada (fila append-only; las anuladas siguen visibles, D-08).
class DosisCarne {
  const DosisCarne({
    required this.id,
    required this.codigoProtocolo,
    required this.biologicoNombre,
    required this.tipo,
    required this.fechaAplicacion,
    this.etiquetaDosis,
    required this.esUltima,
    this.producto,
    this.lote,
    this.observaciones,
    required this.externa,
    this.clinicaExterna,
    required this.esRefuerzo,
    this.citaId,
    required this.anulada,
    this.motivoAnulacion,
    this.anuladaAt,
    this.veterinario,
  });

  factory DosisCarne.desdeJson(Map<String, dynamic> j) {
    final vet = j['veterinario'] as Map<String, dynamic>?;
    return DosisCarne(
      id: j['id'] as String,
      codigoProtocolo: j['codigo_protocolo'] as String,
      biologicoNombre: j['biologico_nombre'] as String,
      tipo: tipoDosisDe(j['tipo'] as String),
      fechaAplicacion: fechaDeBd(j['fecha_aplicacion'] as String),
      etiquetaDosis: j['etiqueta_dosis'] as String?,
      esUltima: (j['es_ultima'] as bool?) ?? false,
      producto: j['producto'] as String?,
      lote: j['lote'] as String?,
      observaciones: j['observaciones'] as String?,
      externa: (j['externa'] as bool?) ?? false,
      clinicaExterna: j['clinica_externa'] as String?,
      esRefuerzo: (j['es_refuerzo'] as bool?) ?? false,
      citaId: j['cita_id'] as String?,
      anulada: (j['anulada'] as bool?) ?? false,
      motivoAnulacion: j['motivo_anulacion'] as String?,
      anuladaAt: _instante(j['anulada_at']),
      veterinario: vet == null
          ? null
          : VeterinarioDosis(
              nombre: (vet['nombre'] as String?) ?? '',
              matricula: vet['matricula'] as String?,
              activo: (vet['activo'] as bool?) ?? true,
            ),
    );
  }

  final String id;
  final String codigoProtocolo;
  final String biologicoNombre;
  final TipoDosis tipo;
  final DateTime fechaAplicacion;
  final String? etiquetaDosis;
  final bool esUltima;
  final String? producto;
  final String? lote;
  final String? observaciones;
  final bool externa;
  final String? clinicaExterna;
  final bool esRefuerzo;
  final String? citaId;
  final bool anulada;
  final String? motivoAnulacion;
  final DateTime? anuladaAt;
  final VeterinarioDosis? veterinario;
}

/// Carné completo de una mascota tal como lo devuelve `carne_de_mascota`.
class Carne {
  const Carne({
    required this.hoy,
    required this.mascotaId,
    required this.mascotaNombre,
    required this.especie,
    required this.raza,
    this.fechaNacimiento,
    this.fotoPath,
    required this.duenoNombre,
    required this.duenoTelefono,
    required this.clinicaNombre,
    required this.clinicaCiudad,
    required this.biologicos,
    required this.dosis,
  });

  factory Carne.desdeJson(Map<String, dynamic> j) {
    final m = j['mascota'] as Map<String, dynamic>;
    final d = (j['dueno'] as Map<String, dynamic>?) ?? const {};
    final c = (j['clinica'] as Map<String, dynamic>?) ?? const {};
    return Carne(
      hoy: fechaDeBd(j['hoy'] as String),
      mascotaId: m['id'] as String,
      mascotaNombre: m['nombre'] as String,
      especie: m['especie'] as String,
      raza: (m['raza'] as String?) ?? '',
      fechaNacimiento: _fecha(m['fecha_nacimiento']),
      fotoPath: m['foto_path'] as String?,
      duenoNombre: (d['nombre'] as String?) ?? '',
      duenoTelefono: (d['telefono'] as String?) ?? '',
      clinicaNombre: (c['nombre'] as String?) ?? '',
      clinicaCiudad: (c['ciudad'] as String?) ?? '',
      biologicos: [
        for (final b in (j['biologicos'] as List? ?? const []))
          BiologicoCarne.desdeJson(b as Map<String, dynamic>),
      ],
      dosis: [
        for (final x in (j['dosis'] as List? ?? const []))
          DosisCarne.desdeJson(x as Map<String, dynamic>),
      ],
    );
  }

  final DateTime hoy;
  final String mascotaId;
  final String mascotaNombre;
  final String especie;
  final String raza;
  final DateTime? fechaNacimiento;
  final String? fotoPath;
  final String duenoNombre;
  final String duenoTelefono;
  final String clinicaNombre;
  final String clinicaCiudad;
  final List<BiologicoCarne> biologicos;
  final List<DosisCarne> dosis;

  /// vencida > proxima > alDia/completo; null si no hay biológicos.
  EstadoCarne? get peorEstado {
    if (biologicos.isEmpty) return null;
    if (biologicos.any((b) => b.estado == EstadoCarne.vencida)) {
      return EstadoCarne.vencida;
    }
    if (biologicos.any((b) => b.estado == EstadoCarne.proxima)) {
      return EstadoCarne.proxima;
    }
    return EstadoCarne.alDia;
  }

  /// Biológicos vencidos o próximos.
  int get pendientes => biologicos
      .where(
        (b) =>
            b.estado == EstadoCarne.vencida || b.estado == EstadoCarne.proxima,
      )
      .length;

  /// Dosis de un biológico, más reciente primero (incluye anuladas).
  List<DosisCarne> historialDe(String codigo) {
    final l = dosis.where((d) => d.codigoProtocolo == codigo).toList();
    l.sort((a, b) => b.fechaAplicacion.compareTo(a.fechaAplicacion));
    return l;
  }
}

/// Resultado de `previsualizar_dosis` (sin insertar nada).
class PrevisualizacionDosis {
  const PrevisualizacionDosis({
    required this.posicion,
    required this.dosisSerie,
    required this.etiquetaDosis,
    this.proximaFecha,
    required this.etiquetaProxima,
    required this.sugerirReiniciar,
  });

  factory PrevisualizacionDosis.desdeFila(Map<String, dynamic> f) =>
      PrevisualizacionDosis(
        posicion: f['posicion'] as int,
        dosisSerie: f['dosis_serie'] as int,
        etiquetaDosis: (f['etiqueta_dosis'] as String?) ?? '',
        proximaFecha: _fecha(f['proxima_fecha']),
        etiquetaProxima: (f['etiqueta_proxima'] as String?) ?? '',
        sugerirReiniciar: (f['sugerir_reiniciar'] as bool?) ?? false,
      );

  final int posicion;
  final int dosisSerie;
  final String etiquetaDosis;
  final DateTime? proximaFecha;
  final String etiquetaProxima;
  final bool sugerirReiniciar;
}

/// Fila de `vacunas_pendientes` (lista de alertas de toda la clínica).
class PendienteVacuna {
  const PendienteVacuna({
    required this.mascotaId,
    required this.mascotaNombre,
    required this.mascotaEspecie,
    this.mascotaFotoPath,
    required this.clienteId,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.codigoProtocolo,
    required this.biologicoNombre,
    required this.tipo,
    required this.ultimaDosisId,
    required this.posicion,
    required this.dosisSerie,
    required this.etiquetaProxima,
    required this.proximaFecha,
    required this.estado,
    required this.diasVencida,
    this.recordatorioEnviadoAt,
  });

  factory PendienteVacuna.desdeFila(Map<String, dynamic> f) => PendienteVacuna(
    mascotaId: f['mascota_id'] as String,
    mascotaNombre: f['mascota_nombre'] as String,
    mascotaEspecie: f['mascota_especie'] as String,
    mascotaFotoPath: f['mascota_foto_path'] as String?,
    clienteId: f['cliente_id'] as String,
    clienteNombre: (f['cliente_nombre'] as String?) ?? '',
    clienteTelefono: (f['cliente_telefono'] as String?) ?? '',
    codigoProtocolo: f['codigo_protocolo'] as String,
    biologicoNombre: f['biologico_nombre'] as String,
    tipo: tipoDosisDe(f['tipo'] as String),
    ultimaDosisId: f['ultima_dosis_id'] as String,
    posicion: f['posicion'] as int,
    dosisSerie: f['dosis_serie'] as int,
    etiquetaProxima: (f['etiqueta_proxima'] as String?) ?? '',
    proximaFecha: fechaDeBd(f['proxima_fecha'] as String),
    estado: estadoCarneDe(f['estado'] as String),
    diasVencida: (f['dias_vencida'] as int?) ?? 0,
    recordatorioEnviadoAt: _instante(f['recordatorio_enviado_at']),
  );

  final String mascotaId;
  final String mascotaNombre;
  final String mascotaEspecie;
  final String? mascotaFotoPath;
  final String clienteId;
  final String clienteNombre;
  final String clienteTelefono;
  final String codigoProtocolo;
  final String biologicoNombre;
  final TipoDosis tipo;
  final String ultimaDosisId;
  final int posicion;
  final int dosisSerie;
  final String etiquetaProxima;
  final DateTime proximaFecha;
  final EstadoCarne estado;
  final int diasVencida;
  final DateTime? recordatorioEnviadoAt;
}

/// Conteos de `vacunas_resumen` para la pantalla de inicio.
class ResumenVacunas {
  const ResumenVacunas({
    required this.vencidas,
    required this.proximas,
    required this.ocultasAntiguas,
  });

  final int vencidas;
  final int proximas;
  final int ocultasAntiguas;
}

/// Conteos por mascota de `vacunas_resumen_mascotas` (insignias de lista).
class ResumenVacunasMascota {
  const ResumenVacunasMascota({required this.vencidas, required this.proximas});

  final int vencidas;
  final int proximas;

  EstadoCarne get peor =>
      vencidas > 0 ? EstadoCarne.vencida : EstadoCarne.proxima;
}
