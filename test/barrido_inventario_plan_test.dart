import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/theme/app_theme.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/inventory/domain/entities/producto.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';
import 'package:vetapp/features/inventory/presentation/screens/inventario_screen.dart';
import 'package:vetapp/features/inventory/presentation/widgets/insignia_stock.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_inventario.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

const _archivos = [
  'lib/features/inventory/presentation/screens/producto_detail_screen.dart',
  'lib/features/inventory/presentation/widgets/ajuste_stock.dart',
  'lib/features/inventory/presentation/widgets/resumen_bajos_strip.dart',
  'lib/features/inventory/presentation/widgets/ajuste_rapido_botones.dart',
  'lib/features/inventory/presentation/widgets/insignia_stock.dart',
  'lib/features/inventory/presentation/screens/inventario_screen.dart',
  'lib/features/plan/presentation/widgets/plan_banner.dart',
  'lib/features/plan/presentation/widgets/uso_contador_tile.dart',
];

/// Código sin comentarios de línea (`//` y `///`).
String _codigo(String ruta) => File(ruta)
    .readAsLinesSync()
    .map((l) {
      final i = l.indexOf('//');
      return i < 0 ? l : l.substring(0, i);
    })
    .join('\n');

const _menos = ValueKey('ajuste-menos-uno');
const _mas = ValueKey('ajuste-mas');
final _hoy = DateTime.utc(2026, 10, 31, 17);

/// Repo cuya lista de productos espera a [listo] (carga sin valor).
class _RepoEnEspera extends FakeInventarioRepository {
  _RepoEnEspera({super.productos});

  final listo = Completer<void>();

  @override
  Future<List<Producto>> productos() async {
    await listo.future;
    return super.productos();
  }
}

Future<void> _pantalla(
  WidgetTester tester,
  FakeInventarioRepository repo,
) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    routerHarness(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, _) => const InventarioScreen())],
      overrides: [
        ...planOverrides(),
        authProfileProvider.overrideWith(
          () => FakeAuthProfileNotifier(profile: vetProfile),
        ),
        inventarioRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => _hoy),
      ],
    ),
  );
}

void main() {
  group('fuente', () {
    for (final ruta in _archivos) {
      test('sin botones Material crudos: $ruta', () {
        final codigo = _codigo(ruta);
        for (final prohibido in [
          'TextButton(',
          'OutlinedButton(',
          'TextButton.styleFrom',
          'OutlinedButton.styleFrom',
          'BorderRadius.circular(4)',
        ]) {
          expect(codigo.contains(prohibido), isFalse, reason: prohibido);
        }
      });
    }

    test('insignia_stock sin FontWeight literal', () {
      expect(
        _codigo(
          'lib/features/inventory/presentation/widgets/insignia_stock.dart',
        ).contains('FontWeight.'),
        isFalse,
      );
    });
  });

  group('inventario', () {
    testWidgets('ajuste rápido: OutlinedButton 48x48 dentro de AppButton', (
      tester,
    ) async {
      final repo = FakeInventarioRepository(
        productos: [productoDePrueba(cantidad: 0)],
      );
      await _pantalla(tester, repo);
      await tester.pumpAndSettle();

      for (final k in [_menos, _mas]) {
        expect(find.byKey(k), findsOneWidget);
        expect(tester.widget(find.byKey(k)), isA<OutlinedButton>());
        expect(tester.getSize(find.byKey(k)), const Size(48, 48));
        expect(
          find.ancestor(of: find.byKey(k), matching: find.byType(AppButton)),
          findsOneWidget,
        );
      }
      // Sin stock: -1 deshabilitado, + activo (como antes).
      expect(
        tester.widget<OutlinedButton>(find.byKey(_menos)).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byKey(_mas)).onPressed,
        isNotNull,
      );
    });

    testWidgets('insignia usa Label 14/600 (labelLarge)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: InsigniaStock(estado: EstadoStock.bajo)),
        ),
      );
      final texto = tester.widget<Text>(
        find.descendant(
          of: find.byType(InsigniaStock),
          matching: find.byType(Text),
        ),
      );
      final ctx = tester.element(find.byType(InsigniaStock));
      final labelLarge = Theme.of(ctx).textTheme.labelLarge!;
      expect(texto.style?.fontSize, labelLarge.fontSize);
      expect(texto.style?.fontSize, 14);
      expect(texto.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('la cabecera se ve deshabilitada mientras carga', (
      tester,
    ) async {
      final repo = _RepoEnEspera(
        productos: [
          productoDePrueba(id: 'zinc', nombre: 'Zinc'),
          productoDePrueba(
            id: 'amoxi',
            nombre: 'Amoxicilina',
            cantidad: 1,
            minimo: 2,
          ),
        ],
      );
      await _pantalla(tester, repo);
      await tester.pump();

      expect(find.text('Buscar producto'), findsWidgets);
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Bajos'), findsOneWidget);
      expect(find.text('Vence pronto'), findsOneWidget);

      // Tocar un chip mientras carga no cambia el filtro.
      await tester.tap(find.text('Bajos'), warnIfMissed: false);
      await tester.pump();

      repo.listo.complete();
      await tester.pumpAndSettle();
      expect(find.text('Zinc'), findsOneWidget);
      expect(find.text('Amoxicilina'), findsWidgets);

      // Con datos, los chips filtran como antes.
      await tester.tap(find.text('Bajos (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Zinc'), findsNothing);
    });
  });
}
