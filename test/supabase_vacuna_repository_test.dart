import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetapp/features/vaccination/data/repositories/supabase_vacuna_repository.dart';
import 'package:vetapp/features/vaccination/domain/entities/carne.dart';

import 'helpers/fake_vacunas.dart';

void main() {
  group('mensajeErrorVacuna', () {
    String m(String code) =>
        mensajeErrorVacuna(PostgrestException(message: 'raw', code: code));

    test('mapea códigos a español', () {
      expect(m('42501'), 'No tienes permiso para hacer esto en esta clínica.');
      expect(
        m('23503'),
        'La mascota, la cita o el biológico ya no existe. Actualiza e intenta de nuevo.',
      );
      expect(
        m('23514'),
        'Revisa los datos: la fecha no puede ser futura y los valores deben ser válidos.',
      );
      expect(m('23505'), 'Ya existe un registro igual.');
      expect(m('P0001'), 'No pudimos completar la operación. Intenta de nuevo.');
      expect(m('XX'), 'No pudimos completar la operación. Intenta de nuevo.');
    });
  });

  test('paramsRegistrarDosis incluye todas las llaves p_', () {
    final p = SupabaseVacunaRepository.paramsRegistrarDosis(
      mascotaId: 'm1',
      codigo: 'polivalente',
      biologicoNombre: 'Polivalente',
      fecha: DateTime.utc(2026, 1, 5),
      producto: '  ',
      lote: '',
      observaciones: ' ',
      clinicaExterna: '',
    );
    expect(p.keys.toSet(), {
      'p_mascota_id',
      'p_codigo_protocolo',
      'p_biologico_nombre',
      'p_fecha_aplicacion',
      'p_duracion_elegida_dias',
      'p_sin_refuerzo',
      'p_es_refuerzo',
      'p_inicia_serie',
      'p_externa',
      'p_clinica_externa',
      'p_producto',
      'p_lote',
      'p_observaciones',
      'p_cita_id',
      'p_guardar_en_catalogo',
    });
    expect(p['p_fecha_aplicacion'], '2026-01-05');
    expect(p['p_producto'], isNull);
    expect(p['p_lote'], isNull);
    expect(p['p_observaciones'], isNull);
    expect(p['p_clinica_externa'], isNull);
  });

  test('dedupeProductos conserva 5 distintos, el más reciente primero', () {
    final filas = [
      for (final (p, l) in [
        ('Nobivac', 'L9'),
        ('nobivac', 'L1'),
        ('Eurican', 'E1'),
        ('Rabisin', null),
        ('Vanguard', 'V1'),
        ('Duramune', 'D1'),
        ('Otra', 'O1'),
      ])
        {'producto': p, 'lote': l},
    ];
    final r = SupabaseVacunaRepository.dedupeProductos(filas);
    expect(r.map((e) => e.producto), [
      'Nobivac',
      'Eurican',
      'Rabisin',
      'Vanguard',
      'Duramune',
    ]);
    expect(r.first.lote, 'L9');
  });

  test('FakeVacunaRepository registra llamadas y lanza error', () async {
    final fake = FakeVacunaRepository();
    await fake.registrarDosis(
      mascotaId: 'm1',
      codigo: 'polivalente',
      biologicoNombre: 'Polivalente',
      fecha: DateTime.utc(2026, 1, 5),
    );
    expect(fake.llamadas.single.metodo, 'registrarDosis');
    expect(fake.llamadas.single.args['mascotaId'], 'm1');

    final f2 = FakeVacunaRepository(errorRegistrar: Exception('x'));
    expect(
      () => f2.registrarDosis(
        mascotaId: 'm1',
        codigo: 'a',
        biologicoNombre: 'A',
        fecha: DateTime.utc(2026, 1, 5),
      ),
      throwsException,
    );
    final t1 = await fake.regenerarEnlace('m1');
    final t2 = await fake.regenerarEnlace('m1');
    expect(t1, isNot(t2));
    await fake.gestionarAlerta(
      dosisRefId: 'd1',
      accion: AccionAlerta.posponer,
      dias: 7,
    );
    expect(fake.llamadas.last.metodo, 'gestionarAlerta');
    expect(fake.llamadas.last.args['dias'], 7);
  });
}
