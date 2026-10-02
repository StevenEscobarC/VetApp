import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formato.dart';
import '../../domain/entities/carne.dart';
import 'vacuna_providers.dart';

/// Resultado de registrar una dosis: lo recibe quien abrió `/dosis/nueva`
/// para mostrar la confirmación. [proximaFecha] la calcula el servidor (D-02).
class DosisRegistrada {
  const DosisRegistrada({
    required this.mascotaId,
    required this.biologicoNombre,
    this.proximaFecha,
  });

  final String mascotaId;
  final String biologicoNombre;
  final DateTime? proximaFecha;
}

/// Registra una dosis (VAC-01): una sola llamada al repositorio, luego
/// invalida lo que cambió y lee la próxima fecha del carné ya refrescado —
/// nunca la calcula en Dart. Guarda el [Ref] (no `WidgetRef`), por eso el
/// provider no es `autoDispose`.
class RegistrarDosis {
  RegistrarDosis(this._ref);

  final Ref _ref;

  Future<DosisRegistrada> call({
    required String mascotaId,
    required String codigo,
    required String biologicoNombre,
    required DateTime fecha,
    int? duracionDias,
    bool sinRefuerzo = false,
    bool esRefuerzo = false,
    bool iniciaSerie = false,
    bool externa = false,
    String? clinicaExterna,
    String? producto,
    String? lote,
    String? observaciones,
    String? citaId,
    bool guardarEnCatalogo = false,
  }) async {
    final nombre = biologicoNombre.trim();
    await _ref
        .read(vacunaRepositoryProvider)
        .registrarDosis(
          mascotaId: mascotaId,
          codigo: codigo,
          biologicoNombre: nombre,
          fecha: fecha,
          duracionDias: duracionDias,
          sinRefuerzo: sinRefuerzo,
          esRefuerzo: esRefuerzo,
          iniciaSerie: iniciaSerie,
          externa: externa,
          clinicaExterna: blancoANull(clinicaExterna),
          producto: blancoANull(producto),
          lote: blancoANull(lote),
          observaciones: blancoANull(observaciones),
          citaId: citaId,
          guardarEnCatalogo: guardarEnCatalogo,
        );
    _ref.invalidate(carneProvider(mascotaId));
    _ref.invalidate(resumenVacunasMascotasProvider);
    DateTime? proxima;
    try {
      final carne = await _ref.read(carneProvider(mascotaId).future);
      for (final b in carne.biologicos) {
        if (b.codigoProtocolo == codigo) proxima = b.proximaFecha;
      }
    } catch (_) {
      // La dosis ya quedó guardada; sin carné solo se omite la próxima fecha.
    }
    return DosisRegistrada(
      mascotaId: mascotaId,
      biologicoNombre: nombre,
      proximaFecha: proxima,
    );
  }
}

final registrarDosisProvider = Provider<RegistrarDosis>(
  (ref) => RegistrarDosis(ref),
);

/// Parámetros de la vista previa de la próxima dosis.
typedef ParamsPrevisualizacion = ({
  String mascotaId,
  String codigo,
  DateTime fecha,
  int? duracionDias,
  bool sinRefuerzo,
  bool esRefuerzo,
  bool iniciaSerie,
});

/// Próxima dosis calculada por el servidor sin insertar nada. `null` para un
/// biológico "Otro" mientras no tenga intervalo elegido.
final previsualizacionDosisProvider = FutureProvider.autoDispose
    .family<PrevisualizacionDosis?, ParamsPrevisualizacion>((ref, p) {
      if (p.codigo.startsWith('otro:') &&
          p.duracionDias == null &&
          !p.sinRefuerzo) {
        return null;
      }
      return ref
          .watch(vacunaRepositoryProvider)
          .previsualizar(
            mascotaId: p.mascotaId,
            codigo: p.codigo,
            fecha: p.fecha,
            duracionDias: p.duracionDias,
            sinRefuerzo: p.sinRefuerzo,
            esRefuerzo: p.esRefuerzo,
            iniciaSerie: p.iniciaSerie,
          );
    });

/// Últimos productos/lotes usados en la clínica (máx. 5) para autocompletar.
final productosRecientesProvider =
    FutureProvider.autoDispose<List<({String producto, String? lote})>>((ref) {
      return ref.watch(vacunaRepositoryProvider).productosRecientes();
    });
