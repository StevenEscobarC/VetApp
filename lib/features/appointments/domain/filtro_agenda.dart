import 'entities/cita.dart';

/// Qué citas muestra la agenda en una clínica con varios veterinarios.
enum FiltroAgenda { mias, todas }

/// Aplica [filtro] a [citas]. "Mías/Todas" es preferencia de vista, no
/// seguridad (la RLS ya entrega la clínica). Con un solo veterinario
/// ([multiVet] falso) devuelve las citas sin cambios.
List<Cita> citasVisibles(
  List<Cita> citas, {
  required FiltroAgenda filtro,
  required String yoId,
  required bool multiVet,
}) {
  if (!multiVet || filtro == FiltroAgenda.todas) return citas;
  return citas.where((c) => c.veterinarioId == yoId).toList();
}
