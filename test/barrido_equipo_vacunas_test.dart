import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/theme/app_colors.dart';
import 'package:vetapp/core/theme/app_spacing.dart';
import 'package:vetapp/core/theme/app_theme.dart';
import 'package:vetapp/core/utils/compartir.dart';
import 'package:vetapp/core/utils/lanzador_externo.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/core/widgets/cards/app_card.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/providers/recordatorios_providers.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';
import 'package:vetapp/features/plan/presentation/providers/plan_providers.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';
import 'package:vetapp/features/team/presentation/screens/equipo_screen.dart';
import 'package:vetapp/features/vaccination/domain/entities/carne.dart';
import 'package:vetapp/features/vaccination/domain/entities/protocolo.dart';
import 'package:vetapp/features/vaccination/presentation/providers/vacuna_providers.dart';
import 'package:vetapp/features/vaccination/presentation/widgets/carne_resumen_section.dart';
import 'package:vetapp/features/vaccination/presentation/widgets/dosis_card.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_compartir.dart';
import 'helpers/fake_inventario.dart';
import 'helpers/fake_plan.dart';
import 'helpers/fake_recordatorios.dart';
import 'helpers/fake_team.dart';
import 'helpers/fake_url_launcher.dart';
import 'helpers/router_harness.dart';

const _team = [
  'lib/features/team/presentation/screens/equipo_screen.dart',
  'lib/features/team/presentation/widgets/invitacion_card.dart',
  'lib/features/team/presentation/widgets/miembro_acciones_sheet.dart',
];
const _vacunas = [
  'lib/features/vaccination/presentation/widgets/dosis_card.dart',
  'lib/features/vaccination/presentation/widgets/carne_resumen_section.dart',
];

/// Source without `//` comments (full-line and trailing).
String _codigo(String path) => File(path)
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .map((l) => l.replaceFirst(RegExp(r'\s//\s.*$'), ''))
    .join('\n');

List<Override> _overrides(FakeTeamRepository repo, DateTime ahora) {
  SharedPreferences.setMockInitialValues({});
  return [
    authProfileProvider.overrideWith(
      () => FakeAuthProfileNotifier(profile: vetAdminProfile),
    ),
    teamRepositoryProvider.overrideWithValue(repo),
    citaRepositoryProvider.overrideWithValue(FakeCitaRepository()),
    recordatoriosServiceProvider.overrideWithValue(FakeRecordatoriosService()),
    planRepositoryProvider.overrideWithValue(FakePlanRepository()),
    inventarioRepositoryProvider.overrideWithValue(FakeInventarioRepository()),
    clockProvider.overrideWithValue(() => ahora),
    compartidorProvider.overrideWithValue(FakeCompartidor()),
    lanzadorExternoProvider.overrideWithValue(FakeLanzadorExterno()),
  ];
}

Widget _equipo(FakeTeamRepository repo) => routerHarness(
  initialLocation: '/equipo',
  routes: [GoRoute(path: '/equipo', builder: (_, _) => const EquipoScreen())],
  overrides: _overrides(repo, DateTime.utc(2026, 10, 1, 15)),
);

DosisCarne _dosisRetirado() => DosisCarne(
  id: 'd1',
  codigoProtocolo: 'rabia',
  biologicoNombre: 'Rabia',
  tipo: TipoDosis.vacuna,
  fechaAplicacion: DateTime(2026, 3, 1),
  esUltima: true,
  externa: false,
  esRefuerzo: false,
  anulada: false,
  veterinario: const VeterinarioDosis(nombre: 'Luis Gómez', activo: false),
);

Widget _dosis(ThemeData theme) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: DosisCard(
      dosis: _dosisRetirado(),
      mascotaId: 'm1',
      hoy: DateTime(2026, 10, 1),
    ),
  ),
);

Color? _colorRetirado(WidgetTester tester) {
  Color? color;
  for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
    rt.text.visitChildren((span) {
      if (span is TextSpan && span.text == ' (retirado)') {
        color = span.style?.color;
      }
      return true;
    });
  }
  return color;
}

void main() {
  group('fuente', () {
    for (final f in [..._team, ..._vacunas]) {
      test('$f sin TextButton crudo', () {
        expect(_codigo(f).contains('TextButton('), isFalse);
      });
    }
    for (final f in _vacunas) {
      test('$f sin literales de espaciado', () {
        final c = _codigo(f);
        expect(
          RegExp(r'EdgeInsets\.\w+\((?:[^)]*[^a-zA-Z_.0-9])?\d+').hasMatch(c),
          isFalse,
        );
        expect(c.contains('SizedBox(height: 32'), isFalse);
      });
    }
  });

  group('equipo', () {
    testWidgets('regenerar código: AppButtons Volver / Generar nuevo', (
      tester,
    ) async {
      final repo = FakeTeamRepository(miembrosFixture: [miembroAna])
        ..invitacion = invitacionFixture;
      await tester.pumpWidget(_equipo(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generar código nuevo'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppButton, 'Volver'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Generar nuevo'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Volver'));
      await tester.pumpAndSettle();
      expect(repo.generadas, 0);
      await tester.tap(find.text('Generar código nuevo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Generar nuevo'));
      await tester.pumpAndSettle();
      expect(repo.generadas, 1);
    });

    testWidgets('revocar código: Volver es AppButton y no revoca', (
      tester,
    ) async {
      final repo = FakeTeamRepository(miembrosFixture: [miembroAna])
        ..invitacion = invitacionFixture;
      await tester.pumpWidget(_equipo(repo));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Revocar código'));
      await tester.tap(find.text('Revocar código'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppButton, 'Volver'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Volver'));
      await tester.pumpAndSettle();
      expect(find.text('Código revocado'), findsNothing);
    });

    testWidgets('confirmación de miembro: AppButtons, Volver no cambia rol', (
      tester,
    ) async {
      final repo = FakeTeamRepository(
        miembrosFixture: [miembroAna, miembroLuis],
      );
      await tester.pumpWidget(_equipo(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Luis Gómez'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hacer administrador'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppButton, 'Volver'), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, 'Hacer administrador'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(AppButton, 'Volver'));
      await tester.pumpAndSettle();
      expect(repo.rolesCambiados, isEmpty);

      await tester.tap(find.textContaining('Luis Gómez'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hacer administrador'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Hacer administrador'));
      await tester.pumpAndSettle();
      expect(repo.rolesCambiados, [('vet-2', 'admin')]);
    });
  });
}
