import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/utils/zona_bogota.dart';
import 'package:vetapp/features/appointments/domain/cita_solapes.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';
import 'package:vetapp/features/appointments/domain/motivos_cita.dart';

Cita _cita(
  String id,
  int h,
  int min,
  int dur, {
  EstadoCita estado = EstadoCita.pendiente,
  int dia = 30,
}) => Cita(
  id: id,
  clinicaId: 'cli-1',
  clienteId: 'c1',
  veterinarioId: 'v1',
  fechaHora: deBogota(2026, 9, dia, h, min),
  duracionMin: dur,
  modalidad: ModalidadCita.consultorio,
  motivo: 'Consulta general',
  estado: estado,
  clienteNombre: 'X',
  mascotas: const [],
);

DateTime _t(int h, int min, {int dia = 30}) => deBogota(2026, 9, dia, h, min);

void main() {
  group('solapa', () {
    test('back-to-back no se cruza', () {
      expect(solapa(_t(10, 0), 30, _t(10, 30), 30), isFalse);
    });
    test('parcial se cruza', () {
      expect(solapa(_t(10, 0), 30, _t(10, 15), 30), isTrue);
    });
    test('contenida se cruza', () {
      expect(solapa(_t(10, 0), 60, _t(10, 15), 15), isTrue);
    });
  });

  group('ocupaHorario', () {
    test('cancelada y noAsistio liberan el hueco', () {
      expect(ocupaHorario(EstadoCita.cancelada), isFalse);
      expect(ocupaHorario(EstadoCita.noAsistio), isFalse);
      expect(ocupaHorario(EstadoCita.pendiente), isTrue);
      expect(ocupaHorario(EstadoCita.confirmada), isTrue);
      expect(ocupaHorario(EstadoCita.completada), isTrue);
    });
  });

  group('solapesCon', () {
    final luna = _cita('luna', 10, 30, 30);
    final max = _cita('max', 10, 0, 30, estado: EstadoCita.cancelada);
    test('solo citas activas', () {
      final r = solapesCon(
        inicio: _t(10, 15),
        duracionMin: 30,
        citas: [max, luna],
      );
      expect(r.map((c) => c.id), ['luna']);
    });
    test('excluirId', () {
      final r = solapesCon(
        inicio: _t(10, 15),
        duracionMin: 30,
        citas: [luna],
        excluirId: 'luna',
      );
      expect(r, isEmpty);
    });
    test('noAsistio se ignora', () {
      final r = solapesCon(
        inicio: _t(10, 30),
        duracionMin: 30,
        citas: [_cita('n', 10, 30, 30, estado: EstadoCita.noAsistio)],
      );
      expect(r, isEmpty);
    });
    test('ordenadas por fechaHora', () {
      final r = solapesCon(
        inicio: _t(10, 0),
        duracionMin: 90,
        citas: [luna, _cita('a', 10, 0, 30)],
      );
      expect(r.map((c) => c.id), ['a', 'luna']);
    });
  });

  group('primerHuecoLibre', () {
    final luna = _cita('luna', 10, 30, 30);
    final dia = DateTime.utc(2026, 9, 30);

    test('hoy redondea al siguiente cuarto', () {
      expect(
        primerHuecoLibre(
          citas: [luna],
          dia: dia,
          ahora: _t(9, 35),
          duracionMin: 30,
        ),
        _t(9, 45),
      );
    });
    test('duración que choca salta a después de la cita', () {
      expect(
        primerHuecoLibre(
          citas: [luna],
          dia: dia,
          ahora: _t(9, 35),
          duracionMin: 60,
        ),
        _t(11, 0),
      );
    });
    test('cuarto exacto se conserva', () {
      expect(
        primerHuecoLibre(
          citas: const [],
          dia: dia,
          ahora: _t(10, 0),
          duracionMin: 30,
        ),
        _t(10, 0),
      );
    });
    test('otro día empieza a las 8:00', () {
      expect(
        primerHuecoLibre(
          citas: const [],
          dia: DateTime.utc(2026, 10, 2),
          ahora: _t(9, 35),
          duracionMin: 30,
        ),
        _t(8, 0, dia: 32),
      );
    });
    test('cita 8-9 empuja a las 9:00; cancelada no', () {
      final d = DateTime.utc(2026, 10, 2);
      DateTime t(int h) => deBogota(2026, 10, 2, h);
      Cita c(EstadoCita e) => Cita(
        id: 'x',
        clinicaId: 'c',
        clienteId: 'c',
        veterinarioId: 'v',
        fechaHora: t(8),
        duracionMin: 60,
        modalidad: ModalidadCita.consultorio,
        motivo: 'm',
        estado: e,
        clienteNombre: 'n',
        mascotas: const [],
      );
      expect(
        primerHuecoLibre(
          citas: [c(EstadoCita.pendiente)],
          dia: d,
          ahora: _t(9, 35),
          duracionMin: 30,
        ),
        t(9),
      );
      expect(
        primerHuecoLibre(
          citas: [c(EstadoCita.cancelada)],
          dia: d,
          ahora: _t(9, 35),
          duracionMin: 30,
        ),
        t(8),
      );
    });
    test('sin hueco devuelve null (nunca una hora que se cruza)', () {
      final llenas = [for (var h = 6; h < 23; h++) _cita('c$h', h, 0, 60)];
      expect(
        primerHuecoLibre(
          citas: llenas,
          dia: dia,
          ahora: _t(9, 35),
          duracionMin: 30,
        ),
        isNull,
      );
    });
    test('hoy después de las 22:00 no sugiere una hora pasada', () {
      expect(
        primerHuecoLibre(
          citas: const [],
          dia: dia,
          ahora: _t(23, 0),
          duracionMin: 30,
        ),
        isNull,
      );
      expect(
        primerHuecoLibre(
          citas: const [],
          dia: dia,
          ahora: _t(22, 5),
          duracionMin: 30,
        ),
        isNull,
      );
    });
    test('hoy antes de las 6:00 empieza a las 6:00 (mínimo del selector)', () {
      expect(
        primerHuecoLibre(
          citas: const [],
          dia: dia,
          ahora: _t(0, 10),
          duracionMin: 30,
        ),
        _t(6, 0),
      );
      expect(inicioBusquedaHueco(dia: dia, ahora: _t(0, 10)), _t(6, 0));
      expect(inicioBusquedaHueco(dia: dia, ahora: _t(23, 50)), _t(22, 0));
    });
  });

  group('motivos', () {
    test('tabla y duraciones', () {
      expect(motivosCita, hasLength(7));
      expect(motivosCita.first.label, 'Consulta general');
      expect(motivoPorDefecto, 'Consulta general');
      expect(duracionPorDefecto('Vacunación'), 15);
      expect(duracionPorDefecto('Cirugía'), 90);
      expect(duracionPorDefecto('Baño/peluquería'), 60);
      expect(duracionPorDefecto('???'), 30);
      expect(duracionesCita, [15, 30, 45, 60, 90, 120]);
    });
  });
}
