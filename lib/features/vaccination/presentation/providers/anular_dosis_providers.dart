import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vacuna_providers.dart';

/// Anula una dosis (D-08): el servidor la marca anulada con motivo y la
/// recalcula el carné; nada se borra ni se edita. Tras anular, invalida el
/// carné y las insignias de la lista.
class AnularDosis {
  AnularDosis(this._ref);

  final Ref _ref;

  Future<void> call({
    required String mascotaId,
    required String dosisId,
    required String motivo,
  }) async {
    await _ref
        .read(vacunaRepositoryProvider)
        .anularDosis(dosisId: dosisId, motivo: motivo);
    _ref.invalidate(carneProvider(mascotaId));
    _ref.invalidate(resumenVacunasMascotasProvider);
  }
}

final anularDosisProvider = Provider<AnularDosis>((ref) => AnularDosis(ref));
