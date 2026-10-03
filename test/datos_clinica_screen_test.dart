import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetapp/core/utils/captura_foto.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/providers/recordatorios_providers.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/clinic/domain/clinica_failure.dart';
import 'package:vetapp/features/clinic/presentation/providers/clinica_providers.dart';
import 'package:vetapp/features/clinic/presentation/providers/datos_clinica_providers.dart';
import 'package:vetapp/features/clinic/presentation/screens/datos_clinica_screen.dart';
import 'package:vetapp/features/home/presentation/screens/mas_screen.dart';
import 'package:vetapp/features/patients/presentation/providers/mascota_foto_providers.dart';
import 'package:vetapp/features/team/presentation/equipo_routes.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_clinica.dart';
import 'helpers/fake_fotos.dart';
import 'helpers/fake_recordatorios.dart';
import 'helpers/fake_team.dart';
import 'helpers/router_harness.dart';

const _textoSoloAdmin =
    'Solo los administradores pueden cambiar los datos de la clínica.';

List<Override> _overrides(
  FakeClinicaRepository repo,
  FakeClinicaLogoDatasource logos,
  AuthProfile perfil, {
  CapturadorFoto? capturador,
  AuthProfileNotifier Function()? auth,
}) {
  SharedPreferences.setMockInitialValues({});
  return [
    authProfileProvider.overrideWith(
      auth ?? () => FakeAuthProfileNotifier(profile: perfil),
    ),
    clinicaRepositoryProvider.overrideWithValue(repo),
    clinicaLogoDatasourceProvider.overrideWithValue(logos),
    capturadorFotoProvider.overrideWithValue(
      capturador ?? capturadorFalso(kFotoPrueba),
    ),
    recortadorCuadradoProvider.overrideWithValue((Uint8List b) async => b),
    teamRepositoryProvider.overrideWithValue(
      FakeTeamRepository(miembrosFixture: []),
    ),
    citaRepositoryProvider.overrideWithValue(FakeCitaRepository()),
    recordatoriosServiceProvider.overrideWithValue(FakeRecordatoriosService()),
  ];
}

Future<void> _abrir(
  WidgetTester tester,
  FakeClinicaRepository repo,
  FakeClinicaLogoDatasource logos, {
  AuthProfile perfil = vetProfile,
  String initial = '/mas/clinica',
  CapturadorFoto? capturador,
  AuthProfileNotifier Function()? auth,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    routerHarness(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/mas',
          builder: (_, _) => const MasScreen(),
          routes: masTeamRoutes,
        ),
      ],
      overrides: _overrides(
        repo,
        logos,
        perfil,
        capturador: capturador,
        auth: auth,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Perfil cuya recarga queda en espera de [_RecargaPerfil.puerta]: simula el
/// refresco del perfil al volver a la app (AppLifecycleListener.onResume).
class _RecargaPerfil {
  Completer<void>? puerta;
}

class _AuthRecargable extends FakeAuthProfileNotifier {
  _AuthRecargable(this.recarga) : super(profile: vetProfile);

  final _RecargaPerfil recarga;

  @override
  Future<AuthProfile?> build() async {
    final puerta = recarga.puerta;
    if (puerta != null) await puerta.future;
    return super.build();
  }
}

void main() {
  testWidgets('admin ve los campos prellenados y Agregar logo', (tester) async {
    await _abrir(tester, FakeClinicaRepository(), FakeClinicaLogoDatasource());
    expect(find.text('Veterinaria El Roble'), findsOneWidget);
    expect(find.text('Medellín'), findsOneWidget);
    expect(find.text('Agregar logo'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);
    expect(find.text('Tomar foto'), findsOneWidget);
    expect(find.text('Quitar logo'), findsNothing);
  });

  testWidgets(
    'Tomar foto muestra la vista previa y guarda con la ruta subida',
    (tester) async {
      final repo = FakeClinicaRepository();
      final logos = FakeClinicaLogoDatasource();
      await _abrir(tester, repo, logos);
      await _tocar(tester, find.text('Tomar foto'));
      expect(find.byKey(const Key('logo-clinica')), findsOneWidget);
      await _tocar(tester, find.text('Guardar cambios'));
      expect(logos.subidas, hasLength(1));
      expect(repo.llamadasActualizar.single['logoPath'], logos.subidas.single);
      expect(find.text('Datos de la clínica guardados'), findsOneWidget);
    },
  );

  testWidgets('nombre vacío muestra error y no llama actualizar', (
    tester,
  ) async {
    final repo = FakeClinicaRepository();
    await _abrir(tester, repo, FakeClinicaLogoDatasource());
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Veterinaria El Roble'),
      '',
    );
    await _tocar(tester, find.text('Guardar cambios'));
    expect(find.text('Escribe el nombre de la clínica.'), findsOneWidget);
    expect(repo.llamadasActualizar, isEmpty);
  });

  testWidgets('Quitar logo y guardar envía logoPath null', (tester) async {
    final repo = FakeClinicaRepository(
      clinica: clinicaDePrueba.copyWith(logoPath: 'cli-1/logo-1.jpg'),
    );
    final logos = FakeClinicaLogoDatasource();
    await _abrir(tester, repo, logos);
    await _tocar(tester, find.text('Quitar logo'));
    await _tocar(tester, find.text('Guardar cambios'));
    expect(repo.llamadasActualizar.single['logoPath'], isNull);
    expect(logos.eliminados, ['cli-1/logo-1.jpg']);
  });

  testWidgets('error del servidor se muestra en línea y conserva el form', (
    tester,
  ) async {
    final repo = FakeClinicaRepository();
    await _abrir(tester, repo, FakeClinicaLogoDatasource());
    repo.error = const ClinicaFailure(_textoSoloAdmin);
    // Sólo falla actualizar: la clínica ya está cargada.
    await _tocar(tester, find.text('Guardar cambios'));
    expect(find.text(_textoSoloAdmin), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);
    expect(find.text('Veterinaria El Roble'), findsOneWidget);
  });

  testWidgets('no administrador ve solo lectura sin acciones', (tester) async {
    await _abrir(
      tester,
      FakeClinicaRepository(),
      FakeClinicaLogoDatasource(),
      perfil: vetColegaProfile,
    );
    expect(find.text('Veterinaria El Roble'), findsOneWidget);
    expect(find.text('Medellín'), findsOneWidget);
    expect(find.text(_textoSoloAdmin), findsOneWidget);
    expect(find.text('Guardar cambios'), findsNothing);
    expect(find.text('Tomar foto'), findsNothing);
    expect(find.text('Quitar logo'), findsNothing);
  });

  testWidgets('Más muestra Datos de la clínica y navega a /mas/clinica', (
    tester,
  ) async {
    await _abrir(
      tester,
      FakeClinicaRepository(),
      FakeClinicaLogoDatasource(),
      initial: '/mas',
    );
    expect(find.text('Datos de la clínica'), findsOneWidget);
    await _tocar(tester, find.text('Datos de la clínica'));
    expect(find.text('Nombre de la clínica'), findsOneWidget);
  });

  testWidgets('G6: la recarga del perfil al volver del selector conserva vista '
      'previa y campos editados', (tester) async {
    final repo = FakeClinicaRepository();
    final logos = FakeClinicaLogoDatasource();
    final recarga = _RecargaPerfil();
    final selector = Completer<Uint8List?>();
    await _abrir(
      tester,
      repo,
      logos,
      capturador: (_, _) => selector.future,
      auth: () => _AuthRecargable(recarga),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, '3001234567'),
      '30012345709',
    );
    await _tocar(tester, find.text('Elegir de galería'));

    // La app pasa a segundo plano por la galería y al volver se relee el
    // perfil: miClinicaProvider se recarga mientras el selector sigue abierto.
    recarga.puerta = Completer<void>();
    ProviderScope.containerOf(
      tester.element(find.byType(DatosClinicaScreen)),
    ).invalidate(authProfileProvider);
    await tester.pump();
    expect(find.text('Guardar cambios'), findsOneWidget);
    recarga.puerta!.complete();
    await tester.pumpAndSettle();

    selector.complete(kFotoPrueba);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('logo-clinica')), findsOneWidget);
    expect(find.text('30012345709'), findsOneWidget);

    await _tocar(tester, find.text('Guardar cambios'));
    expect(logos.subidas, hasLength(1));
    final llamada = repo.llamadasActualizar.single;
    expect(llamada['logoPath'], logos.subidas.single);
    expect(llamada['telefono'], '30012345709');
    expect(find.text('Datos de la clínica guardados'), findsOneWidget);
  });
}
