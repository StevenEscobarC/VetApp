import '../../../core/utils/formato.dart';
import '../domain/mi_plan.dart';

/// Estilo visual de una insignia de plan (UI-SPEC "Plan state style map").
enum EstiloPlan { activo, gratis, prueba, beta, alerta, soloLectura }

/// Umbral de "últimos días" que muestra la insignia en alerta. Solo
/// presentacional: los días los entrega el servidor.
const int kDiasAlerta = 7;

String nombrePlan(PlanTipo plan) => switch (plan) {
  PlanTipo.gratis => 'Plan Gratis',
  PlanTipo.pro => 'Plan Pro',
  PlanTipo.clinica => 'Plan Clínica',
  PlanTipo.beta => 'Plan Beta',
};

/// 0 -> "último día", 1 -> "1 día", n -> "n días".
String textoDias(int n) => switch (n) {
  0 => 'último día',
  1 => '1 día',
  _ => '$n días',
};

String _nombrePrueba(OrigenPlan o) =>
    o == OrigenPlan.pruebaClinica ? 'Prueba Clínica' : 'Prueba Pro';

/// Etiqueta y estilo de la insignia del plan (fila de Más y chips).
({String texto, EstiloPlan estilo}) insigniaPlan(MiPlan p) {
  if (!p.puedeEscribir) {
    return (texto: 'Solo lectura', estilo: EstiloPlan.soloLectura);
  }
  final dias = p.diasRestantes;
  if (p.estado == EstadoPlan.gracia) {
    return (
      texto: dias == null ? 'Gracia' : 'Gracia · ${textoDias(dias)}',
      estilo: EstiloPlan.alerta,
    );
  }
  final conFecha = p.estado == EstadoPlan.vigente && dias != null;
  final ultimos = conFecha && dias <= kDiasAlerta;
  if (p.esPrueba) {
    final nombre = _nombrePrueba(p.origen);
    return (
      texto: conFecha ? '$nombre · ${textoDias(dias)}' : nombre,
      estilo: ultimos ? EstiloPlan.alerta : EstiloPlan.prueba,
    );
  }
  switch (p.plan) {
    case PlanTipo.gratis:
      return (texto: 'Plan Gratis', estilo: EstiloPlan.gratis);
    case PlanTipo.beta:
      return (
        texto: p.fundador ? 'Beta · Fundador' : 'Beta',
        estilo: EstiloPlan.beta,
      );
    case PlanTipo.pro:
    case PlanTipo.clinica:
      final nombre = nombrePlan(p.plan);
      if (ultimos) {
        return (
          texto: '$nombre · ${textoDias(dias)}',
          estilo: EstiloPlan.alerta,
        );
      }
      return (
        texto: p.fundador ? '$nombre · Fundador' : nombre,
        estilo: EstiloPlan.activo,
      );
  }
}

String _fecha(DateTime? f) => f == null ? '' : formatearFecha(f);

/// Líneas de vigencia de la tarjeta del plan (UI-SPEC §2 filas 3, 4 y 5).
({String linea, String detalle, String? nota}) lineasVigencia(MiPlan p) {
  final dias = p.diasRestantes;
  final tieneFecha = p.vigenteHasta != null;

  if (p.estado == EstadoPlan.gracia) {
    final consecuencia = p.hayColegas
        ? 'Después, tus colegas quedarán en solo lectura.'
        : 'Después volverás al plan Gratis.';
    final gracia = dias == null
        ? 'Tienes días de gracia'
        : dias == 0
        ? 'Hoy es tu último día de gracia'
        : 'Tienes ${textoDias(dias)} de gracia';
    final hasta = p.graciaHasta == null
        ? ''
        : ', hasta el ${_fecha(p.graciaHasta)}';
    return (
      linea: tieneFecha
          ? 'Venció el ${_fecha(p.vigenteHasta)}'
          : 'Tu plan venció',
      detalle: '$gracia$hasta. $consecuencia',
      nota: null,
    );
  }

  if (p.plan == PlanTipo.gratis) {
    final ultimaPrueba =
        p.ultimoVencimiento != null &&
        (p.ultimoOrigen == OrigenPlan.pruebaPro ||
            p.ultimoOrigen == OrigenPlan.pruebaClinica);
    return (
      linea: 'Plan sin vencimiento',
      detalle: 'Hasta ${p.pacientesMax ?? 50} pacientes y 1 veterinario.',
      nota: ultimaPrueba
          ? 'Tu prueba terminó el ${_fecha(p.ultimoVencimiento)}. '
                'Tus datos están intactos.'
          : null,
    );
  }

  if (p.plan == PlanTipo.beta) {
    return (
      linea: tieneFecha
          ? 'Acceso Beta hasta el ${_fecha(p.vigenteHasta)}'
          : 'Acceso Beta completo',
      detalle: 'Todo está habilitado durante la Beta.',
      nota: null,
    );
  }

  if (!tieneFecha) {
    return (
      linea: p.fundador ? 'Plan Fundador' : 'Plan activo',
      detalle: 'Sin fecha de vencimiento.',
      nota: null,
    );
  }

  final prueba = p.esPrueba;
  final quedan = dias == null
      ? ''
      : dias == 0
      ? 'Último día.'
      : 'Te quedan ${textoDias(dias)}.';
  final detalle = prueba
      ? (quedan.isEmpty ? 'Sin tarjeta.' : '$quedan Sin tarjeta.')
      : quedan;
  return (
    linea: prueba
        ? '${_nombrePrueba(p.origen)} hasta el ${_fecha(p.vigenteHasta)}'
        : 'Activo hasta el ${_fecha(p.vigenteHasta)}',
    detalle: detalle,
    nota: null,
  );
}
