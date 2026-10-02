import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/appointments/domain/filtro_agenda.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';

import 'helpers/fake_citas.dart';

void main() {
  group('citasVisibles', () {
    test('multiVet false devuelve todo sin importar el filtro', () {
      final r = citasVisibles(
        citasEquipoFixture,
        filtro: FiltroAgenda.mias,
        yoId: 'vet-1',
        multiVet: false,
      );
      expect(r, citasEquipoFixture);
    });

    test('mias descarta la cita del colega; todas la conserva', () {
      final mias = citasVisibles(
        citasEquipoFixture,
        filtro: FiltroAgenda.mias,
        yoId: 'vet-1',
        multiVet: true,
      );
      expect(mias, isNot(contains(citaColegaFixture)));
      expect(mias.length, citasSemanaFixture.length);
      final todas = citasVisibles(
        citasEquipoFixture,
        filtro: FiltroAgenda.todas,
        yoId: 'vet-1',
        multiVet: true,
      );
      expect(todas, contains(citaColegaFixture));
    });
  });

  test('filtroAgendaProvider empieza en mias y set cambia', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.listen(filtroAgendaProvider, (_, _) {});
    expect(c.read(filtroAgendaProvider), FiltroAgenda.mias);
    c.read(filtroAgendaProvider.notifier).set(FiltroAgenda.todas);
    expect(c.read(filtroAgendaProvider), FiltroAgenda.todas);
  });
}
