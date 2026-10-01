import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/utils/zona_bogota.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/providers/recordatorios_providers.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_recordatorios.dart';

final _ahora = deBogota(2026, 9, 30, 9, 35);

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

({
  ProviderContainer c,
  FakeRecordatoriosService svc,
  FakeCitaRepository repo,
  List<String> abiertas,
})
_setup({
  bool permiso = true,
  String? lanzamiento,
  Object? error,
  bool autenticado = true,
}) {
  final svc = FakeRecordatoriosService()
    ..permiso = permiso
    ..lanzamiento = lanzamiento;
  final repo = FakeCitaRepository(citas: citasSemanaFixture, error: error);
  final abiertas = <String>[];
  final c = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: autenticado ? vetProfile : null),
      ),
      citaRepositoryProvider.overrideWithValue(repo),
      recordatoriosServiceProvider.overrideWithValue(svc),
      clockProvider.overrideWithValue(() => _ahora),
      abrirCitaDesdeNotificacionProvider.overrideWithValue(abiertas.add),
    ],
  );
  addTearDown(c.dispose);
  return (c: c, svc: svc, repo: repo, abiertas: abiertas);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('programa las citas futuras pendiente/confirmada 60 min antes', () async {
    final t = _setup();
    t.c.read(recordatoriosSyncProvider);
    await _settle();

    expect(t.svc.reprogramaciones, hasLength(1));
    final planes = t.svc.reprogramaciones.single;
    expect(planes.map((p) => p.citaId), ['cita-2', 'cita-4', 'cita-5']);
    expect(planes.first.cuando, deBogota(2026, 9, 30, 14, 0));
    expect(t.repo.consultasEntre.first.inicio, _ahora);
    expect(
      t.repo.consultasEntre.first.fin,
      _ahora.add(const Duration(days: 30)),
    );
  });

  test('incrementar citasRevision reprograma otra vez', () async {
    final t = _setup();
    t.c.read(recordatoriosSyncProvider);
    await _settle();
    t.c.read(citasRevisionProvider.notifier).incrementar();
    await _settle();
    expect(t.svc.reprogramaciones, hasLength(2));
  });

  test('anticipacion: default 60, cambiar(15) persiste y reprograma', () async {
    final t = _setup();
    t.c.read(recordatoriosSyncProvider);
    await _settle();
    expect(await t.c.read(anticipacionRecordatorioProvider.future), 60);

    await t.c.read(anticipacionRecordatorioProvider.notifier).cambiar(15);
    await _settle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('recordatorio_minutos_antes'), 15);
    expect(t.svc.reprogramaciones.length, greaterThanOrEqualTo(2));
    final ultimo = t.svc.reprogramaciones.last;
    expect(ultimo.first.cuando, deBogota(2026, 9, 30, 10, 15));
    expect(ultimo.first.titulo, 'Cita en 15 min');
  });

  test('cambiar(45) lanza ArgumentError y no persiste', () async {
    final t = _setup();
    await expectLater(
      t.c.read(anticipacionRecordatorioProvider.notifier).cambiar(45),
      throwsArgumentError,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('recordatorio_minutos_antes'), isNull);
  });

  test('cerrar sesion cancela todo una vez y no reprograma mas', () async {
    final t = _setup();
    t.c.read(recordatoriosSyncProvider);
    await _settle();
    final antes = t.svc.reprogramaciones.length;

    await t.c.read(authProfileProvider.notifier).signOut();
    await _settle();

    expect(t.svc.cancelarTodoLlamadas, 1);
    expect(t.svc.reprogramaciones.length, antes);
  });

  test('cerrar sesion con sync en vuelo no reprograma', () async {
    final t = _setup();
    final retener = Completer<void>();
    t.svc.retenerPermiso = retener.future;
    t.c.read(recordatoriosSyncProvider);
    await _settle();
    expect(t.svc.reprogramaciones, isEmpty);

    await t.c.read(authProfileProvider.notifier).signOut();
    await _settle();
    retener.complete();
    await _settle();

    expect(t.svc.reprogramaciones, isEmpty);
    expect(t.svc.cancelarTodoLlamadas, greaterThanOrEqualTo(1));
  });

  test('sin permiso no reprograma', () async {
    final t = _setup(permiso: false);
    t.c.read(recordatoriosSyncProvider);
    await _settle();
    await t.c.read(recordatoriosSyncProvider).sincronizar();
    expect(t.svc.reprogramaciones, isEmpty);
  });

  test('toque y lanzamiento abren la cita', () async {
    final t = _setup(lanzamiento: 'c2');
    t.c.read(recordatoriosSyncProvider);
    await _settle();
    expect(t.abiertas, ['c2']);

    t.svc.simularToque('c1');
    expect(t.abiertas, ['c2', 'c1']);

    // El lanzamiento solo se atiende tras la primera sincronizacion.
    await t.c.read(recordatoriosSyncProvider).sincronizar();
    expect(t.abiertas, ['c2', 'c1']);
  });

  test('un fallo del repositorio se traga', () async {
    final t = _setup(error: Exception('boom'));
    t.c.read(recordatoriosSyncProvider);
    await _settle();
    await t.c.read(recordatoriosSyncProvider).sincronizar();
    expect(t.svc.reprogramaciones, isEmpty);
  });
}
