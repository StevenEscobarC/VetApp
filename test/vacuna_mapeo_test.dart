import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/widgets/status/dosis_estado_chip.dart';
import 'package:vetapp/features/vaccination/domain/duraciones.dart';
import 'package:vetapp/features/vaccination/domain/entities/carne.dart';
import 'package:vetapp/features/vaccination/domain/entities/protocolo.dart';
import 'package:vetapp/features/vaccination/domain/estado_dosis_ui.dart';
import 'package:vetapp/features/vaccination/domain/fecha_bd.dart';

Map<String, dynamic> _biologico(String codigo, String estado) => {
  'codigo_protocolo': codigo,
  'biologico_nombre': codigo,
  'tipo': 'vacuna',
  'ultima_dosis_id': 'd-$codigo',
  'ultima_fecha': '2026-01-10',
  'posicion': 1,
  'dosis_serie': 3,
  'proxima_fecha': '2026-02-01',
  'etiqueta_proxima': 'Dosis 2 de 3',
  'estado': estado,
  'dias_vencida': estado == 'vencida' ? 12 : 0,
  'ventana_dias': 3,
  'sugerir_reiniciar': false,
};

Map<String, dynamic> _dosis(
  String id,
  String codigo,
  String fecha, {
  bool anulada = false,
}) => {
  'id': id,
  'codigo_protocolo': codigo,
  'biologico_nombre': codigo,
  'tipo': 'vacuna',
  'fecha_aplicacion': fecha,
  'etiqueta_dosis': anulada ? null : 'Dosis 1 de 3',
  'es_ultima': !anulada,
  'producto': null,
  'lote': null,
  'observaciones': null,
  'externa': false,
  'clinica_externa': null,
  'es_refuerzo': false,
  'cita_id': null,
  'anulada': anulada,
  'motivo_anulacion': anulada ? 'Error de digitación' : null,
  'anulada_at': anulada ? '2026-03-01T15:00:00+00:00' : null,
  'veterinario': {'nombre': 'Laura Gómez', 'matricula': 'MP-123', 'activo': true},
};

Map<String, dynamic> _json(List<Map<String, dynamic>> bios) => {
  'hoy': '2026-10-02',
  'mascota': {
    'id': 'm1',
    'nombre': 'Luna',
    'especie': 'perro',
    'raza': 'Criolla',
    'fecha_nacimiento': '2025-01-01',
    'foto_path': null,
  },
  'dueno': {'nombre': 'María Pérez', 'telefono': '3001234567'},
  'clinica': {'nombre': 'Clínica Sol', 'ciudad': 'Bogotá'},
  'biologicos': bios,
  'dosis': [
    _dosis('a', 'polivalente', '2026-01-10'),
    _dosis('b', 'polivalente', '2026-03-10'),
    _dosis('c', 'polivalente', '2026-02-10', anulada: true),
  ],
};

void main() {
  test('fechaDeBd / fechaABd', () {
    expect(fechaDeBd('2026-10-02'), DateTime.utc(2026, 10, 2));
    expect(fechaABd(DateTime.utc(2026, 1, 5)), '2026-01-05');
  });

  group('Carne.desdeJson', () {
    final carne = Carne.desdeJson(
      _json([_biologico('polivalente', 'vencida'), _biologico('rabia', 'al_dia')]),
    );

    test('mapea cabecera y fechas date en UTC', () {
      expect(carne.hoy, DateTime.utc(2026, 10, 2));
      expect(carne.mascotaNombre, 'Luna');
      expect(carne.duenoNombre, 'María Pérez');
      expect(carne.clinicaNombre, 'Clínica Sol');
      expect(carne.fechaNacimiento, DateTime.utc(2025, 1, 1));
      expect(carne.biologicos.first.proximaFecha, DateTime.utc(2026, 2, 1));
    });

    test('peorEstado y pendientes', () {
      expect(carne.peorEstado, EstadoCarne.vencida);
      expect(carne.pendientes, 1);
    });

    test('historialDe ordena por fecha desc y mapea anulada', () {
      final h = carne.historialDe('polivalente');
      expect(h.map((d) => d.id), ['b', 'c', 'a']);
      final anulada = h.firstWhere((d) => d.anulada);
      expect(anulada.etiquetaDosis, isNull);
      expect(anulada.motivoAnulacion, isNotNull);
      expect(anulada.anuladaAt, isNotNull);
      expect(h.first.veterinario!.matricula, 'MP-123');
    });

    test('sin biológicos peorEstado es null', () {
      expect(Carne.desdeJson(_json([])).peorEstado, isNull);
    });
  });

  test('estados', () {
    expect(estadoCarneDe('completo'), EstadoCarne.completo);
    expect(estadoCarneDe('al_dia'), EstadoCarne.alDia);
    expect(dosisEstadoDe(EstadoCarne.completo), DosisEstado.alDia);
    expect(dosisEstadoDe(EstadoCarne.vencida), DosisEstado.vencida);
    expect(tipoDosisDe('desparasitacion_externa'), TipoDosis.desparasitacionExterna);
  });

  test('textoVencimiento', () {
    final hoy = DateTime.utc(2026, 10, 2);
    expect(textoVencimiento(hoy, hoy), 'Vence hoy');
    expect(textoVencimiento(DateTime.utc(2026, 10, 6), hoy), 'Vence en 4 días');
    expect(textoVencimiento(DateTime.utc(2026, 10, 1), hoy), 'Venció hace 1 día');
    expect(
      textoVencimiento(DateTime.utc(2026, 9, 20), hoy),
      'Venció hace 12 días',
    );
  });

  test('etiquetaDuracion', () {
    expect(etiquetaDuracion(21), '21 días');
    expect(etiquetaDuracion(30), '1 mes');
    expect(etiquetaDuracion(35), '5 semanas');
    expect(etiquetaDuracion(84), '3 meses');
    expect(etiquetaDuracion(90), '3 meses');
    expect(etiquetaDuracion(180), '6 meses');
    expect(etiquetaDuracion(365), '1 año');
    expect(etiquetaDuracion(1095), '3 años');
    expect(etiquetaDuracion(17), '17 días');
  });

  test('Protocolo.desdeFila', () {
    final p = Protocolo.desdeFila({
      'codigo': 'otro:x',
      'nombre': 'X',
      'tipo': 'vacuna',
      'especies': ['perro'],
      'edad_min_dias': null,
      'dosis_serie': 1,
      'intervalo_serie_dias': null,
      'intervalo_refuerzo_dias': 365,
      'opciones_duracion_dias': [365],
      'personalizado': false,
      'es_semilla': true,
      'activo': true,
    });
    expect(p.esOtro, isTrue);
    expect(p.opcionesDuracionDias, [365]);
  });

  test('PendienteVacuna y resúmenes', () {
    const r = ResumenVacunasMascota(vencidas: 0, proximas: 2);
    expect(r.peor, EstadoCarne.proxima);
    expect(
      const ResumenVacunasMascota(vencidas: 1, proximas: 2).peor,
      EstadoCarne.vencida,
    );
  });
}
