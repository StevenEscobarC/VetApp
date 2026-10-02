import 'entities/consulta.dart';

/// `true` si el autor de [c] ya no es miembro activo de la clínica: marcado
/// inactivo en el embed, o ausente de [idsActivos] (D-13). Con [idsActivos]
/// nulo (equipo cargando o con error) nunca se fuerza la línea.
bool autorRetirado(Consulta c, Set<String>? idsActivos) =>
    c.veterinarioActivo == false ||
    (idsActivos != null && !idsActivos.contains(c.veterinarioId));

/// `true` si el autor de [c] es miembro activo conocido de la clínica.
bool autorEsMiembroActivo(Consulta c, Set<String>? idsActivos) =>
    !autorRetirado(c, idsActivos);

/// Regla de visibilidad de la línea "Atendió: Dr(a). X" (TEAM-03): en clínica
/// multi-veterinario siempre (D-00); en clínica de un solo veterinario solo si
/// el autor está retirado o ya no es miembro, para no perder la autoría (D-05,
/// D-13).
bool debeMostrarAutor(
  Consulta c, {
  required bool multiVet,
  Set<String>? idsActivos,
}) => multiVet || autorRetirado(c, idsActivos);
