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
  ],
);

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
}
