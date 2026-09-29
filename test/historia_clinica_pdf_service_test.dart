import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/clinical_history/data/services/historia_clinica_pdf_service.dart';
import 'package:vetapp/features/clinical_history/domain/consulta_failure.dart';

import 'helpers/fake_consultas.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/fake_pdf.dart';

void main() {
  group('HistoriaClinicaPdfService.entradasDe', () {
    test(
      'incluye TODA la historia clínica en orden cronológico (D-04), no '
      'solo la consulta más reciente',
      () {
        final service = HistoriaClinicaPdfService(
          cargarFuentes: fuentesDePrueba,
        );

        final entradas = service.entradasDe(consultasRocky);

        expect(entradas, hasLength(3));
        expect(entradas.map((e) => e.fecha), [
          '20/02/2026',
          '12/04/2026',
          '05/08/2026',
        ]);
      },
    );

    test(
      "cada entrada tiene las 5 secciones fijas y usa 'Sin registrar' para "
      'los campos en blanco, nunca un valor vacío',
      () {
        final service = HistoriaClinicaPdfService(
          cargarFuentes: fuentesDePrueba,
        );

        final entradas = service.entradasDe(consultasRocky);

        for (final entrada in entradas) {
          expect(entrada.secciones.map((s) => s.etiqueta), [
            'Anamnesis',
            'Examen físico',
            'Diagnóstico',
            'Tratamiento',
            'Evolución',
          ]);
          for (final seccion in entrada.secciones) {
            expect(seccion.valor.trim(), isNotEmpty);
          }
        }

        final control = entradas.firstWhere((e) => e.fecha == '12/04/2026');
        final porEtiqueta = {
          for (final s in control.secciones) s.etiqueta: s.valor,
        };
        expect(porEtiqueta['Anamnesis'], 'Sin registrar');
        expect(porEtiqueta['Examen físico'], 'Sin registrar');
        expect(porEtiqueta['Evolución'], 'Sin registrar');
      },
    );

    test(
      'el examen físico de la consulta de Otitis incluye peso y '
      'temperatura formateados igual que la línea de tiempo',
      () {
        final service = HistoriaClinicaPdfService(
          cargarFuentes: fuentesDePrueba,
        );

        final entradas = service.entradasDe(consultasRocky);
        final otitis = entradas.firstWhere((e) => e.fecha == '20/02/2026');
        final examen = otitis.secciones
            .firstWhere((s) => s.etiqueta == 'Examen físico')
            .valor;

        expect(examen, contains('Peso: 4,2 kg'));
        expect(examen, contains('Temperatura: 38,5 °C'));
      },
    );
  });

  group('HistoriaClinicaPdfService.generar', () {
    test('devuelve bytes de un PDF válido con las fuentes de prueba', () async {
      final service = HistoriaClinicaPdfService(
        cargarFuentes: fuentesDePrueba,
      );

      final bytes = await service.generar(
        mascota: mascotaRocky,
        consultas: consultasRocky,
        generadoEn: DateTime(2026, 9, 26),
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test(
      'una mascota sin consultas también exporta un PDF válido, sin lanzar',
      () async {
        final service = HistoriaClinicaPdfService(
          cargarFuentes: fuentesDePrueba,
        );

        final bytes = await service.generar(
          mascota: mascotaLuna,
          consultas: const [],
          generadoEn: DateTime(2026, 9, 26),
        );

        expect(bytes, isNotEmpty);
        expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      },
    );

    test(
      'un fallo al cargar las fuentes se traduce siempre en el mismo '
      'ConsultaFailure',
      () async {
        final service = HistoriaClinicaPdfService(
          cargarFuentes: fuentesQueFallan,
        );

        await expectLater(
          service.generar(mascota: mascotaRocky, consultas: consultasRocky),
          throwsA(
            isA<ConsultaFailure>().having(
              (e) => e.message,
              'message',
              'No pudimos generar el PDF. Intenta de nuevo.',
            ),
          ),
        );
      },
    );
  });

  group('HistoriaClinicaPdfService.nombreArchivo', () {
    test('genera un nombre de archivo seguro a partir del nombre de la '
        'mascota', () {
      expect(
        HistoriaClinicaPdfService.nombreArchivo('Rocky'),
        'historia_clinica_Rocky.pdf',
      );
      expect(
        HistoriaClinicaPdfService.nombreArchivo('  Don Gato '),
        'historia_clinica_Don_Gato.pdf',
      );
      expect(
        HistoriaClinicaPdfService.nombreArchivo(''),
        'historia_clinica_paciente.pdf',
      );
    });
  });
}
