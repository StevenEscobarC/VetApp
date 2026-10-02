import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/features/clinic/domain/clinica_failure.dart';
import 'package:vetapp/features/clinic/presentation/providers/clinica_providers.dart';
import 'package:vetapp/features/vaccination/domain/entities/carne.dart';
import 'package:vetapp/features/vaccination/domain/entities/protocolo.dart';
import 'package:vetapp/features/vaccination/domain/vacuna_failure.dart';
import 'package:vetapp/features/vaccination/presentation/providers/vacuna_providers.dart';
import 'package:vetapp/features/vaccination/presentation/screens/carne_screen.dart';

import 'helpers/fake_vacunas.dart';
import 'helpers/router_harness.dart';

BiologicoCarne _bio({
  required String codigo,
  required String nombre,
  required String ultimaDosisId,
  required EstadoCarne estado,
  TipoDosis tipo = TipoDosis.vacuna,
  int posicion = 1,
  int dosisSerie = 1,
  DateTime? proxima,
  int diasVencida = 0,
  DateTime? ultimaFecha,
}) => BiologicoCarne(
  codigoProtocolo: codigo,
  biologicoNombre: nombre,
  tipo: tipo,
  ultimaDosisId: ultimaDosisId,
  ultimaFecha: ultimaFecha ?? DateTime.utc(2026, 9, 1),
  posicion: posicion,
  dosisSerie: dosisSerie,
  proximaFecha: proxima,
  etiquetaProxima: '',
  estado: estado,
  diasVencida: diasVencida,
  ventanaDias: 30,
  sugerirReiniciar: false,
);

DosisCarne _dosis({
  required String id,
  required String codigo,
  required String nombre,
  required DateTime fecha,
  TipoDosis tipo = TipoDosis.vacuna,
  String? etiqueta,
  bool esUltima = true,
  String? producto,
  String? lote,
  bool externa = false,
  String? clinicaExterna,
  bool esRefuerzo = false,
  bool anulada = false,
  String? motivo,
  VeterinarioDosis? vet = const VeterinarioDosis(
    nombre: 'Laura Gómez',
    matricula: '12345',
    activo: true,
  ),
}) => DosisCarne(
  id: id,
  codigoProtocolo: codigo,
  biologicoNombre: nombre,
  tipo: tipo,
  fechaAplicacion: fecha,
  etiquetaDosis: etiqueta,
  esUltima: esUltima,
  producto: producto,
  lote: lote,
  externa: externa,
  clinicaExterna: clinicaExterna,
  esRefuerzo: esRefuerzo,
  anulada: anulada,
  motivoAnulacion: motivo,
  anuladaAt: anulada ? DateTime.utc(2026, 9, 5) : null,
  veterinario: externa ? null : vet,
);

Carne _carne({
  List<BiologicoCarne>? biologicos,
  List<DosisCarne>? dosis,
  bool vetActivo = true,
  String clinicaNombre = 'Clínica',
  String clinicaCiudad = 'Bogotá',
  String? clinicaLogoPath,
}) => Carne(
  hoy: DateTime.utc(2026, 10, 2),
  mascotaId: 'm-1',
  mascotaNombre: 'Luna',
  especie: 'perro',
  raza: '',
  duenoNombre: 'Rita',
  duenoTelefono: '3001112233',
  clinicaNombre: clinicaNombre,
  clinicaCiudad: clinicaCiudad,
  clinicaLogoPath: clinicaLogoPath,
  biologicos:
      biologicos ??
      [
        _bio(
          codigo: 'desp_externa',
          nombre: 'Desparasitación externa',
          tipo: TipoDosis.desparasitacionExterna,
          ultimaDosisId: 'd-ext',
          estado: EstadoCarne.completo,
        ),
        _bio(
          codigo: 'antirrabica',
          nombre: 'Antirrábica',
          ultimaDosisId: 'd-ant',
          estado: EstadoCarne.alDia,
          proxima: DateTime.utc(2027, 9, 1),
        ),
        _bio(
          codigo: 'polivalente',
          nombre: 'Polivalente',
          ultimaDosisId: 'd-pol-2',
          estado: EstadoCarne.vencida,
          posicion: 2,
          dosisSerie: 3,
          proxima: DateTime.utc(2026, 9, 20),
          diasVencida: 12,
          ultimaFecha: DateTime.utc(2026, 8, 30),
        ),
      ],
  dosis:
      dosis ??
      [
        _dosis(
          id: 'd-pol-2',
          codigo: 'polivalente',
          nombre: 'Polivalente',
          fecha: DateTime.utc(2026, 8, 30),
          etiqueta: 'Dosis 2 de 3',
          producto: 'Nobivac',
          lote: 'A123',
          vet: VeterinarioDosis(
            nombre: 'Laura Gómez',
            matricula: '12345',
            activo: vetActivo,
          ),
        ),
        _dosis(
          id: 'd-pol-1',
          codigo: 'polivalente',
          nombre: 'Polivalente',
          fecha: DateTime.utc(2026, 8, 9),
          esUltima: false,
          anulada: true,
          motivo: 'Error de registro',
        ),
        _dosis(
          id: 'd-ant',
          codigo: 'antirrabica',
          nombre: 'Antirrábica',
          fecha: DateTime.utc(2026, 9, 1),
          esRefuerzo: true,
        ),
        _dosis(
          id: 'd-ext',
          codigo: 'desp_externa',
          nombre: 'Desparasitación externa',
          tipo: TipoDosis.desparasitacionExterna,
          fecha: DateTime.utc(2026, 9, 10),
          externa: true,
          clinicaExterna: 'Clínica X',
        ),
      ],
);

Widget _app({
  required FakeVacunaRepository repo,
  List<String>? ubicaciones,
  List<Override> extra = const [],
}) {
  return routerHarness(
    initialLocation: '/pacientes/m-1/carne',
    routes: [
      GoRoute(
        path: '/pacientes/:id/carne',
        builder: (_, state) =>
            CarneScreen(mascotaId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/dosis/nueva',
        builder: (_, state) {
          ubicaciones?.add(state.uri.toString());
          return Text('REGISTRAR ${state.uri.query}');
        },
      ),
    ],
    overrides: [vacunaRepositoryProvider.overrideWithValue(repo), ...extra],
  );
}

void _pantallaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  const rutaLogo = 'c1/logo-1700000000000.jpg';
  final logo = find.byKey(const Key('logo-clinica'));

  testWidgets('membrete sin logo: solo nombre y ciudad, sin logo', (
    tester,
  ) async {
    _pantallaAlta(tester);
    final repo = FakeVacunaRepository(
      carnes: {
        'm-1': _carne(
          clinicaNombre: 'Veterinaria El Roble',
          clinicaCiudad: 'Medellín',
        ),
      },
    );
    await tester.pumpWidget(_app(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Veterinaria El Roble · Medellín'), findsOneWidget);
    expect(logo, findsNothing);
  });

  testWidgets('membrete con logo lo muestra junto al nombre', (tester) async {
    _pantallaAlta(tester);
    final repo = FakeVacunaRepository(
      carnes: {
        'm-1': _carne(
          clinicaNombre: 'Veterinaria El Roble',
          clinicaCiudad: 'Medellín',
          clinicaLogoPath: rutaLogo,
        ),
      },
    );
    await tester.pumpWidget(
      _app(
        repo: repo,
        extra: [
          clinicaLogoUrlProvider(
            rutaLogo,
          ).overrideWith((ref) async => 'https://example.test/y'),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(logo, findsOneWidget);
    expect(find.text('Veterinaria El Roble · Medellín'), findsOneWidget);
  });

  testWidgets('membrete: si el logo falla queda solo el nombre', (
    tester,
  ) async {
    _pantallaAlta(tester);
    final repo = FakeVacunaRepository(
      carnes: {
        'm-1': _carne(
          clinicaNombre: 'Veterinaria El Roble',
          clinicaCiudad: 'Medellín',
          clinicaLogoPath: rutaLogo,
        ),
      },
    );
    await tester.pumpWidget(
      _app(
        repo: repo,
        extra: [
          clinicaLogoUrlProvider(rutaLogo).overrideWith(
            (ref) => throw const ClinicaFailure('No pudimos cargar el logo.'),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(logo, findsNothing);
    expect(find.text('Veterinaria El Roble · Medellín'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('agrupa por biológico: vencida primero, luego alfabético', (
    tester,
  ) async {
    _pantallaAlta(tester);
    final repo = FakeVacunaRepository(carnes: {'m-1': _carne()});
    await tester.pumpWidget(_app(repo: repo));
    await tester.pumpAndSettle();

    final pol = tester.getTopLeft(find.text('Polivalente').first).dy;
    final ant = tester.getTopLeft(find.text('Antirrábica').first).dy;
    final ext = tester.getTopLeft(find.text('Desparasitación externa').first).dy;
    expect(pol, lessThan(ant));
    expect(ant, lessThan(ext));
    expect(find.text('Carné de vacunación'), findsOneWidget);
    expect(find.text('3 dosis'), findsOneWidget);
  });

  testWidgets('la tarjeta muestra dosis, fechas, vencimiento y atribución', (
    tester,
  ) async {
    _pantallaAlta(tester);
    final repo = FakeVacunaRepository(carnes: {'m-1': _carne()});
    await tester.pumpWidget(_app(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Dosis 2 de 3'), findsOneWidget);
    expect(find.text('Aplicada: 30/08/2026'), findsOneWidget);
    expect(find.text('Próxima: 20/09/2026'), findsOneWidget);
    expect(find.text('Venció hace 12 días'), findsOneWidget);
    expect(find.text('Producto: Nobivac · Lote: A123'), findsOneWidget);
    expect(
      find.text('Aplicó: Dr(a). Laura Gómez · Mat. 12345'),
      findsWidgets,
    );
    expect(find.text('Refuerzo'), findsOneWidget);
    expect(find.text('Sin refuerzo'), findsOneWidget);
  });

  testWidgets('veterinario inactivo se marca (retirado)', (tester) async {
    _pantallaAlta(tester);
    final repo = FakeVacunaRepository(
      carnes: {'m-1': _carne(vetActivo: false)},
    );
    await tester.pumpWidget(_app(repo: repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('(retirado)'), findsOneWidget);
  });

  testWidgets('dosis externa: etiqueta Otra clínica y Aplicada en {Clínica}', (
    tester,
  ) async {
    _pantallaAlta(tester);
    final repo = FakeVacunaRepository(carnes: {'m-1': _carne()});
    await tester.pumpWidget(_app(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Otra clínica'), findsOneWidget);
    expect(find.text('Aplicada en Clínica X'), findsOneWidget);
  });

  testWidgets('Historial está colapsado y muestra la dosis anulada tachada', (
    tester,
  ) async {
    _pantallaAlta(tester);
    final repo = FakeVacunaRepository(carnes: {'m-1': _carne()});
    await tester.pumpWidget(_app(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Historial (1)'), findsOneWidget);
    expect(find.text('Anulada: Error de registro'), findsNothing);

    await tester.tap(find.text('Historial (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Anulada: Error de registro'), findsOneWidget);
    final fecha = tester.widget<Text>(find.text('Aplicada: 09/08/2026'));
    expect(fecha.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('anular dosis: exige motivo y llama al repositorio', (
    tester,
  ) async {
    _pantallaAlta(tester);
    final repo = FakeVacunaRepository(carnes: {'m-1': _carne()});
    await tester.pumpWidget(_app(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Más acciones').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anular dosis'));
    await tester.pumpAndSettle();

    expect(find.text('Error de registro'), findsOneWidget);
    expect(find.text('Dosis duplicada'), findsOneWidget);
    expect(find.text('Otro motivo'), findsOneWidget);
    expect(
      find.text(
        'La dosis quedará tachada y no contará para la próxima fecha. '
        'No se puede deshacer.',
      ),
      findsOneWidget,
    );

    AppButton confirmar() => tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Anular dosis'),
    );
    expect(confirmar().onPressed, isNull);

    await tester.tap(find.text('Error de registro'));
    await tester.pumpAndSettle();
    expect(confirmar().onPressed, isNotNull);

    await tester.tap(find.widgetWithText(AppButton, 'Anular dosis'));
    await tester.pumpAndSettle();

    final llamada = repo.llamadas.lastWhere((l) => l.metodo == 'anularDosis');
    expect(llamada.args['dosisId'], 'd-pol-2');
    expect(llamada.args['motivo'], 'Error de registro');
    expect(find.text('Dosis anulada. Registra la correcta.'), findsOneWidget);
    expect(
      find.widgetWithText(SnackBarAction, 'Registrar dosis'),
      findsOneWidget,
    );
  });

  testWidgets('"Otro motivo" requiere texto', (tester) async {
    _pantallaAlta(tester);
    final repo = FakeVacunaRepository(carnes: {'m-1': _carne()});
    await tester.pumpWidget(_app(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Más acciones').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anular dosis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otro motivo'));
    await tester.pumpAndSettle();

    AppButton confirmar() => tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Anular dosis'),
    );
    expect(confirmar().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Vacuna equivocada');
    await tester.pumpAndSettle();
    expect(confirmar().onPressed, isNotNull);
    await tester.tap(find.widgetWithText(AppButton, 'Anular dosis'));
    await tester.pumpAndSettle();

    final llamada = repo.llamadas.lastWhere((l) => l.metodo == 'anularDosis');
    expect(llamada.args['motivo'], 'Vacuna equivocada');
  });

  testWidgets('fallo al anular muestra el mensaje de VacunaFailure', (
    tester,
  ) async {
    _pantallaAlta(tester);
    final repo = FakeVacunaRepository(
      carnes: {'m-1': _carne()},
      errorAnular: const VacunaFailure('No pudimos anular la dosis.'),
    );
    await tester.pumpWidget(_app(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Más acciones').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anular dosis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dosis duplicada'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Anular dosis'));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos anular la dosis.'), findsOneWidget);
  });

  testWidgets('carné vacío: estado vacío y Compartir avisa', (tester) async {
    _pantallaAlta(tester);
    final repo = FakeVacunaRepository(
      carnes: {'m-1': _carne(biologicos: [], dosis: [])},
    );
    await tester.pumpWidget(_app(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Sin vacunas registradas'), findsOneWidget);
    expect(
      find.text(
        'Registra la primera dosis de Luna o la que ya trae en su carné '
        'de papel.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Compartir carné'));
    await tester.pump();
    expect(
      find.text('Registra al menos una dosis para compartir el carné'),
      findsOneWidget,
    );
  });

  testWidgets('"+ Registrar dosis" empuja /dosis/nueva con mascotaId', (
    tester,
  ) async {
    _pantallaAlta(tester);
    final ubicaciones = <String>[];
    final repo = FakeVacunaRepository(carnes: {'m-1': _carne()});
    await tester.pumpWidget(_app(repo: repo, ubicaciones: ubicaciones));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Registrar dosis'));
    await tester.pumpAndSettle();

    expect(ubicaciones, contains('/dosis/nueva?mascotaId=m-1'));
  });

  testWidgets('error de carga: mensaje y Reintentar', (tester) async {
    _pantallaAlta(tester);
    final repo = FakeVacunaRepository(
      carnes: {'m-1': _carne()},
      error: const VacunaFailure('x'),
    );
    await tester.pumpWidget(_app(repo: repo));
    await tester.pumpAndSettle();

    expect(
      find.text('No pudimos cargar el carné. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
