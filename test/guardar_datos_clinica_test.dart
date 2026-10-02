import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/clinic/domain/clinica.dart';
import 'package:vetapp/features/clinic/domain/clinica_failure.dart';
import 'package:vetapp/features/clinic/presentation/providers/clinica_providers.dart';
import 'package:vetapp/features/clinic/presentation/providers/datos_clinica_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_clinica.dart';

const _conLogo = Clinica(
  id: 'cli-1',
  nombre: 'Veterinaria El Roble',
  ciudad: 'Medellín',
  direccion: 'Cra 70 # 45-12',
  telefono: '3001234567',
  logoPath: 'cli-1/logo-1.jpg',
);

({
  ProviderContainer c,
  FakeClinicaRepository repo,
  FakeClinicaLogoDatasource logos,
})
_armar(Clinica clinica, {ClinicaFailure? error}) {
  final repo = FakeClinicaRepository(clinica: clinica, error: error);
  final logos = FakeClinicaLogoDatasource();
  final c = ProviderContainer(
    overrides: [
      clinicaRepositoryProvider.overrideWithValue(repo),
      clinicaLogoDatasourceProvider.overrideWithValue(logos),
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
    ],
  );
  addTearDown(c.dispose);
  return (c: c, repo: repo, logos: logos);
}

void main() {
  final bytes = Uint8List.fromList([1, 2, 3]);

  test('logo nuevo: sube, actualiza con la ruta y borra el anterior', () async {
    final t = _armar(_conLogo);
    final r = await t.c
        .read(guardarDatosClinicaProvider)
        .call(
          actual: _conLogo,
          nombre: '  Nueva  ',
          ciudad: 'Bogotá ',
          direccion: ' Calle 1',
          telefono: '300 ',
          nuevoLogo: bytes,
        );
    expect(t.logos.subidas, hasLength(1));
    expect(
      t.repo.llamadasActualizar.single['logoPath'],
      t.logos.subidas.single,
    );
    expect(t.repo.llamadasActualizar.single['nombre'], 'Nueva');
    expect(t.repo.llamadasActualizar.single['ciudad'], 'Bogotá');
    expect(t.logos.eliminados, ['cli-1/logo-1.jpg']);
    expect(r.logoPath, t.logos.subidas.single);
  });

  test('quitarLogo: no sube, logoPath null, borra el anterior', () async {
    final t = _armar(_conLogo);
    await t.c
        .read(guardarDatosClinicaProvider)
        .call(
          actual: _conLogo,
          nombre: 'A',
          ciudad: '',
          direccion: '',
          telefono: '',
          quitarLogo: true,
        );
    expect(t.logos.subidas, isEmpty);
    expect(t.repo.llamadasActualizar.single['logoPath'], isNull);
    expect(t.logos.eliminados, ['cli-1/logo-1.jpg']);
  });

  test('sin cambios de logo: conserva la ruta y no borra nada', () async {
    final t = _armar(_conLogo);
    await t.c
        .read(guardarDatosClinicaProvider)
        .call(
          actual: _conLogo,
          nombre: 'A',
          ciudad: '',
          direccion: '',
          telefono: '',
        );
    expect(t.logos.subidas, isEmpty);
    expect(t.repo.llamadasActualizar.single['logoPath'], 'cli-1/logo-1.jpg');
    expect(t.logos.eliminados, isEmpty);
  });

  test('si actualizar falla borra el logo subido y no el anterior', () async {
    const falla = ClinicaFailure(
      'Solo los administradores pueden cambiar los datos de la clínica.',
    );
    final t = _armar(_conLogo, error: falla);
    await expectLater(
      t.c
          .read(guardarDatosClinicaProvider)
          .call(
            actual: _conLogo,
            nombre: 'A',
            ciudad: '',
            direccion: '',
            telefono: '',
            nuevoLogo: bytes,
          ),
      throwsA(same(falla)),
    );
    expect(t.logos.eliminados, t.logos.subidas);
    expect(t.logos.eliminados, isNot(contains('cli-1/logo-1.jpg')));
  });

  test('bytes demasiado grandes fallan antes de subir', () async {
    final t = _armar(_conLogo);
    await expectLater(
      t.c
          .read(guardarDatosClinicaProvider)
          .call(
            actual: _conLogo,
            nombre: 'A',
            ciudad: '',
            direccion: '',
            telefono: '',
            nuevoLogo: Uint8List(kMaxBytesLogo + 1),
          ),
      throwsA(
        isA<ClinicaFailure>().having(
          (e) => e.message,
          'message',
          'El logo es muy pesado. Prueba con otra imagen.',
        ),
      ),
    );
    expect(t.logos.subidas, isEmpty);
    expect(t.repo.llamadasActualizar, isEmpty);
  });

  test('falla al borrar el logo anterior se ignora', () async {
    final t = _armar(_conLogo);
    t.logos.errorEliminar = const ClinicaFailure('x');
    final r = await t.c
        .read(guardarDatosClinicaProvider)
        .call(
          actual: _conLogo,
          nombre: 'A',
          ciudad: '',
          direccion: '',
          telefono: '',
          quitarLogo: true,
        );
    expect(r.logoPath, isNull);
  });
}
