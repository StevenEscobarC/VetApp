import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vacuna_providers.dart';

/// Token del enlace permanente del carné; el servidor lo crea de forma
/// perezosa en la primera consulta (D-16).
final enlaceCarneProvider = FutureProvider.autoDispose.family<String, String>((
  ref,
  mascotaId,
) {
  return ref.watch(vacunaRepositoryProvider).enlaceCarne(mascotaId);
});

/// Reemplaza el token (el enlace anterior deja de funcionar) y refresca
/// [enlaceCarneProvider].
class RegenerarEnlaceCarne {
  RegenerarEnlaceCarne(this._ref);

  final Ref _ref;

  Future<String> call(String mascotaId) async {
    final token = await _ref
        .read(vacunaRepositoryProvider)
        .regenerarEnlace(mascotaId);
    _ref.invalidate(enlaceCarneProvider(mascotaId));
    return token;
  }
}

final regenerarEnlaceCarneProvider = Provider<RegenerarEnlaceCarne>(
  (ref) => RegenerarEnlaceCarne(ref),
);
