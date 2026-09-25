import 'package:vetapp/features/patients/data/repositories/supabase_mascota_repository.dart';
import 'package:vetapp/features/patients/domain/entities/mascota.dart';
import 'package:vetapp/features/patients/domain/entities/peso_registro.dart';
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
    Map<String, List<PesoRegistro>> pesosPorMascota = const {},
    this.error,
    this.resultado = const (clienteId: 'c-nuevo', mascotaId: 'm-nuevo'),
  }) : mascotas = List.of(mascotas),
       pesosPorMascota = {
         for (final entry in pesosPorMascota.entries)
           entry.key: List.of(entry.value),
       };

  final List<Mascota> mascotas;
  final Object? error;
  final ({String clienteId, String mascotaId}) resultado;

  /// mascotaId -> historial de peso seedeado (Plan 08) — deliberadamente NO
  /// se ordena aquí: [pesos] lo devuelve tal cual fue seedeado, para que los
  /// tests verifiquen que la pantalla (no el fake) hace el ordenamiento
  /// defensivo por `registradoEn` descendente.
  final Map<String, List<PesoRegistro>> pesosPorMascota;

  /// Every call to [registrarPeso], in call order.
  final List<({String mascotaId, double pesoKg})> pesosRegistrados = [];

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

  /// Every call to [registrarMascota] (D-03: new pet for an existing
  /// owner), in call order.
  final List<
    ({
      String duenoId,
      String nombre,
      Especie especie,
      String? raza,
      DateTime? fechaNacimiento,
      double? pesoKg,
    })
  >
  registrosMascota = [];

  /// Every [Mascota] passed to [actualizar] (PAT-02 edit), in call order.
  final List<Mascota> actualizados = [];

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

  @override
  Future<Mascota> obtener(String id) async {
    if (error != null) throw error!;
    return mascotas.firstWhere((m) => m.id == id);
  }

  @override
  Future<List<PesoRegistro>> pesos(String mascotaId) async {
    if (error != null) throw error!;
    return List.of(pesosPorMascota[mascotaId] ?? const []);
  }

  /// Nuevo pet para un dueño existente (D-03) — siempre devuelve 'm-creada'
  /// salvo que [error] esté fijado.
  @override
  Future<String> registrarMascota({
    required String duenoId,
    required String nombre,
    required Especie especie,
    String? raza,
    DateTime? fechaNacimiento,
    double? pesoKg,
  }) async {
    registrosMascota.add((
      duenoId: duenoId,
      nombre: nombre,
      especie: especie,
      raza: raza,
      fechaNacimiento: fechaNacimiento,
      pesoKg: pesoKg,
    ));
    if (error != null) throw error!;
    return 'm-creada';
  }

  /// Edita una mascota existente (PAT-02) — nunca toca el historial de peso.
  @override
  Future<Mascota> actualizar(Mascota mascota) async {
    actualizados.add(mascota);
    if (error != null) throw error!;
    return mascota;
  }

  @override
  Future<void> registrarPeso(String mascotaId, double pesoKg) async {
    pesosRegistrados.add((mascotaId: mascotaId, pesoKg: pesoKg));
    if (error != null) throw error!;
    final lista = pesosPorMascota.putIfAbsent(mascotaId, () => []);
    lista.add(
      PesoRegistro(
        id: 'p-${lista.length + 1}',
        mascotaId: mascotaId,
        pesoKg: pesoKg,
        registradoEn: DateTime.now(),
      ),
    );
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
  fotoPath: 'cli-1/m-1/1.jpg',
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
