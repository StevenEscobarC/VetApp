import 'package:vetapp/features/clients/data/repositories/supabase_cliente_repository.dart';
import 'package:vetapp/features/clients/domain/cliente_failure.dart';
import 'package:vetapp/features/clients/domain/entities/cliente.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';

/// In-memory [SupabaseClienteRepository] stand-in so no test in this phase
/// touches a real Supabase client. Mirrors [FakeAuthProfileNotifier]'s
/// "fixed data or fixed error" shape (test/helpers/fake_auth.dart).
/// `buscar` does a case-insensitive contains match on nombre/telefono
/// scoped to `clinicaId`, and records every call in [busquedas] so tests can
/// assert on debounce/call-count behavior without inspecting internals.
class FakeClienteRepository implements SupabaseClienteRepository {
  FakeClienteRepository({
    List<Cliente> clientes = const [],
    this.error,
    CodigoVinculacion? codigoResultado,
    this.errorCodigo,
  }) : clientes = List.of(clientes),
       codigoResultado =
           codigoResultado ??
           (
             codigo: '482915',
             expiraEn: DateTime.now().add(const Duration(hours: 24)),
             reemplazoExpirado: false,
           );

  final List<Cliente> clientes;
  final Object? error;

  /// Resultado fijo devuelto por [generarCodigoVinculacion]. Por defecto
  /// '482915', vigente 24h, sin reemplazo.
  final CodigoVinculacion codigoResultado;

  /// Si se establece, [generarCodigoVinculacion] lo lanza en vez de devolver
  /// [codigoResultado].
  final Object? errorCodigo;

  /// (query, clinicaId) pairs, in call order.
  final List<(String, String)> busquedas = [];

  /// Cada [Cliente] pasado a [actualizar], en orden de llamada.
  final List<Cliente> actualizados = [];

  @override
  Future<List<Cliente>> buscar(
    String query, {
    required String clinicaId,
  }) async {
    busquedas.add((query, clinicaId));
    if (error != null) throw error!;
    final q = query.trim().toLowerCase();
    final resultado = clientes
        .where((cliente) => cliente.clinicaId == clinicaId)
        .where(
          (cliente) =>
              q.isEmpty ||
              cliente.nombre.toLowerCase().contains(q) ||
              cliente.telefono.toLowerCase().contains(q),
        )
        .toList();
    resultado.sort((a, b) => a.nombre.compareTo(b.nombre));
    return resultado;
  }

  @override
  Future<Cliente> obtener(String id) async {
    if (error != null) throw error!;
    return clientes.firstWhere(
      (cliente) => cliente.id == id,
      orElse: () => throw const ClienteFailure('No encontramos el cliente.'),
    );
  }

  @override
  Future<Cliente> actualizar(Cliente cliente) async {
    if (error != null) throw error!;
    actualizados.add(cliente);
    final index = clientes.indexWhere((c) => c.id == cliente.id);
    if (index != -1) clientes[index] = cliente;
    return cliente;
  }

  @override
  Future<CodigoVinculacion> generarCodigoVinculacion(String clienteId) async {
    if (errorCodigo != null) throw errorCodigo!;
    return codigoResultado;
  }
}

/// Fake [ClientesNotifier] for tests that only need a fixed result and no
/// debounce/timer behavior (e.g. a screen test not exercising search itself).
class FakeClientesNotifier extends ClientesNotifier {
  FakeClientesNotifier({this.clientes = const [], this.error});

  final List<Cliente> clientes;
  final Object? error;

  @override
  Future<List<Cliente>> build() async {
    if (error != null) throw error!;
    return clientes;
  }
}

/// Sample clientes reused verbatim by Plans 04-09 — ids/nombres/telefonos
/// must not change.
const clienteRita = Cliente(
  id: 'c-1',
  clinicaId: 'cli-1',
  nombre: 'Rita Gómez',
  telefono: '3001234567',
  numeroMascotas: 2,
);

const clientePedro = Cliente(
  id: 'c-2',
  clinicaId: 'cli-1',
  nombre: 'Pedro Ruiz',
  telefono: '3109876543',
);
