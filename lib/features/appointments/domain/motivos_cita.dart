/// Motivos de cita con su duración por defecto (D-01), en el orden de la
/// UI. Elegir un motivo sugiere esa duración; el veterinario puede cambiarla.
const motivosCita = <({String label, int duracionMin})>[
  (label: 'Consulta general', duracionMin: 30),
  (label: 'Vacunación', duracionMin: 15),
  (label: 'Control', duracionMin: 30),
  (label: 'Desparasitación', duracionMin: 15),
  (label: 'Baño/peluquería', duracionMin: 60),
  (label: 'Cirugía', duracionMin: 90),
  (label: 'Otro', duracionMin: 30),
];

/// Duraciones (minutos) ofrecidas como chips; no se escribe a mano.
const duracionesCita = [15, 30, 45, 60, 90, 120];

const motivoPorDefecto = 'Consulta general';

/// Duración sugerida para [motivo]; 30 min si el motivo no está en la tabla.
int duracionPorDefecto(String motivo) {
  for (final m in motivosCita) {
    if (m.label == motivo) return m.duracionMin;
  }
  return 30;
}
