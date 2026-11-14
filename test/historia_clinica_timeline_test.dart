import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/core/widgets/status/vet_avatar.dart';
import 'package:vetapp/features/clinical_history/domain/entities/consulta.dart';
import 'package:vetapp/features/clinical_history/presentation/providers/consultas_providers.dart';
import 'package:vetapp/features/clinical_history/presentation/widgets/historia_clinica_timeline.dart';
import 'package:vetapp/features/team/domain/miembro.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_consultas.dart';
import 'helpers/fake_team.dart';
import 'helpers/router_harness.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
import 'package:vetapp/features/billing/presentation/widgets/estado_cobro_chip.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';

import 'helpers/fake_cobros.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/fake_plan.dart';

Consulta _consulta({
  String? nombre = 'Laura Gómez',
  bool? activo = true,
  String vetId = 'vet-1',
}) => Consulta(
  id: 'c1',
  mascotaId: 'm1',
  veterinarioId: vetId,
  fecha: DateTime(2026, 5, 1),
  diagnostico: 'Otitis',
  tratamiento: 'Gotas',
  veterinarioNombre: nombre,
  veterinarioActivo: activo,
);

Widget _app(List<Consulta> consultas, List<Miembro> miembros) => routerHarness(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) =>
          const Scaffold(body: HistoriaClinicaTimeline(mascotaId: 'm1')),
    ),
  ],
  overrides: <Override>[
    authProfileProvider.overrideWith(
      () => FakeAuthProfileNotifier(profile: vetProfile),
    ),
    consultaRepositoryProvider.overrideWithValue(
      FakeConsultaRepository(consultas: consultas),
    ),
    teamRepositoryProvider.overrideWithValue(
      FakeTeamRepository(miembrosFixture: miembros),
    ),
    cobrosRepositoryProvider.overrideWithValue(FakeCobrosRepository()),
    mascotaRepositoryProvider.overrideWithValue(FakeMascotaRepository()),
  ],
);

/// Consulta de Rocky (m-1, dueño c-1) para los casos de cobro.
final _consultaRocky = Consulta(
  id: 'con-7',
  mascotaId: 'm-1',
  veterinarioId: 'vet-1',
  fecha: DateTime(2026, 5, 1),
  diagnostico: 'Otitis',
  tratamiento: 'Gotas',
  evolucion: 'Mejoría',
);

Widget _appCobro({
  FakeCobrosRepository? cobros,
  FakeMascotaRepository? mascotas,
  MiPlan? plan,
}) => routerHarness(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(
        body: SingleChildScrollView(
          child: HistoriaClinicaTimeline(mascotaId: 'm-1'),
        ),
      ),
    ),
    GoRoute(
      path: '/cobros/nuevo',
      builder: (_, s) => Scaffold(body: Text('NUEVO ${s.uri.query}')),
    ),
    GoRoute(
      path: '/cobros/:id',
      builder: (_, s) =>
          Scaffold(body: Text('DETALLE ${s.pathParameters['id']}')),
    ),
  ],
  overrides: <Override>[
    ...planOverrides(plan: plan),
    authProfileProvider.overrideWith(
      () => FakeAuthProfileNotifier(profile: vetProfile),
    ),
    consultaRepositoryProvider.overrideWithValue(
      FakeConsultaRepository(consultas: [_consultaRocky]),
    ),
    teamRepositoryProvider.overrideWithValue(
      FakeTeamRepository(miembrosFixture: [miembroAna]),
    ),
    cobrosRepositoryProvider.overrideWithValue(
      cobros ?? FakeCobrosRepository(),
    ),
    mascotaRepositoryProvider.overrideWithValue(
      mascotas ?? FakeMascotaRepository(mascotas: [mascotaRocky]),
    ),
  ],
);

Future<void> _expandir(WidgetTester tester) async {
  await tester.tap(find.text('Otitis'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('multi-vet muestra Atendió con VetAvatar', (tester) async {
    await tester.pumpWidget(_app([_consulta()], [miembroAna, miembroLuis]));
    await tester.pumpAndSettle();
    expect(find.text('Atendió: Dr(a). Laura Gómez'), findsOneWidget);
    expect(find.byType(VetAvatar), findsOneWidget);
  });

  testWidgets('un solo vet con consultas propias no muestra la línea', (
    tester,
  ) async {
    await tester.pumpWidget(_app([_consulta()], [miembroAna]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Atendió'), findsNothing);
  });

  testWidgets('un solo vet con autor retirado muestra (retirado)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([_consulta(activo: false, vetId: 'vet-3')], [miembroAna]),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Atendió: Dr(a). Laura Gómez', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('(retirado)', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('sin nombre de autor no hay línea', (tester) async {
    await tester.pumpWidget(
      _app([_consulta(nombre: null)], [miembroAna, miembroLuis]),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Atendió'), findsNothing);
  });

  group('Cobrar desde la consulta (D-05)', () {
    testWidgets('colapsada no muestra Cobrar ni Cobrada', (tester) async {
      await tester.pumpWidget(_appCobro());
      await tester.pumpAndSettle();
      expect(find.text('Cobrar'), findsNothing);
      expect(find.textContaining('Cobrada'), findsNothing);
    });

    testWidgets(
      'expandida: TextButton "Cobrar" de 48dp bajo Evolución; abre el '
      'formulario con cliente, mascota y consulta',
      (tester) async {
        await tester.pumpWidget(_appCobro());
        await tester.pumpAndSettle();
        await _expandir(tester);

        final boton = find.widgetWithText(TextButton, 'Cobrar');
        expect(boton, findsOneWidget);
        expect(tester.getSize(boton).height, greaterThanOrEqualTo(48));
        expect(
          tester.getTopLeft(boton).dy,
          greaterThan(tester.getTopLeft(find.text('Evolución')).dy),
        );

        await tester.tap(boton);
        await tester.pumpAndSettle();
        final destino = tester
            .widget<Text>(find.textContaining('NUEVO '))
            .data!;
        final query = Uri.splitQueryString(destino.substring(6));
        expect(query['tipo'], 'cc');
        expect(query['clienteId'], 'c-1');
        expect(query['mascotaId'], 'm-1');
        expect(query['consultaId'], 'con-7');
      },
    );

    testWidgets('con CC vinculada: "Cobrada: CC-0012" + chip, sin Cobrar', (
      tester,
    ) async {
      final cobros = FakeCobrosRepository(
        vinculado: const CobroVinculado(
          id: 'cc-12',
          numero: 12,
          estado: EstadoCobro.pendiente,
        ),
      );
      await tester.pumpWidget(_appCobro(cobros: cobros));
      await tester.pumpAndSettle();
      await _expandir(tester);

      expect(find.text('Cobrada: CC-0012'), findsOneWidget);
      expect(find.byType(EstadoCobroChip), findsOneWidget);
      expect(find.text('Cobrar'), findsNothing);
      expect(
        cobros.llamadas.where((l) => l.metodo == 'cobroVinculado').last.args,
        {'citaId': null, 'consultaId': 'con-7'},
      );

      await tester.tap(find.text('Cobrada: CC-0012'));
      await tester.pumpAndSettle();
      expect(find.text('DETALLE cc-12'), findsOneWidget);
    });

    testWidgets('error de cobros: muestra "Cobrar" sin texto de error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _appCobro(cobros: FakeCobrosRepository(errorCobro: Exception('x'))),
      );
      await tester.pumpAndSettle();
      await _expandir(tester);

      expect(find.widgetWithText(TextButton, 'Cobrar'), findsOneWidget);
      expect(find.textContaining('No pudimos'), findsNothing);
    });

    testWidgets('solo lectura: candado y hoja del plan sin navegar', (
      tester,
    ) async {
      await tester.pumpWidget(_appCobro(plan: planSoloLectura));
      await tester.pumpAndSettle();
      await _expandir(tester);

      expect(
        find.descendant(
          of: find.widgetWithText(TextButton, 'Cobrar'),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cobrar'));
      await tester.pumpAndSettle();
      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(find.textContaining('NUEVO'), findsNothing);
    });

    testWidgets('sin dueño conocido no ofrece Cobrar', (tester) async {
      await tester.pumpWidget(
        _appCobro(mascotas: FakeMascotaRepository(error: Exception('x'))),
      );
      await tester.pumpAndSettle();
      await _expandir(tester);
      expect(find.text('Evolución'), findsOneWidget);
      expect(find.text('Cobrar'), findsNothing);
    });

    testWidgets('append-only: ninguna tarjeta ofrece Editar ni Eliminar', (
      tester,
    ) async {
      await tester.pumpWidget(_appCobro());
      await tester.pumpAndSettle();
      await _expandir(tester);
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Eliminar'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });
}
