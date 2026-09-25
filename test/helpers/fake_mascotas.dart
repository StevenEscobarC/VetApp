import 'package:vetapp/features/patients/data/repositories/supabase_mascota_repository.dart';
import 'package:vetapp/features/patients/domain/entities/mascota.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';

/// In-memory [SupabaseMascotaRepository] stand-in so no test in this phase
/// touches a real Supabase client. Mirrors [FakeClienteRepository]'s "fixed
/// data or fixed error" shape (test/helpers/fake_clientes.dart). [registros]
/// logs every [registrarClienteConMascota] call as a named-arg record so
/// tests can assert exactly-once-per-submit and trimmed-values behavior
/// without inspecting a real RPC payload.
class FakeMascotaRepository implements SupabaseMascotaRepository {
  FakeMascotaRepository({
    List<Mascota> mascotas = const [],
    this.error,
    this.resultado = const (clienteId: 'c-nuevo', mascotaId: 'm-nuevo'),
  }) : mascotas = List.of(mascotas);

  final List<Mascota> mascotas;
  final Object? error;
  final ({String clienteId, String mascotaId}) resultado;

  /// Every call to [registrarClienteConMascota], in call order.
  final List<
    ({
      String clienteNombre,
      String clienteTelefono,
      String mascotaNombre,
      Especie mascotaEspecie,
      String? mascotaRaza,
      DateTime? mascotaFechaNacimiento,
      double? mascotaPesoKg,
    })
  >
  registros = [];

  /// mascotaId -> fotoPath, one entry per [actualizarFotoPath] call.
  final Map<String, String> fotoPathsActualizados = {};

  /// (query, clinicaId) pairs, in call order — mirrors
  /// [FakeClienteRepository.busquedas].
  final List<(String, String)> busquedas = [];

  @override
  Future<List<Mascota>> buscar(String query, {required String clinicaId}) async {
    busquedas.add((query, clinicaId));
    if (error != null) throw error!;
    final q = query.trim().toLowerCase();
    final resultado = mascotas
        .where((m) => m.clinicaId == clinicaId)
        .where(
          (m) =>
              q.isEmpty ||
              m.nombre.toLowerCase().contains(q) ||
              m.especie.name.toLowerCase().contains(q) ||
              (m.duenoNombre?.toLowerCase().contains(q) ?? false),
        )
        .toList();
    resultado.sort((a, b) => a.nombre.compareTo(b.nombre));
    return resultado;
  }

  @override
  Future<({String clienteId, String mascotaId})> registrarClienteConMascota({
    required String clienteNombre,
    required String clienteTelefono,
    required String mascotaNombre,
    required Especie mascotaEspecie,
    String? mascotaRaza,
    DateTime? mascotaFechaNacimiento,
    double? mascotaPesoKg,
  }) async {
    registros.add((
      clienteNombre: clienteNombre,
      clienteTelefono: clienteTelefono,
      mascotaNombre: mascotaNombre,
      mascotaEspecie: mascotaEspecie,
      mascotaRaza: mascotaRaza,
      mascotaFechaNacimiento: mascotaFechaNacimiento,
      mascotaPesoKg: mascotaPesoKg,
    ));
    if (error != null) throw error!;
    return resultado;
  }

  @override
  Future<List<Mascota>> porCliente(String clienteId) async {
    if (error != null) throw error!;
    return mascotas.where((m) => m.duenoId == clienteId).toList();
  }

  @override
  Future<void> actualizarFotoPath(String mascotaId, String fotoPath) async {
    if (error != null) throw error!;
    fotoPathsActualizados[mascotaId] = fotoPath;
  }
}

/// Sample mascotas reused verbatim by later plans (07-09) — ids/nombres must
/// not change. All belong to clinicaId 'cli-1'.
const mascotaRocky = Mascota(
  id: 'm-1',
  duenoId: 'c-1',
  clinicaId: 'cli-1',
  nombre: 'Rocky',
  especie: Especie.perro,
  raza: 'Labrador',
  duenoNombre: 'Rita Gómez',
);

const mascotaLuna = Mascota(
  id: 'm-2',
  duenoId: 'c-1',
  clinicaId: 'cli-1',
  nombre: 'Luna',
  especie: Especie.gato,
  duenoNombre: 'Rita Gómez',
);

const mascotaMichi = Mascota(
  id: 'm-3',
  duenoId: 'c-9',
  clinicaId: 'cli-1',
  nombre: 'Michi',
  especie: Especie.gato,
  duenoNombre: 'Otra Persona',
);

/// Fake [MascotasNotifier] for tests that only need a fixed result and no
/// debounce/timer behavior — mirrors [FakeClientesNotifier].
class FakeMascotasNotifier extends MascotasNotifier {
  FakeMascotasNotifier({this.mascotas = const [], this.error});

  final List<Mascota> mascotas;
  final Object? error;

  @override
  Future<List<Mascota>> build() async {
    if (error != null) throw error!;
    return mascotas;
  }
}
