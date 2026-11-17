import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/utils/lanzador_externo.dart';
import 'package:vetapp/features/appointments/domain/whatsapp_recordatorio.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/billing/domain/cobro_failure.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/domain/whatsapp_cobro.dart';
import 'package:vetapp/features/billing/presentation/providers/cobro_pdf_providers.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
import 'package:vetapp/features/billing/presentation/widgets/enviar_cobro_sheet.dart';
import 'package:vetapp/features/clients/domain/entities/cliente.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_cobros.dart';
import 'helpers/fake_compartir_cobro.dart';
import 'helpers/fake_url_launcher.dart';
import 'helpers/router_harness.dart';

Cobro _cc({
  EstadoCobro estado = EstadoCobro.pendiente,
  String? clienteId = 'cli1',
}) => cobroDePrueba(
  numero: 12,
  estado: estado,
  clienteId: clienteId,
  fecha: DateTime.utc(2026, 11, 13),
  metodoPago: estado == EstadoCobro.pagada ? MetodoPago.nequi : null,
);

Cobro _cot() => cobroDePrueba(
  id: 'q1',
  tipo: TipoCobro.cotizacion,
  numero: 4,
  estado: EstadoCobro.abierta,
  fecha: DateTime.utc(2026, 11, 13),
  validaHasta: DateTime.utc(2026, 11, 28),
);

String _mensaje(Cobro c) => mensajeCobroWhatsApp(
  cliente: c.clienteNombre,
  numero: c.numeroTexto,
  totalCop: c.totalCop,
  clinica: clinicaPdfDePrueba().nombre,
  veterinario: vetProfile.nombre,
  mascota: c.mascotaNombre,
  esCotizacion: c.esCotizacion,
  pagada: c.pagada,
  validaHasta: c.validaHasta,
);

Future<void> _abrir(
  WidgetTester tester, {
  Cobro? cobro,
  String telefono = '3001234567',
  FakeLanzadorExterno? lanzador,
  CompartirCobroFalso? compartir,
  CobroPdfServiceFalso? servicio,
  FakeCobrosRepository? repo,
}) async {
  final c = cobro ?? _cc();
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
                onPressed: () => showEnviarCobroSheet(context, c),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ],
      overrides: <Override>[
        cobrosRepositoryProvider.overrideWithValue(
          repo ?? FakeCobrosRepository(cobros: [c]),
        ),
        clienteProvider.overrideWith(
          (ref, id) async => Cliente(
            id: id,
            clinicaId: 'cli-1',
            nombre: 'Laura Gómez',
            telefono: telefono,
          ),
        ),
        lanzadorExternoProvider.overrideWithValue(
          lanzador ?? FakeLanzadorExterno(),
        ),
        compartirCobroProvider.overrideWithValue(
          (compartir ?? CompartirCobroFalso()).call,
        ),
        cobroPdfServiceProvider.overrideWithValue(
          servicio ?? CobroPdfServiceFalso(),
        ),
        authProfileProvider.overrideWith(
          () => FakeAuthProfileNotifier(profile: vetProfile),
        ),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 13, 17)),
      ],
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('encabezado y subtítulo con el número del cliente', (
    tester,
  ) async {
    await _abrir(tester);
    expect(find.text('Enviar CC-0012'), findsOneWidget);
    expect(find.text('Para Laura Gómez'), findsOneWidget);
    expect(find.text('Enviar PDF por WhatsApp'), findsOneWidget);
    expect(
      find.text('Elige WhatsApp y el chat de Laura Gómez (+57 300 123 4567)'),
      findsOneWidget,
    );
    expect(find.text('Abrir chat de WhatsApp'), findsOneWidget);
    expect(find.text('+57 300 123 4567'), findsOneWidget);
    expect(find.text('Compartir PDF'), findsOneWidget);
    // D-16: nunca un enlace público.
    expect(
      find.textContaining(RegExp('enlace|link', caseSensitive: false)),
      findsNothing,
    );
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('Enviar PDF por WhatsApp: genera y comparte con el mensaje', (
    tester,
  ) async {
    final compartir = CompartirCobroFalso();
    final servicio = CobroPdfServiceFalso()..bloqueo = Completer<void>();
    await _abrir(tester, compartir: compartir, servicio: servicio);
    await tester.tap(find.text('Enviar PDF por WhatsApp'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Generando PDF…'), findsOneWidget);
    servicio.bloqueo!.complete();
    await tester.pumpAndSettle();
    expect(servicio.generados, hasLength(1));
    expect(compartir.llamadas, hasLength(1));
    final l = compartir.llamadas.single;
    expect(l.filename, 'Cuenta_de_cobro_CC-0012.pdf');
    expect(l.texto, _mensaje(_cc()));
    expect(find.text('Generando PDF…'), findsNothing);
  });

  testWidgets('dos toques rápidos generan una sola vez', (tester) async {
    final compartir = CompartirCobroFalso();
    final servicio = CobroPdfServiceFalso()..bloqueo = Completer<void>();
    await _abrir(tester, compartir: compartir, servicio: servicio);
    await tester.tap(find.text('Enviar PDF por WhatsApp'));
    await tester.tap(find.text('Enviar PDF por WhatsApp'), warnIfMissed: false);
    await tester.pump();
    servicio.bloqueo!.complete();
    await tester.pumpAndSettle();
    expect(servicio.generados, hasLength(1));
    expect(compartir.llamadas, hasLength(1));
  });

  testWidgets('Abrir chat de WhatsApp: wa.me al +57 con el mensaje', (
    tester,
  ) async {
    final l = FakeLanzadorExterno();
    await _abrir(tester, lanzador: l);
    await tester.tap(find.text('Abrir chat de WhatsApp'));
    await tester.pumpAndSettle();
    expect(l.metodos, ['abrirEnApp']);
    expect(l.abiertos.single, whatsappUri('573001234567', _mensaje(_cc())));
  });

  testWidgets('WhatsApp no abre -> aviso', (tester) async {
    final l = FakeLanzadorExterno()..resultadoApp = false;
    await _abrir(tester, lanzador: l);
    await tester.tap(find.text('Abrir chat de WhatsApp'));
    await tester.pumpAndSettle();
    expect(
      find.text('No pudimos abrir WhatsApp. Usa «Compartir PDF».'),
      findsOneWidget,
    );
  });

  testWidgets('teléfono fijo: fila deshabilitada con el motivo', (
    tester,
  ) async {
    final l = FakeLanzadorExterno();
    await _abrir(tester, telefono: '6015551234', lanzador: l);
    expect(
      find.text(
        'Este número parece un teléfono fijo; no se puede enviar WhatsApp.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Abrir chat de WhatsApp'));
    await tester.pumpAndSettle();
    expect(l.abiertos, isEmpty);
    // Sin opacidad: el texto sigue pintado sin un Opacity encima.
    expect(
      find.ancestor(
        of: find.text('Abrir chat de WhatsApp'),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });

  testWidgets('sin teléfono: fila deshabilitada y subtítulo sin número', (
    tester,
  ) async {
    await _abrir(tester, telefono: '');
    expect(find.text('Este cliente no tiene teléfono.'), findsOneWidget);
    expect(
      find.text('Elige WhatsApp y el chat de Laura Gómez'),
      findsOneWidget,
    );
  });

  testWidgets('sin cliente: la fila del chat no aparece', (tester) async {
    await _abrir(tester, cobro: _cc(clienteId: null));
    expect(find.text('Abrir chat de WhatsApp'), findsNothing);
    expect(find.text('Enviar PDF por WhatsApp'), findsOneWidget);
    expect(find.text('Compartir PDF'), findsOneWidget);
  });

  testWidgets('Compartir PDF: sin texto', (tester) async {
    final compartir = CompartirCobroFalso();
    await _abrir(tester, compartir: compartir);
    await tester.tap(find.text('Compartir PDF'));
    await tester.pumpAndSettle();
    expect(compartir.llamadas.single.texto, isNull);
    expect(compartir.llamadas.single.filename, 'Cuenta_de_cobro_CC-0012.pdf');
  });

  testWidgets('falla el PDF -> aviso', (tester) async {
    await _abrir(
      tester,
      servicio: CobroPdfServiceFalso(
        error: const CobroFailure(
          'No pudimos generar el PDF. Intenta de nuevo.',
        ),
      ),
    );
    await tester.tap(find.text('Compartir PDF'));
    await tester.pumpAndSettle();
    expect(
      find.text('No pudimos generar el PDF. Intenta de nuevo.'),
      findsOneWidget,
    );
  });

  group('WR-05: sin red el PDF se recupera sin cerrar la hoja', () {
    const sinRed = CobroFailure(
      'Sin conexión. Inténtalo de nuevo cuando tengas señal.',
      tipo: ErrorCobro.sinConexion,
    );

    testWidgets('Compartir PDF: falla, vuelve la señal y el segundo toque '
        'comparte', (tester) async {
      final c = _cc();
      final repo = FakeCobrosRepository(cobros: [c], errorPdf: sinRed);
      final compartir = CompartirCobroFalso();
      await _abrir(tester, repo: repo, compartir: compartir);

      await tester.tap(find.text('Compartir PDF'));
      await tester.pumpAndSettle();
      expect(
        find.text('Sin conexión. Inténtalo de nuevo cuando tengas señal.'),
        findsOneWidget,
      );
      expect(find.textContaining('No se guardaron'), findsNothing);
      expect(compartir.llamadas, isEmpty);

      repo.errorPdf = null;
      await tester.tap(find.text('Compartir PDF'));
      await tester.pumpAndSettle();
      expect(compartir.llamadas, hasLength(1));
    });

    testWidgets('chat: falla sin red y el reintento abre WhatsApp', (
      tester,
    ) async {
      final c = _cc();
      final repo = FakeCobrosRepository(cobros: [c], errorPdf: sinRed);
      final lanzador = FakeLanzadorExterno();
      await _abrir(tester, repo: repo, lanzador: lanzador);

      await tester.tap(find.text('Abrir chat de WhatsApp'));
      await tester.pumpAndSettle();
      expect(
        find.text('Sin conexión. Inténtalo de nuevo cuando tengas señal.'),
        findsOneWidget,
      );
      expect(lanzador.abiertos, isEmpty);

      repo.errorPdf = null;
      await tester.tap(find.text('Abrir chat de WhatsApp'));
      await tester.pumpAndSettle();
      expect(lanzador.abiertos, hasLength(1));
    });
  });

  testWidgets('falla el menú de compartir -> aviso', (tester) async {
    await _abrir(
      tester,
      compartir: CompartirCobroFalso(
        error: const CobroFailure(
          'No pudimos abrir el menú de compartir. Intenta de nuevo.',
        ),
      ),
    );
    await tester.tap(find.text('Enviar PDF por WhatsApp'));
    await tester.pumpAndSettle();
    expect(
      find.text('No pudimos abrir el menú de compartir. Intenta de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('cotización: título y mensaje con la validez', (tester) async {
    final compartir = CompartirCobroFalso();
    final cot = _cot();
    await _abrir(tester, cobro: cot, compartir: compartir);
    expect(find.text('Enviar COT-0004'), findsOneWidget);
    await tester.tap(find.text('Enviar PDF por WhatsApp'));
    await tester.pumpAndSettle();
    final l = compartir.llamadas.single;
    expect(l.filename, 'Cotizacion_COT-0004.pdf');
    expect(l.texto, _mensaje(cot));
    expect(l.texto, contains('Es válida hasta el 28/11/2026'));
  });

  testWidgets('CC pagada: mensaje de pagada', (tester) async {
    final compartir = CompartirCobroFalso();
    final pagada = _cc(estado: EstadoCobro.pagada);
    await _abrir(tester, cobro: pagada, compartir: compartir);
    await tester.tap(find.text('Enviar PDF por WhatsApp'));
    await tester.pumpAndSettle();
    expect(compartir.llamadas.single.texto, _mensaje(pagada));
    expect(compartir.llamadas.single.texto, contains('ya pagada'));
  });
}
