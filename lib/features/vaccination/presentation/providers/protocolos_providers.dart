import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/protocolo.dart';
import 'vacuna_providers.dart';

/// Escrituras del catálogo de protocolos. Cada una invalida el catálogo para
/// que la lista y las próximas dosis (derivadas en el servidor, D-02) se
/// refresquen.
class ProtocolosActions {
  ProtocolosActions(this._ref);

  final Ref _ref;

  Future<String> guardar({
    String? codigo,
    required String nombre,
    required TipoDosis tipo,
    required List<String> especies,
    required int dosisSerie,
    int? intervaloSerieDias,
    int? intervaloRefuerzoDias,
    required List<int> opcionesDuracionDias,
  }) async {
    final r = await _ref
        .read(vacunaRepositoryProvider)
        .guardarProtocolo(
          codigo: codigo,
          nombre: nombre,
          tipo: tipo,
          especies: especies,
          dosisSerie: dosisSerie,
          intervaloSerieDias: intervaloSerieDias,
          intervaloRefuerzoDias: intervaloRefuerzoDias,
          opcionesDuracionDias: opcionesDuracionDias,
        );
    _ref.invalidate(protocolosProvider);
    return r;
  }

  Future<void> restablecer(String codigo) async {
    await _ref.read(vacunaRepositoryProvider).restablecerProtocolo(codigo);
    _ref.invalidate(protocolosProvider);
  }

  Future<void> desactivar(String codigo) async {
    await _ref.read(vacunaRepositoryProvider).desactivarProtocolo(codigo);
    _ref.invalidate(protocolosProvider);
  }
}

final protocolosActionsProvider = Provider<ProtocolosActions>(
  (ref) => ProtocolosActions(ref),
);

/// Solo administradores editan el catálogo (D-24). En una clínica de un solo
/// veterinario ese veterinario es administrador (4.1 D-04). El servidor es la
/// autoridad; esto solo oculta acciones.
final puedeEditarProtocolosProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(authProfileProvider).value?.esAdmin ?? false,
);
