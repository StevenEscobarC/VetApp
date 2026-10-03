import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alertas_providers.dart';
import 'dosis_cita_providers.dart';
import 'vacuna_providers.dart';

/// Refresca toda lectura derivada de las dosis tras una mutación (registrar,
/// anular): carné de la mascota, insignias de Pacientes, tarjeta de Inicio y
/// lista de pendientes (G4). Los providers son `autoDispose`, pero la rama de
/// Inicio del shell sigue montada, así que sin invalidarlos nunca se recargan.
void invalidarVacunas(Ref ref, {required String mascotaId, String? citaId}) {
  ref.invalidate(carneProvider(mascotaId));
  ref.invalidate(resumenVacunasMascotasProvider);
  invalidarAlertasVacunas(ref);
  if (citaId != null) ref.invalidate(dosisDeCitaProvider(citaId));
}

/// Refresca solo las alertas (Inicio + pendientes): descartar, posponer,
/// restaurar y recordar no cambian el carné ni las insignias (el servidor no
/// los filtra por estado de alerta).
void invalidarAlertasVacunas(Ref ref) {
  ref.invalidate(vacunasPendientesProvider);
  ref.invalidate(resumenVacunasProvider);
}
