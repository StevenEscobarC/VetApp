import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/utils/zona_bogota.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';
import 'package:vetapp/features/appointments/domain/recordatorios_plan.dart';

Cita _cita(
  String id,
  DateTime fecha, {
  EstadoCita estado = EstadoCita.pendiente,
  ModalidadCita modalidad = ModalidadCita.consultorio,
  List<String> mascotas = const ['Luna'],
}) => Cita(
  id: id,
  clinicaId: 'cli-1',
  clienteId: 'c-1',
  veterinarioId: 'vet-1',
  fechaHora: fecha,
  duracionMin: 30,
  modalidad: modalidad,
  direccion: modalidad == ModalidadCita.domicilio ? 'Calle 1 # 2-3' : null,
  motivo: 'Consulta',
  estado: estado,
  clienteNombre: 'María Pérez',
  clienteTelefono: '3001234567',
  mascotas: [
    for (final n in mascotas)
      MascotaDeCita(id: 'm-$n', nombre: n, especie: 'perro'),
  ],
);

void main() {
  final ahora = deBogota(2026, 9, 30, 9, 35);

  group('planificar', () {
    test('solo pendiente y confirmada', () {
      final citas = [
        for (final e in EstadoCita.values)
          _cita('c-${e.name}', deBogota(2026, 9, 30, 15), estado: e),
      ];
      final planes = planificar(citas, 60, ahora);
      expect(planes.map((p) => p.citaId).toSet(), {
        'c-pendiente',
        'c-confirmada',
      });
    });

    test('cuando = fechaHora - minutosAntes y omite pasados', () {
      final futura = _cita('f', deBogota(2026, 9, 30, 15));
      final pasada = _cita('p', deBogota(2026, 9, 30, 10, 0)); // cuando 09:00
      final planes = planificar([futura, pasada], 60, ahora);
      expect(planes, hasLength(1));
      expect(planes.single.citaId, 'f');
      expect(planes.single.cuando, deBogota(2026, 9, 30, 14));
    });

    test('excluye mas alla de 30 dias', () {
      final lejos = _cita('l', ahora.add(const Duration(days: 31)));
      expect(planificar([lejos], 60, ahora), isEmpty);
    });

    test('maximo 60 mas tempranas, ordenadas', () {
      final citas = [
        for (var i = 70; i >= 1; i--)
          _cita('c$i', ahora.add(Duration(hours: 2, minutes: i * 10))),
      ];
      final planes = planificar(citas, 60, ahora);
      expect(planes, hasLength(60));
      for (var i = 1; i < planes.length; i++) {
        expect(planes[i].cuando.isAfter(planes[i - 1].cuando), isTrue);
      }
      expect(planes.first.citaId, 'c1');
      expect(planes.last.citaId, 'c60');
    });
  });

  group('idNotificacion', () {
    test('determinista y fijado', () {
      const u = '00000000-0000-0000-0000-000000000000';
      expect(idNotificacion(u), idNotificacion(u));
      expect(idNotificacion(u), 1044877009);
    });

    test('rango y unicidad', () {
      final a = idNotificacion('aaaaaaaa-0000-0000-0000-000000000001');
      final b = idNotificacion('aaaaaaaa-0000-0000-0000-000000000002');
      expect(a, inInclusiveRange(0, 0x7fffffff));
      expect(b, inInclusiveRange(0, 0x7fffffff));
      expect(a, isNot(b));
    });
  });

  group('textos', () {
    test('titulo', () {
      expect(tituloRecordatorio(15), 'Cita en 15 min');
      expect(tituloRecordatorio(30), 'Cita en 30 min');
      expect(tituloRecordatorio(60), 'Cita en 1 hora');
      expect(tituloRecordatorio(120), 'Cita en 2 horas');
    });

    test('cuerpo consultorio', () {
      expect(
        cuerpoRecordatorio(_cita('a', deBogota(2026, 9, 30, 10, 30))),
        'Luna — María Pérez a las 10:30 a. m.',
      );
    });

    test('cuerpo domicilio', () {
      expect(
        cuerpoRecordatorio(
          _cita(
            'b',
            deBogota(2026, 9, 30, 15),
            modalidad: ModalidadCita.domicilio,
            mascotas: ['Rocky', 'Luna'],
          ),
        ),
        'Rocky y Luna — María Pérez a las 3:00 p. m. · A domicilio',
      );
    });

    test('payload solo lleva citaId', () {
      final p = planificar([_cita('x', deBogota(2026, 9, 30, 15))], 60, ahora);
      expect(p.single.citaId, 'x');
      expect(p.single.cuerpo, isNot(contains('3001234567')));
      expect(p.single.cuerpo, isNot(contains('Calle')));
    });
  });
}
