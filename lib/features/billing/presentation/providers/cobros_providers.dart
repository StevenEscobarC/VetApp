import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/supabase_client_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../inventory/presentation/providers/inventario_providers.dart';
import '../../data/repositories/supabase_cobros_repository.dart';
import '../../domain/entities/cobro.dart';
import '../../domain/entities/cobro_item.dart';
import '../../domain/entities/servicio.dart';

final cobrosRepositoryProvider = Provider<SupabaseCobrosRepository>((ref) {
  return SupabaseCobrosRepository(ref.watch(supabaseClientProvider));
});

/// Tipo de documento y, opcionalmente, estado ("Pendientes", "Pagadas").
typedef FiltroCobros = ({TipoCobro tipo, EstadoCobro? estado});

/// Documentos de un tipo (cotizaciones o cuentas de cobro); con estado, el
/// filtro lo aplica el servidor (WR-02).
final cobrosProvider = FutureProvider.autoDispose
    .family<List<Cobro>, FiltroCobros>((ref, f) {
      return ref
          .watch(cobrosRepositoryProvider)
          .cobros(f.tipo, estado: f.estado);
    });

/// Un documento por id; `null` si no existe o no es visible.
final cobroProvider = FutureProvider.autoDispose.family<Cobro?, String>((
  ref,
  id,
) {
  return ref.watch(cobrosRepositoryProvider).cobro(id);
});

/// Cifras de la tarjeta de Inicio y del encabezado de la lista.
final resumenCobrosProvider = FutureProvider.autoDispose<ResumenCobros>((ref) {
  return ref.watch(cobrosRepositoryProvider).resumen();
});

/// Catálogo de servicios activos de la clínica.
final serviciosProvider = FutureProvider.autoDispose<List<Servicio>>((ref) {
  return ref.watch(cobrosRepositoryProvider).servicios();
});

/// Cuenta de cobro activa de una cita o consulta.
final cobroVinculadoProvider = FutureProvider.autoDispose
    .family<CobroVinculado?, ({String? citaId, String? consultaId})>((
      ref,
      visita,
    ) {
      return ref
          .watch(cobrosRepositoryProvider)
          .cobroVinculado(citaId: visita.citaId, consultaId: visita.consultaId);
    });

/// Datos para generar el PDF de un documento.
final datosPdfCobroProvider = FutureProvider.autoDispose
    .family<({Cobro cobro, ClinicaCobroPdf clinica}), String>((ref, id) {
      return ref.watch(cobrosRepositoryProvider).datosPdf(id);
    });

/// Solo los administradores editan el catálogo de servicios. Cortesía: el
/// servidor es la autoridad (42501).
final puedeAdministrarServiciosProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(authProfileProvider).value?.esAdmin ?? false,
);

/// Anula el administrador o quien emitió el documento ([creadoPor]).
/// Cortesía: el servidor es la autoridad (42501).
final puedeAnularCobroProvider = Provider.autoDispose.family<bool, String>((
  ref,
  creadoPor,
) {
  final perfil = ref.watch(authProfileProvider).value;
  if (perfil == null) return false;
  return perfil.esAdmin || perfil.id == creadoPor;
});

/// Refresca toda lectura de cobros y el inventario de los [productoIds]
/// involucrados. Los providers son `autoDispose`, pero las pantallas vivas
/// (Inicio, lista) los mantienen montados: sin invalidarlos nunca recargan.
void invalidarCobros(
  Ref ref, {
  String? cobroId,
  Iterable<String> productoIds = const [],
  String? otroCobroId,
}) {
  ref.invalidate(cobrosProvider);
  ref.invalidate(resumenCobrosProvider);
  ref.invalidate(cobroVinculadoProvider);
  if (cobroId != null) {
    ref.invalidate(cobroProvider(cobroId));
    ref.invalidate(datosPdfCobroProvider(cobroId));
  }
  if (otroCobroId != null) {
    ref.invalidate(cobroProvider(otroCobroId));
    ref.invalidate(datosPdfCobroProvider(otroCobroId));
  }
  final ids = productoIds.toSet();
  for (final id in ids) {
    invalidarInventario(ref, productoId: id);
  }
  if (ids.isNotEmpty) invalidarInventario(ref);
}

Set<String> _productosDe(List<LineaCobroNueva> lineas) => {
  for (final l in lineas)
    if (l.tipo == TipoLinea.producto && l.productoId != null) l.productoId!,
};

final cobrosActionsProvider = Provider<CobrosActions>(CobrosActions.new);

/// Escrituras de cobros. Nunca envían total ni número: el servidor los
/// decide.
///
/// A diferencia del inventario, cada acción invalida en un `finally`, en
/// éxito y en CUALQUIER fallo (lección WR-03): tras un timeout el servidor
/// pudo haber confirmado, y la clave de idempotencia hace seguro reintentar.
class CobrosActions {
  CobrosActions(this._ref);

  final Ref _ref;

  SupabaseCobrosRepository get _repo => _ref.read(cobrosRepositoryProvider);

  /// Con [cotizacionId] convierte esa cotización (su detalle también se
  /// refresca).
  Future<ResultadoCobro> emitirCuentaCobro({
    required String clave,
    required String clienteId,
    required List<LineaCobroNueva> lineas,
    String? mascotaId,
    String? citaId,
    String? consultaId,
    String? cotizacionId,
  }) async {
    String? id;
    try {
      final r = await _repo.crearCuentaCobro(
        clave: clave,
        clienteId: clienteId,
        lineas: lineas,
        mascotaId: mascotaId,
        citaId: citaId,
        consultaId: consultaId,
        cotizacionId: cotizacionId,
      );
      id = r.id;
      return r;
    } finally {
      invalidarCobros(
        _ref,
        cobroId: id,
        productoIds: _productosDe(lineas),
        otroCobroId: cotizacionId,
      );
    }
  }

  Future<ResultadoCobro> guardarCotizacion({
    required String clave,
    required String clienteId,
    required List<LineaCobroNueva> lineas,
    String? mascotaId,
  }) async {
    String? id;
    try {
      final r = await _repo.crearCotizacion(
        clave: clave,
        clienteId: clienteId,
        lineas: lineas,
        mascotaId: mascotaId,
      );
      id = r.id;
      return r;
    } finally {
      invalidarCobros(_ref, cobroId: id, productoIds: _productosDe(lineas));
    }
  }

  Future<void> editarCotizacion({
    required String id,
    required String clienteId,
    required List<LineaCobroNueva> lineas,
    String? mascotaId,
  }) async {
    try {
      await _repo.editarCotizacion(
        id: id,
        clienteId: clienteId,
        lineas: lineas,
        mascotaId: mascotaId,
      );
    } finally {
      invalidarCobros(_ref, cobroId: id, productoIds: _productosDe(lineas));
    }
  }

  Future<void> marcarPagado({
    required Cobro cobro,
    required MetodoPago metodo,
    DateTime? fecha,
  }) async {
    try {
      await _repo.marcarPagado(id: cobro.id, metodo: metodo, fecha: fecha);
    } finally {
      invalidarCobros(_ref, cobroId: cobro.id);
    }
  }

  /// Anular devuelve el stock: se refresca el inventario de cada producto.
  Future<void> anular({required Cobro cobro, required String motivo}) async {
    try {
      await _repo.anular(id: cobro.id, motivo: motivo);
    } finally {
      invalidarCobros(
        _ref,
        cobroId: cobro.id,
        productoIds: cobro.productoIds,
        otroCobroId: cobro.cotizacionOrigenId,
      );
    }
  }

  Future<String> guardarServicio({
    String? id,
    required String nombre,
    required int precioCop,
  }) async {
    try {
      return await _repo.guardarServicio(
        id: id,
        nombre: nombre,
        precioCop: precioCop,
      );
    } finally {
      _ref.invalidate(serviciosProvider);
      invalidarCobros(_ref);
    }
  }

  Future<void> archivarServicio(String id) async {
    try {
      await _repo.archivarServicio(id);
    } finally {
      _ref.invalidate(serviciosProvider);
      invalidarCobros(_ref);
    }
  }
}
