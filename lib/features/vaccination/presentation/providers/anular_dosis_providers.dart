import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'invalidar_vacunas.dart';
import 'vacuna_providers.dart';

/// Anula una dosis (D-08): el servidor la marca anulada con motivo y la
/// recalcula el carné; nada se borra ni se edita. Tras anular, refresca el
/// carné, las insignias, Inicio y pendientes ([invalidarVacunas]).
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
    invalidarVacunas(_ref, mascotaId: mascotaId);
  }
}

final anularDosisProvider = Provider<AnularDosis>((ref) => AnularDosis(ref));
