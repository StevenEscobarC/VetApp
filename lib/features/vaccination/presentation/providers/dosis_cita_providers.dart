import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vacuna_providers.dart';

/// Dosis registradas contra una cita (D-22): "Completar cita" las usa para
/// reemplazar la oferta "Registrar dosis aplicada" por "Dosis registrada".
final dosisDeCitaProvider = FutureProvider.autoDispose
    .family<List<({String mascotaId, String biologicoNombre})>, String>((
      ref,
      citaId,
    ) {
      return ref.watch(vacunaRepositoryProvider).dosisDeCita(citaId);
    });
