import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/config/carne_config.dart';
import 'package:vetapp/features/vaccination/data/services/carne_pdf_service.dart';
import 'package:vetapp/features/vaccination/domain/entities/carne.dart';
import 'package:vetapp/features/vaccination/domain/entities/protocolo.dart';
import 'package:vetapp/features/vaccination/domain/vacuna_failure.dart';

import 'helpers/fake_pdf.dart';

DosisCarne _dosis(
  String id,
  String codigo,
  String nombre,
  TipoDosis tipo, {
  bool anulada = false,
  bool externa = false,
  bool esUltima = true,
  VeterinarioDosis? vet = const VeterinarioDosis(
    nombre: 'Laura Gómez',
    matricula: '12345',
    activo: true,
  ),
}) => DosisCarne(
  id: id,
  codigoProtocolo: codigo,
  biologicoNombre: nombre,
  tipo: tipo,
  fechaAplicacion: DateTime.utc(2026, 3, 12),
  esUltima: esUltima,
  producto: 'Producto $id',
  lote: 'L-$id',
  externa: externa,
  esRefuerzo: false,
  anulada: anulada,
  veterinario: vet,
);

Carne _carne() => Carne(
  hoy: DateTime.utc(2026, 10, 2),
  mascotaId: 'm-1',
  mascotaNombre: 'Luna',
  especie: 'perro',
  raza: 'Criollo',
  fechaNacimiento: DateTime.utc(2025, 3, 12),
  duenoNombre: 'María Fernanda Gómez',
  duenoTelefono: '3001234567',
  clinicaNombre: 'Clínica Patitas',
  clinicaCiudad: 'Bogotá',
  biologicos: [
    BiologicoCarne(
      codigoProtocolo: 'rabia',
      biologicoNombre: 'Rabia',
      tipo: TipoDosis.vacuna,
      ultimaDosisId: 'd1',
      ultimaFecha: DateTime.utc(2026, 3, 12),
      posicion: 1,
      dosisSerie: 1,
      proximaFecha: DateTime.utc(2027, 3, 12),
      etiquetaProxima: 'Refuerzo anual',
      estado: EstadoCarne.vencida,
      diasVencida: 3,
      ventanaDias: 0,
      sugerirReiniciar: false,
    ),
  ],
  dosis: [
    _dosis('d1', 'rabia', 'Rabia', TipoDosis.vacuna),
    _dosis('d2', 'parvo', 'Parvovirus', TipoDosis.vacuna, anulada: true),
    _dosis(
      'd3',
      'int',
      'Desparasitante interno',
      TipoDosis.desparasitacionInterna,
      externa: true,
      vet: null,
    ),
  ],
);

void main() {
  test('generar devuelve un PDF', () async {
    final bytes = await CarnePdfService(
      cargarFuentes: fuentesDePrueba,
    ).generar(carne: _carne(), generadoEn: DateTime.utc(2026, 10, 2, 15));
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('filasPdf excluye anuladas, separa tablas y marca externas', () {
    final f = CarnePdfService.filasPdf(_carne());
    expect(f.vacunacion.length, 1);
    expect(f.vacunacion.single.join('|'), contains('Rabia'));
    expect(
      f.vacunacion.single.join('|'),
      contains('Dr(a). Laura Gómez · Mat. 12345'),
    );
    expect(f.vacunacion.single.join('|'), contains('Vencida'));
    expect(f.desparasitacion.length, 1);
    expect(f.desparasitacion.single.last, 'Otra clínica');
    expect(f.desparasitacion.single.join('|'), isNot(contains('Parvovirus')));
  });

  test('propietarioCorto', () {
    expect(propietarioCorto('María Fernanda Gómez'), 'María F.');
    expect(propietarioCorto('Ana'), 'Ana');
  });

  test('fuentes que fallan -> VacunaFailure', () async {
    expect(
      CarnePdfService(
        cargarFuentes: fuentesQueFallan,
      ).generar(carne: _carne(), generadoEn: DateTime.utc(2026, 10, 2)),
      throwsA(
        isA<VacunaFailure>().having(
          (e) => e.message,
          'message',
          'No pudimos generar el PDF. Intenta de nuevo.',
        ),
      ),
    );
  });

  test('nombreArchivo', () {
    expect(
      CarnePdfService.nombreArchivo('Luna', DateTime.utc(2026, 10, 2)),
      'Carne_Luna_2026-10-02.pdf',
    );
  });

  test('urlCarne', () {
    final t = 'ab' * 32;
    expect(urlCarne(t), 'https://stevenescobarc.github.io/VetApp/c/#$t');
  });
}
