import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/utils/lanzador_externo.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/vaccination/domain/entities/carne.dart';
import 'package:vetapp/features/vaccination/domain/entities/protocolo.dart';
import 'package:vetapp/features/vaccination/presentation/providers/vacuna_providers.dart';
import 'package:vetapp/features/vaccination/presentation/vacunacion_routes.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_url_launcher.dart';
import 'helpers/fake_vacunas.dart';
import 'helpers/router_harness.dart';

PendienteVacuna _p({
  required String id,
  required String mascota,
  String especie = 'perro',
  String cliente = 'Rita Gómez',
  String telefono = '3001112222',
  String codigo = 'polivalente',
  String biologico = 'Polivalente',
  TipoDosis tipo = TipoDosis.vacuna,
  String etiqueta = 'Dosis 2 de 3',
  required DateTime proxima,
  required EstadoCarne estado,
  int diasVencida = 0,
  DateTime? enviado,
}) => PendienteVacuna(
  mascotaId: 'm-$id',
  mascotaNombre: mascota,
  mascotaEspecie: especie,
  clienteId: 'c-$id',
  clienteNombre: cliente,
  clienteTelefono: telefono,
  codigoProtocolo: codigo,
  biologicoNombre: biologico,
  tipo: tipo,
  ultimaDosisId: 'd-$id',
  posicion: 1,
  dosisSerie: 3,
  etiquetaProxima: etiqueta,
  proximaFecha: proxima,
  estado: estado,
  diasVencida: diasVencida,
  recordatorioEnviadoAt: enviado,
);

final _rocky = _p(
  id: 'rocky',
  mascota: 'Rocky',
  proxima: DateTime.utc(2026, 9, 12),
  estado: EstadoCarne.vencida,
  diasVencida: 19,
);
final _misu = _p(
  id: 'misu',
  mascota: 'Misu',
  especie: 'gato',
  cliente: 'Sin Teléfono',
  telefono: '',
  codigo: 'antirrabica',
  biologico: 'Antirrábica',
  etiqueta: 'Refuerzo',
  proxima: DateTime.utc(2026, 9, 28),
  estado: EstadoCarne.vencida,
  diasVencida: 3,
);
final _luna = _p(
  id: 'luna',
  mascota: 'Luna',
  cliente: 'Ana Ruiz',
  codigo: 'desp_interna',
  biologico: 'Desparasitación interna',
  tipo: TipoDosis.desparasitacionInterna,
  etiqueta: 'Refuerzo',
  proxima: DateTime.utc(2026, 10, 5),
  estado: EstadoCarne.proxima,
);

/// Repo cuyo `pendientes()` refleja el "recordatorio enviado" ya marcado.
class _Repo extends FakeVacunaRepository {
  _Repo({
    super.pendientesData,
    super.resumenData,
    super.error,
    super.errorGestionar,
  });

  bool recordado = false;

  @override
  Future<List<PendienteVacuna>> pendientes() async {
    final l = await super.pendientes();
    if (!recordado) return l;
    return [
      for (final p in l)
        if (p.mascotaId == 'm-rocky')
          _p(
            id: 'rocky',
            mascota: 'Rocky',
            proxima: p.proximaFecha,
            estado: p.estado,
            diasVencida: p.diasVencida,
            enviado: DateTime.utc(2026, 10, 1, 17),
          )
        else
          p,
    ];
  }

  @override
  Future<void> gestionarAlerta({
    required String dosisRefId,
    required AccionAlerta accion,
    String? motivo,
    int? dias,
  }) async {
    await super.gestionarAlerta(
      dosisRefId: dosisRefId,
      accion: accion,
      motivo: motivo,
      dias: dias,
    );
    if (accion == AccionAlerta.recordado) recordado = true;
  }
}

Widget _app(_Repo repo, FakeLanzadorExterno lanzador) => routerHarness(
  initialLocation: '/vacunas',
  routes: [
    vacunacionRoutes.firstWhere((r) => r.path == '/vacunas'),
    GoRoute(
      path: '/dosis/nueva',
      builder: (_, s) => Scaffold(body: Text('DOSIS ${s.uri}')),
    ),
    GoRoute(
      path: '/agenda/nueva',
      builder: (_, s) => Scaffold(body: Text('RUTA ${s.uri}')),
    ),
    GoRoute(
      path: '/pacientes/:id/carne',
      builder: (_, s) => Scaffold(body: Text('CARNE ${s.uri}')),
    ),
  ],
  overrides: [
    authProfileProvider.overrideWith(
      () => FakeAuthProfileNotifier(profile: vetProfile),
    ),
    vacunaRepositoryProvider.overrideWithValue(repo),
    lanzadorExternoProvider.overrideWithValue(lanzador),
    clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 1, 17)),
  ],
);

_Repo _repoTodos({int ocultas = 0, Object? errorGestionar}) => _Repo(
  pendientesData: [_rocky, _misu, _luna],
  resumenData: ResumenVacunas(
    vencidas: 2,
    proximas: 1,
    ocultasAntiguas: ocultas,
  ),
  errorGestionar: errorGestionar,
);

Future<void> _abrir(
  WidgetTester tester,
  _Repo repo, [
  FakeLanzadorExterno? lanzador,
]) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(repo, lanzador ?? FakeLanzadorExterno()));
  await tester.pumpAndSettle();
}

Finder _boton(String tile, String label) => find.descendant(
  of: find.ancestor(of: find.text(tile), matching: find.byType(Card)).first,
  matching: find.text(label),
);

void main() {
  testWidgets('agrupa vencidas (más vencida primero) y próximas', (
    tester,
  ) async {
    await _abrir(tester, _repoTodos());
    expect(find.text('Vacunas pendientes'), findsOneWidget);
    expect(find.text('Vencidas (2)'), findsOneWidget);
    expect(find.text('Próximas (1)'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Rocky')).dy,
      lessThan(tester.getTopLeft(find.text('Misu')).dy),
    );
    expect(find.text('Polivalente · Dosis 2 de 3'), findsOneWidget);
    expect(find.text('Antirrábica · Refuerzo'), findsOneWidget);
    expect(find.text('Venció el 12/09/2026 · hace 19 días'), findsOneWidget);
    expect(find.text('Venció el 28/09/2026 · hace 3 días'), findsOneWidget);
    expect(find.text('Vence el 05/10/2026 · en 4 días'), findsOneWidget);
    expect(find.text('Rita Gómez'), findsOneWidget);
    expect(find.text('Vencida'), findsNWidgets(2));
    expect(find.text('Próxima'), findsOneWidget);
  });

  testWidgets('pie de ocultas solo si hay vencidas antiguas', (tester) async {
    const pie =
        'Se ocultan las vacunas vencidas hace más de 6 meses. Siguen marcadas en cada carné.';
    await _abrir(tester, _repoTodos(ocultas: 2));
    expect(find.text(pie), findsOneWidget);
    await _abrir(tester, _repoTodos());
    expect(find.text(pie), findsNothing);
  });

  testWidgets('sin alertas muestra Todo al día', (tester) async {
    await _abrir(tester, _Repo());
    expect(find.text('Todo al día'), findsOneWidget);
    expect(
      find.text('No hay vacunas vencidas ni próximas en la clínica.'),
      findsOneWidget,
    );
  });

  testWidgets('error muestra mensaje y Reintentar', (tester) async {
    await _abrir(tester, _Repo(error: Exception('x')));
    expect(
      find.text('No pudimos cargar las alertas. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets(
    'Recordar abre WhatsApp, marca enviado y firma al usuario actual',
    (tester) async {
      final lanzador = FakeLanzadorExterno();
      final repo = _repoTodos();
      await _abrir(tester, repo, lanzador);

      await tester.tap(_boton('Rocky', 'Recordar'));
      await tester.pumpAndSettle();

      expect(lanzador.metodos, ['abrirEnApp']);
      final msg = Uri.decodeComponent(lanzador.abiertos.single.toString());
      expect(msg, contains('Le escribe Dr(a). Ana Ramírez'));
      expect(msg, contains('Rocky'));
      final llamada = repo.llamadas.where((l) => l.metodo == 'gestionarAlerta');
      expect(llamada.single.args['accion'], AccionAlerta.recordado);
      expect(llamada.single.args['dosisRefId'], 'd-rocky');
      expect(find.text('Recordatorio enviado el 01/10/2026'), findsOneWidget);
    },
  );

  testWidgets('Recordar sin abrir WhatsApp no marca nada', (tester) async {
    final lanzador = FakeLanzadorExterno()..resultado = false;
    final repo = _repoTodos();
    await _abrir(tester, repo, lanzador);

    await tester.tap(_boton('Rocky', 'Recordar'));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos abrir WhatsApp.'), findsOneWidget);
    expect(repo.llamadas.where((l) => l.metodo == 'gestionarAlerta'), isEmpty);
    expect(find.textContaining('Recordatorio enviado'), findsNothing);
  });

  testWidgets('dueño sin teléfono: Recordar deshabilitado con aviso', (
    tester,
  ) async {
    await _abrir(tester, _repoTodos());
    expect(find.text('Sin teléfono'), findsOneWidget);
  });

  testWidgets('Agendar abre la cita con cliente, mascota y motivo', (
    tester,
  ) async {
    await _abrir(tester, _repoTodos());
    await tester.tap(_boton('Rocky', 'Agendar'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'RUTA /agenda/nueva?clienteId=c-rocky&mascotaId=m-rocky&motivo=Vacunaci%C3%B3n',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Agendar una desparasitación usa ese motivo', (tester) async {
    await _abrir(tester, _repoTodos());
    await tester.tap(_boton('Luna', 'Agendar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('motivo=Desparasitaci%C3%B3n'), findsOneWidget);
  });

  testWidgets('Registrar abre el formulario con el biológico', (tester) async {
    await _abrir(tester, _repoTodos());
    await tester.tap(_boton('Rocky', 'Registrar'));
    await tester.pumpAndSettle();
    expect(
      find.text('DOSIS /dosis/nueva?mascotaId=m-rocky&codigo=polivalente'),
      findsOneWidget,
    );
  });

  testWidgets('tocar la tarjeta abre el carné', (tester) async {
    await _abrir(tester, _repoTodos());
    await tester.tap(find.text('Polivalente · Dosis 2 de 3'));
    await tester.pumpAndSettle();
    expect(find.text('CARNE /pacientes/m-rocky/carne'), findsOneWidget);
  });

  testWidgets('Posponer 7 días + Aplicar y Deshacer', (tester) async {
    final repo = _repoTodos();
    await _abrir(tester, repo);
    await tester.tap(_boton('Rocky', 'Descartar o posponer'));
    await tester.pumpAndSettle();

    expect(find.text('¿Qué hacemos con esta alerta?'), findsOneWidget);
    for (final t in [
      'Posponer 7 días',
      'Posponer 30 días',
      'Mascota fallecida',
      'Cambió de veterinario',
      'Otro motivo',
    ]) {
      expect(find.text(t), findsOneWidget);
    }
    await tester.tap(find.text('Posponer 7 días'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    final g = repo.llamadas.where((l) => l.metodo == 'gestionarAlerta').single;
    expect(g.args['accion'], AccionAlerta.posponer);
    expect(g.args['dias'], 7);
    expect(find.text('Alerta pospuesta hasta el 08/10/2026'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    final acciones = repo.llamadas
        .where((l) => l.metodo == 'gestionarAlerta')
        .map((l) => l.args['accion'])
        .toList();
    expect(acciones, [AccionAlerta.posponer, AccionAlerta.restaurar]);
  });

  testWidgets('Mascota fallecida descarta con ese motivo', (tester) async {
    final repo = _repoTodos();
    await _abrir(tester, repo);
    await tester.tap(_boton('Rocky', 'Descartar o posponer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mascota fallecida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    final g = repo.llamadas.where((l) => l.metodo == 'gestionarAlerta').single;
    expect(g.args['accion'], AccionAlerta.descartar);
    expect(g.args['motivo'], 'Mascota fallecida');
    expect(find.text('Alerta descartada'), findsOneWidget);
  });

  testWidgets('filtros Perros y Gatos', (tester) async {
    await _abrir(tester, _repoTodos());
    await tester.tap(find.text('Gatos'));
    await tester.pumpAndSettle();
    expect(find.text('Misu'), findsOneWidget);
    expect(find.text('Rocky'), findsNothing);
    expect(find.text('Vencidas (1)'), findsOneWidget);
    expect(find.textContaining('Próximas ('), findsNothing);

    await tester.tap(find.text('Perros'));
    await tester.pumpAndSettle();
    expect(find.text('Misu'), findsNothing);
    expect(find.text('Rocky'), findsOneWidget);
    expect(find.text('Luna'), findsOneWidget);

    await tester.tap(find.text('Todas'));
    await tester.pumpAndSettle();
    expect(find.text('Misu'), findsOneWidget);
  });
}
