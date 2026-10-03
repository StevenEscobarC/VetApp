import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/features/vaccination/domain/entities/carne.dart';
import 'package:vetapp/features/vaccination/domain/entities/protocolo.dart';
import 'package:vetapp/features/vaccination/presentation/providers/alertas_providers.dart';
import 'package:vetapp/features/vaccination/presentation/providers/anular_dosis_providers.dart';
import 'package:vetapp/features/vaccination/presentation/providers/dosis_cita_providers.dart';
import 'package:vetapp/features/vaccination/presentation/providers/registrar_dosis_providers.dart';
import 'package:vetapp/features/vaccination/presentation/providers/vacuna_providers.dart';

import 'helpers/fake_vacunas.dart';

final _carne = Carne(
  hoy: DateTime.utc(2026, 10, 2),
  mascotaId: 'm-1',
  mascotaNombre: 'Rocky',
  especie: 'perro',
  raza: 'Labrador',
  duenoNombre: 'Rita Gómez',
  duenoTelefono: '3001112222',
  clinicaNombre: 'Clínica Patitas',
  clinicaCiudad: 'Bogotá',
  biologicos: const [],
  dosis: const [],
);

/// Simula pantallas vivas (la tarjeta de Inicio dentro de la rama del shell,
/// la lista de Pacientes, el carné y "Completar cita"): con un listener
/// activo los providers `autoDispose` nunca se desechan solos, así que solo
/// se refrescan si la mutación los invalida (G4).
ProviderContainer _contenedor(FakeVacunaRepository repo) {
  final c = ProviderContainer(
    overrides: [vacunaRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  c.listen(resumenVacunasProvider, (_, _) {});
  c.listen(vacunasPendientesProvider, (_, _) {});
  c.listen(resumenVacunasMascotasProvider, (_, _) {});
  c.listen(carneProvider('m-1'), (_, _) {});
  c.listen(dosisDeCitaProvider('cita-1'), (_, _) {});
  return c;
}

Future<void> _cargar(ProviderContainer c) async {
  await c.read(resumenVacunasProvider.future);
  await c.read(vacunasPendientesProvider.future);
  await c.read(resumenVacunasMascotasProvider.future);
  await c.read(carneProvider('m-1').future);
  await c.read(dosisDeCitaProvider('cita-1').future);
}

int _veces(FakeVacunaRepository repo, String metodo) =>
    repo.llamadas.where((l) => l.metodo == metodo).length;

void main() {
  test('registrar una dosis refresca Inicio, pendientes, insignias, carné '
      'y las dosis de la cita', () async {
    final repo = FakeVacunaRepository(carnes: {'m-1': _carne});
    final c = _contenedor(repo);
    await _cargar(c);

    await c.read(registrarDosisProvider)(
      mascotaId: 'm-1',
      codigo: 'polivalente',
      biologicoNombre: 'Polivalente',
      fecha: DateTime.utc(2026, 10, 2),
      citaId: 'cita-1',
    );
    await _cargar(c);

    expect(_veces(repo, 'resumen'), 2);
    expect(_veces(repo, 'pendientes'), 2);
    expect(_veces(repo, 'resumenPorMascota'), 2);
    expect(_veces(repo, 'carne'), 2);
    expect(_veces(repo, 'dosisDeCita'), 2);
  });

  test('anular una dosis refresca Inicio, pendientes, insignias y carné', () async {
    final repo = FakeVacunaRepository(carnes: {'m-1': _carne});
    final c = _contenedor(repo);
    await _cargar(c);

    await c.read(anularDosisProvider)(
      mascotaId: 'm-1',
      dosisId: 'd-1',
      motivo: 'Error de registro',
    );
    await _cargar(c);

    expect(_veces(repo, 'resumen'), 2);
    expect(_veces(repo, 'pendientes'), 2);
    expect(_veces(repo, 'resumenPorMascota'), 2);
    expect(_veces(repo, 'carne'), 2);
  });

  test('descartar, posponer y restaurar una alerta refrescan Inicio y '
      'pendientes', () async {
    final repo = FakeVacunaRepository(carnes: {'m-1': _carne});
    final c = _contenedor(repo);
    await _cargar(c);
    final p = PendienteVacuna(
      mascotaId: 'm-1',
      mascotaNombre: 'Rocky',
      mascotaEspecie: 'perro',
      clienteId: 'c-1',
      clienteNombre: 'Rita Gómez',
      clienteTelefono: '3001112222',
      biologicoNombre: 'Polivalente',
      codigoProtocolo: 'polivalente',
      tipo: TipoDosis.vacuna,
      ultimaDosisId: 'd-1',
      posicion: 1,
      dosisSerie: 3,
      etiquetaProxima: 'Dosis 2 de 3',
      proximaFecha: DateTime.utc(2026, 10, 5),
      estado: EstadoCarne.proxima,
      diasVencida: 0,
    );
    final actions = c.read(alertasActionsProvider);

    await actions.descartar(p, 'Otro motivo');
    await _cargar(c);
    await actions.posponer(p, 7);
    await _cargar(c);
    await actions.restaurar(p);
    await _cargar(c);

    expect(_veces(repo, 'resumen'), 4);
    expect(_veces(repo, 'pendientes'), 4);
  });
}
