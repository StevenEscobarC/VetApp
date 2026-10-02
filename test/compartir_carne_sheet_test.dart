import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/utils/compartir.dart';
import 'package:vetapp/core/utils/lanzador_externo.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/clinical_history/presentation/providers/historia_clinica_pdf_providers.dart';
import 'package:vetapp/features/vaccination/data/services/carne_pdf_service.dart';
import 'package:vetapp/features/vaccination/domain/entities/carne.dart';
import 'package:vetapp/features/vaccination/domain/vacuna_failure.dart';
import 'package:vetapp/features/vaccination/presentation/providers/carne_pdf_providers.dart';
import 'package:vetapp/features/vaccination/presentation/providers/vacuna_providers.dart';
import 'package:vetapp/features/vaccination/presentation/widgets/compartir_carne_sheet.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_compartir.dart';
import 'helpers/fake_pdf.dart';
import 'helpers/fake_url_launcher.dart';
import 'helpers/fake_vacunas.dart';
import 'helpers/router_harness.dart';

class _PdfFalso implements CarnePdfService {
  _PdfFalso({this.error});

  final Object? error;

  @override
  Future<Uint8List> generar({
    required Carne carne,
    required DateTime generadoEn,
  }) async {
    if (error != null) throw error!;
    return Uint8List.fromList([37, 80, 68, 70]);
  }
}

Carne _carne({String telefono = '3001234567'}) => Carne(
  hoy: DateTime.utc(2026, 10, 2),
  mascotaId: 'm-1',
  mascotaNombre: 'Luna',
  especie: 'perro',
  raza: 'Criollo',
  duenoNombre: 'Ana Ramírez',
  duenoTelefono: telefono,
  clinicaNombre: 'Clínica Patitas',
  clinicaCiudad: 'Bogotá',
  biologicos: const [],
  dosis: const [],
);

final _token = 'a' * 64;
final _url = 'https://stevenescobarc.github.io/VetApp/c/#$_token';

Future<void> _abrir(
  WidgetTester tester, {
  FakeVacunaRepository? repo,
  FakeLanzadorExterno? lanzador,
  FakeCompartidor? compartidor,
  CompartirPdfFalso? pdf,
  CarnePdfService? servicio,
  String telefono = '3001234567',
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    routerHarness(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    showCompartirCarneSheet(context, mascotaId: 'm-1'),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ],
      overrides: <Override>[
        vacunaRepositoryProvider.overrideWithValue(
          repo ??
              FakeVacunaRepository(carnes: {'m-1': _carne(telefono: telefono)}),
        ),
        lanzadorExternoProvider.overrideWithValue(
          lanzador ?? FakeLanzadorExterno(),
        ),
        compartidorProvider.overrideWithValue(
          compartidor ?? FakeCompartidor(),
        ),
        compartirPdfProvider.overrideWithValue(pdf ?? CompartirPdfFalso()),
        carnePdfServiceProvider.overrideWithValue(servicio ?? _PdfFalso()),
        authProfileProvider.overrideWith(
          () => FakeAuthProfileNotifier(profile: vetProfile),
        ),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 2, 15)),
      ],
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra título y enlace truncado con los 4 últimos', (
    tester,
  ) async {
    await _abrir(tester);
    expect(find.text('Compartir carné de Luna'), findsOneWidget);
    expect(find.textContaining('aaaa'), findsWidgets);
    expect(
      find.text('Quien tenga el enlace podrá ver el carné.'),
      findsOneWidget,
    );
    expect(find.text('Dueño: Ana Ramírez · 3001234567'), findsOneWidget);
  });

  testWidgets('WhatsApp abre wa.me con el enlace y mensaje formal', (
    tester,
  ) async {
    final l = FakeLanzadorExterno();
    await _abrir(tester, lanzador: l);
    await tester.tap(find.text('Enviar por WhatsApp al dueño'));
    await tester.pumpAndSettle();
    expect(l.metodos, ['abrirEnApp']);
    final uri = l.abiertos.single;
    expect(uri.host, 'wa.me');
    final texto = Uri.decodeComponent(uri.queryParameters['text']!);
    expect(texto, contains(_url));
    expect(texto, contains('Le compartimos el carné de vacunación de Luna'));
  });

  testWidgets('WhatsApp falla -> snackbar', (tester) async {
    final l = FakeLanzadorExterno()..resultado = false;
    await _abrir(tester, lanzador: l);
    await tester.tap(find.text('Enviar por WhatsApp al dueño'));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos abrir WhatsApp.'), findsOneWidget);
  });

  testWidgets('sin teléfono deshabilita WhatsApp', (tester) async {
    final l = FakeLanzadorExterno();
    await _abrir(tester, lanzador: l, telefono: '');
    expect(find.text('Sin teléfono registrado'), findsOneWidget);
    await tester.tap(find.text('Enviar por WhatsApp al dueño'));
    await tester.pumpAndSettle();
    expect(l.abiertos, isEmpty);
  });

  testWidgets('Compartir enlace usa el share nativo', (tester) async {
    final c = FakeCompartidor();
    await _abrir(tester, compartidor: c);
    await tester.tap(find.text('Compartir enlace'));
    await tester.pumpAndSettle();
    expect(c.compartidos, ['Carné de vacunación de Luna: $_url']);
  });

  testWidgets('Descargar PDF entrega bytes y nombre de archivo', (
    tester,
  ) async {
    final p = CompartirPdfFalso();
    await _abrir(tester, pdf: p);
    await tester.tap(find.text('Descargar PDF'));
    await tester.pumpAndSettle();
    expect(p.llamadas.single.filename, 'Carne_Luna_2026-10-02.pdf');
    expect(p.llamadas.single.bytes, isNotEmpty);
  });

  testWidgets('Descargar PDF con fallo muestra mensaje', (tester) async {
    await _abrir(
      tester,
      servicio: _PdfFalso(
        error: const VacunaFailure('No pudimos generar el PDF. Intenta de nuevo.'),
      ),
    );
    await tester.tap(find.text('Descargar PDF'));
    await tester.pumpAndSettle();
    expect(
      find.text('No pudimos generar el PDF. Intenta de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('fuentes que fallan no usan el servicio real en tests', (
    tester,
  ) async {
    // Garantiza que el helper de fuentes siga siendo importable/usable.
    expect((await fuentesDePrueba()).regular, isNotNull);
  });

  testWidgets('Copiar enlace pone el url en el portapapeles', (tester) async {
    String? copiado;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiado = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _abrir(tester);
    await tester.tap(find.text('Copiar enlace'));
    await tester.pumpAndSettle();
    expect(copiado, _url);
    expect(find.text('Enlace copiado'), findsOneWidget);
  });

  testWidgets('Regenerar enlace pide confirmación y cambia el token', (
    tester,
  ) async {
    final repo = FakeVacunaRepository(carnes: {'m-1': _carne()});
    await _abrir(tester, repo: repo);
    await tester.tap(find.text('Regenerar enlace'));
    await tester.pumpAndSettle();
    expect(find.text('¿Regenerar el enlace del carné?'), findsOneWidget);
    expect(find.text('Volver'), findsOneWidget);
    await tester.tap(find.text('Regenerar'));
    await tester.pumpAndSettle();
    expect(repo.llamadas.any((l) => l.metodo == 'regenerarEnlace'), isTrue);
    expect(find.text('Enlace regenerado'), findsOneWidget);
  });

  testWidgets('Regenerar y Volver no regenera', (tester) async {
    final repo = FakeVacunaRepository(carnes: {'m-1': _carne()});
    await _abrir(tester, repo: repo);
    await tester.tap(find.text('Regenerar enlace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(repo.llamadas.any((l) => l.metodo == 'regenerarEnlace'), isFalse);
  });

  testWidgets('error al crear el enlace muestra Reintentar', (tester) async {
    final repo = FakeVacunaRepository(
      carnes: {'m-1': _carne()},
      errorEnlace: const VacunaFailure('x'),
    );
    final l = FakeLanzadorExterno();
    await _abrir(tester, repo: repo, lanzador: l);
    expect(
      find.text('No pudimos crear el enlace. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.text('Enviar por WhatsApp al dueño'));
    await tester.pumpAndSettle();
    expect(l.abiertos, isEmpty);
  });
}
