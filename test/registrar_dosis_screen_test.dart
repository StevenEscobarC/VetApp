import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/patients/domain/entities/mascota.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';
import 'package:vetapp/features/vaccination/domain/entities/carne.dart';
import 'package:vetapp/features/vaccination/domain/entities/protocolo.dart';
import 'package:vetapp/features/vaccination/domain/vacuna_failure.dart';
import 'package:vetapp/features/vaccination/presentation/providers/registrar_dosis_providers.dart';
import 'package:vetapp/features/vaccination/presentation/providers/vacuna_providers.dart';
import 'package:vetapp/features/vaccination/presentation/vacunacion_routes.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/fake_vacunas.dart';
import 'helpers/router_harness.dart';

const _rocky = Mascota(
  id: 'm-1',
  duenoId: 'c-1',
  clinicaId: 'cli-1',
  nombre: 'Rocky',
  especie: Especie.perro,
  raza: 'Labrador',
  duenoNombre: 'Rita Gómez',
);

const _polivalente = Protocolo(
  codigo: 'polivalente',
  nombre: 'Polivalente',
  tipo: TipoDosis.vacuna,
  especies: ['perro'],
  dosisSerie: 3,
  intervaloSerieDias: 21,
  intervaloRefuerzoDias: 365,
  opcionesDuracionDias: [],
  personalizado: false,
  esSemilla: true,
  activo: true,
);
const _antirrabica = Protocolo(
  codigo: 'antirrabica',
  nombre: 'Antirrábica',
  tipo: TipoDosis.vacuna,
  especies: ['perro', 'gato'],
  dosisSerie: 1,
  intervaloRefuerzoDias: 365,
  opcionesDuracionDias: [365, 1095],
  personalizado: false,
  esSemilla: true,
  activo: true,
);
const _despInterna = Protocolo(
  codigo: 'desp_interna',
  nombre: 'Desparasitación interna',
  tipo: TipoDosis.desparasitacionInterna,
  especies: ['perro', 'gato'],
  dosisSerie: 1,
  intervaloRefuerzoDias: 90,
  opcionesDuracionDias: [],
  personalizado: false,
  esSemilla: true,
  activo: true,
);
const _felina = Protocolo(
  codigo: 'triple_felina',
  nombre: 'Triple felina',
  tipo: TipoDosis.vacuna,
  especies: ['gato'],
  dosisSerie: 3,
  opcionesDuracionDias: [],
  personalizado: false,
  esSemilla: true,
  activo: true,
);

final _carne = Carne(
  hoy: DateTime.utc(2026, 10, 1),
  mascotaId: 'm-1',
  mascotaNombre: 'Rocky',
  especie: 'perro',
  raza: 'Labrador',
  duenoNombre: 'Rita Gómez',
  duenoTelefono: '3001112222',
  clinicaNombre: 'Clínica Patitas',
  clinicaCiudad: 'Bogotá',
  biologicos: [
    BiologicoCarne(
      codigoProtocolo: 'polivalente',
      biologicoNombre: 'Polivalente',
      tipo: TipoDosis.vacuna,
      ultimaDosisId: 'd-1',
      ultimaFecha: DateTime.utc(2026, 9, 1),
      posicion: 1,
      dosisSerie: 3,
      proximaFecha: DateTime.utc(2026, 10, 5),
      etiquetaProxima: 'Dosis 2 de 3',
      estado: EstadoCarne.proxima,
      diasVencida: 0,
      ventanaDias: 7,
      sugerirReiniciar: false,
    ),
  ],
  dosis: const [],
);

final _preview = PrevisualizacionDosis(
  posicion: 0,
  dosisSerie: 1,
  etiquetaDosis: 'Refuerzo anual',
  proximaFecha: DateTime.utc(2027, 10, 1),
  etiquetaProxima: 'en 1 año',
  sugerirReiniciar: false,
);

DosisRegistrada? _resultado;

Widget _app(
  FakeVacunaRepository repo, {
  String ruta = '/dosis/nueva?mascotaId=m-1',
  AuthProfile? perfil,
  Mascota mascota = _rocky,
}) {
  _resultado = null;
  return routerHarness(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () async {
                  _resultado = await context.push<DosisRegistrada>(ruta);
                },
                child: const Text('Abrir'),
              ),
            ],
          ),
        ),
      ),
      ...vacunacionRoutes,
    ],
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: perfil ?? vetProfile),
      ),
      vacunaRepositoryProvider.overrideWithValue(repo),
      mascotaRepositoryProvider.overrideWithValue(
        FakeMascotaRepository(mascotas: [mascota]),
      ),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 1, 17)),
    ],
  );
}

FakeVacunaRepository _repo({Object? errorRegistrar}) => FakeVacunaRepository(
  carnes: {'m-1': _carne},
  protocolosData: const [_polivalente, _antirrabica, _despInterna, _felina],
  preview: _preview,
  errorRegistrar: errorRegistrar,
);

Future<void> _abrir(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Future<void> _elegir(WidgetTester tester, String nombre) async {
  await tester.tap(find.text('Elige un biológico'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(nombre));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra título, Biológico con hint y fecha de hoy en Bogotá', (
    tester,
  ) async {
    await _abrir(tester, _app(_repo()));
    expect(find.text('Registrar dosis'), findsOneWidget);
    expect(find.text('Biológico'), findsOneWidget);
    expect(find.text('Elige un biológico'), findsOneWidget);
    expect(find.text('Fecha de aplicación'), findsOneWidget);
    expect(find.text('Hoy · 01/10/2026'), findsOneWidget);
    final guardar = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Guardar dosis'),
    );
    expect(guardar.onPressed, isNull);
  });

  testWidgets(
    'el selector lista solo protocolos de perro con pistas y Otro...',
    (tester) async {
      await _abrir(tester, _app(_repo()));
      await tester.tap(find.text('Elige un biológico'));
      await tester.pumpAndSettle();
      expect(find.text('Polivalente'), findsOneWidget);
      expect(find.text('Dosis 2 de 3'), findsOneWidget);
      expect(find.text('Antirrábica'), findsOneWidget);
      expect(find.text('Primera dosis'), findsWidgets);
      expect(find.text('Triple felina'), findsNothing);
      expect(find.text('Otro...'), findsOneWidget);
    },
  );

  testWidgets('Antirrábica muestra chips de duración; Polivalente no', (
    tester,
  ) async {
    await _abrir(tester, _app(_repo()));
    await _elegir(tester, 'Antirrábica');
    expect(find.text('1 año'), findsOneWidget);
    expect(find.text('3 años'), findsOneWidget);

    await tester.tap(find.text('Antirrábica'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Polivalente'));
    await tester.pumpAndSettle();
    expect(find.text('1 año'), findsNothing);
    expect(find.text('3 años'), findsNothing);
  });

  testWidgets(
    'ProximaPreview usa la respuesta del servidor y envía los datos',
    (tester) async {
      final repo = _repo();
      await _abrir(tester, _app(repo));
      await _elegir(tester, 'Antirrábica');
      expect(find.text('Próxima: 01/10/2027'), findsOneWidget);
      final llamada = repo.llamadas.lastWhere(
        (l) => l.metodo == 'previsualizar',
      );
      expect(llamada.args['codigo'], 'antirrabica');
      expect(llamada.args['fecha'], DateTime.utc(2026, 10, 1));
      expect(llamada.args['duracionDias'], 365);
    },
  );

  testWidgets(
    'Guardar dosis llama registrarDosis una vez y devuelve el resultado',
    (tester) async {
      final repo = _repo();
      await _abrir(tester, _app(repo));
      await _elegir(tester, 'Antirrábica');
      await tester.tap(find.widgetWithText(AppButton, 'Guardar dosis'));
      await tester.pumpAndSettle();
      final llamadas = repo.llamadas.where((l) => l.metodo == 'registrarDosis');
      expect(llamadas.length, 1);
      final args = llamadas.single.args;
      expect(args['codigo'], 'antirrabica');
      expect(args['fecha'], DateTime.utc(2026, 10, 1));
      expect(args['duracionDias'], 365);
      expect(args['externa'], false);
      expect(_resultado, isNotNull);
      expect(_resultado!.biologicoNombre, 'Antirrábica');
      expect(find.text('Abrir'), findsOneWidget);
    },
  );

  testWidgets(
    'un error al guardar muestra el mensaje y conserva el formulario',
    (tester) async {
      final repo = _repo(
        errorRegistrar: const VacunaFailure(
          'No pudimos guardar la dosis. Intenta de nuevo.',
        ),
      );
      await _abrir(tester, _app(repo));
      await _elegir(tester, 'Antirrábica');
      await tester.tap(find.widgetWithText(AppButton, 'Guardar dosis'));
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos guardar la dosis. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Registrar dosis'), findsOneWidget);
      expect(find.text('Antirrábica'), findsOneWidget);
      expect(_resultado, isNull);
    },
  );

  testWidgets('codigo en la ruta preselecciona; citaId viaja en la llamada', (
    tester,
  ) async {
    final repo = _repo();
    await _abrir(
      tester,
      _app(
        repo,
        ruta: rutaRegistrarDosis(
          mascotaId: 'm-1',
          codigo: 'desp_interna',
          citaId: 'c1',
        ),
      ),
    );
    expect(find.text('Desparasitación interna'), findsOneWidget);
    expect(find.text('Elige un biológico'), findsNothing);
    await tester.tap(find.widgetWithText(AppButton, 'Guardar dosis'));
    await tester.pumpAndSettle();
    final args = repo.llamadas
        .lastWhere((l) => l.metodo == 'registrarDosis')
        .args;
    expect(args['citaId'], 'c1');
    expect(args['codigo'], 'desp_interna');
  });

  testWidgets(
    'Otro...: nombre, chips de intervalo y catálogo solo para admin',
    (tester) async {
      final repo = _repo();
      await _abrir(tester, _app(repo));
      await _elegir(tester, 'Otro...');
      expect(find.text('Nombre del biológico'), findsOneWidget);
      for (final l in [
        '21 días',
        '1 mes',
        '3 meses',
        '6 meses',
        '1 año',
        'Sin refuerzo',
      ]) {
        expect(find.text(l), findsOneWidget, reason: l);
      }
      expect(find.text('Guardar en mi catálogo'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Giardia');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Guardar dosis'));
      await tester.pumpAndSettle();
      final args = repo.llamadas
          .lastWhere((l) => l.metodo == 'registrarDosis')
          .args;
      expect(args['codigo'], 'otro:giardia');
      expect(args['biologicoNombre'], 'Giardia');
      expect(args['duracionDias'], 365);
      expect(args['guardarEnCatalogo'], true);
    },
  );

  testWidgets('Otro...: un veterinario no admin no ve Guardar en mi catálogo', (
    tester,
  ) async {
    await _abrir(tester, _app(_repo(), perfil: vetColegaProfile));
    await _elegir(tester, 'Otro...');
    expect(find.text('Nombre del biológico'), findsOneWidget);
    expect(find.text('Guardar en mi catálogo'), findsNothing);
  });

  testWidgets(
    'Aplicada en otra clínica pide la clínica, oculta Aplicó y marca externa',
    (tester) async {
      final repo = _repo();
      await _abrir(tester, _app(repo));
      await _elegir(tester, 'Antirrábica');
      expect(find.text('Aplicó: Dr(a). Ana Ramírez'), findsOneWidget);
      await tester.ensureVisible(find.text('Aplicada en otra clínica'));
      await tester.tap(find.text('Aplicada en otra clínica'));
      await tester.pumpAndSettle();
      expect(find.text('Nombre de la clínica (opcional)'), findsOneWidget);
      expect(find.text('Aplicó: Dr(a). Ana Ramírez'), findsNothing);
      await tester.tap(find.widgetWithText(AppButton, 'Guardar dosis'));
      await tester.pumpAndSettle();
      final args = repo.llamadas
          .lastWhere((l) => l.metodo == 'registrarDosis')
          .args;
      expect(args['externa'], true);
      expect(args['clinicaExterna'], isNull);
    },
  );
}
