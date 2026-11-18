/// Cifras del mes en curso (zona Bogotá) que muestra Inicio (DASH-01):
/// consultas registradas, ingresos cobrados en COP enteros y pacientes
/// nuevos. Las calcula la RPC `inicio_resumen`; aquí solo se transportan.
class ResumenInicio {
  const ResumenInicio({
    this.consultasMes = 0,
    this.ingresosMes = 0,
    this.pacientesNuevos = 0,
  });

  final int consultasMes;
  final int ingresosMes;
  final int pacientesNuevos;
}
