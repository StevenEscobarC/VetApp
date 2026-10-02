import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/widgets/status/app_status_chip.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';
import 'package:vetapp/features/appointments/presentation/estado_cita_ui.dart';

import 'helpers/fake_citas.dart';

Cita conMascotas(List<String> nombres) => citaLunaHoy.copyWith(
  mascotas: [
    for (final n in nombres)
      MascotaDeCita(id: 'id-$n', nombre: n, especie: 'perro'),
  ],
);

void main() {
  group('EstadoCita', () {
    test('desdeValor y valor', () {
      expect(EstadoCita.desdeValor('no_asistio'), EstadoCita.noAsistio);
      expect(EstadoCita.desdeValor('solicitada'), EstadoCita.pendiente);
      expect(EstadoCita.desdeValor('raro'), EstadoCita.pendiente);
      expect(EstadoCita.noAsistio.valor, 'no_asistio');
      expect(EstadoCita.confirmada.valor, 'confirmada');
    });

    test('esTerminal solo para completada/cancelada/noAsistio', () {
      expect(EstadoCita.pendiente.esTerminal, isFalse);
      expect(EstadoCita.confirmada.esTerminal, isFalse);
      expect(EstadoCita.completada.esTerminal, isTrue);
      expect(EstadoCita.cancelada.esTerminal, isTrue);
      expect(EstadoCita.noAsistio.esTerminal, isTrue);
    });

    test('estadoAStatus cubre todos los estados', () {
      expect(estadoAStatus(EstadoCita.pendiente), AppStatus.pending);
      expect(estadoAStatus(EstadoCita.confirmada), AppStatus.confirmed);
      expect(estadoAStatus(EstadoCita.completada), AppStatus.completed);
      expect(estadoAStatus(EstadoCita.cancelada), AppStatus.cancelled);
      expect(estadoAStatus(EstadoCita.noAsistio), AppStatus.noShow);
    });
  });

  group('ModalidadCita', () {
    test('desdeValor y valor', () {
      expect(ModalidadCita.desdeValor('domicilio'), ModalidadCita.domicilio);
      expect(ModalidadCita.desdeValor('consultorio'), ModalidadCita.consultorio);
      expect(ModalidadCita.domicilio.valor, 'domicilio');
    });
  });

  group('Cita', () {
    test('fin = fechaHora + duracionMin', () {
      expect(
        citaLunaHoy.fin,
        citaLunaHoy.fechaHora.add(const Duration(minutes: 30)),
      );
    });

    test('nombresMascotas', () {
      expect(conMascotas(['Luna']).nombresMascotas, 'Luna');
      expect(conMascotas(['Luna', 'Rocky']).nombresMascotas, 'Luna y Rocky');
      expect(
        conMascotas(['Luna', 'Rocky', 'Max']).nombresMascotas,
        'Luna, Rocky y Max',
      );
    });

    test('nombresMascotasCorto', () {
      expect(
        conMascotas(['Luna', 'Rocky', 'Max']).nombresMascotasCorto,
        'Luna, Rocky y 1 más',
      );
      expect(conMascotas(['Luna', 'Rocky']).nombresMascotasCorto, 'Luna y Rocky');
    });
  });

  group('Cita veterinario', () {
    test('copyWith cambia el vet y conserva veterinarioNombre', () {
      expect(citaColegaFixture.copyWith().veterinarioNombre, 'Luis Torres');
      expect(
        citaLunaHoy.copyWith(veterinarioId: 'vet-2').veterinarioId,
        'vet-2',
      );
    });
  });
}
