import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/utils/formato.dart';
import '../../../patients/domain/entities/mascota.dart';
import '../../domain/consulta_failure.dart';
import '../../domain/entities/consulta.dart';
import '../../domain/formato_consulta.dart';

/// Carga las fuentes Unicode usadas por el PDF — inyectable para que los
/// tests nunca disparen la descarga real (`PdfGoogleFonts` va sobre HTTPS
/// en el primer uso). Mismo seam de test que [CapturadorFoto]
/// (lib/core/utils/captura_foto.dart) y `capturadorFotoProvider`.
typedef CargarFuentesPdf =
    Future<({pw.Font regular, pw.Font bold})> Function();

Future<({pw.Font regular, pw.Font bold})> _cargarFuentesReales() async {
  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  return (regular: regular, bold: bold);
}

/// Genera el PDF de TODA la historia clínica de un paciente (HIST-03,
/// D-04) — nunca una consulta individual: cada llamada a [generar]
/// recorre la lista completa de consultas de la mascota, no la más
/// reciente. El resultado solo se comparte por el share sheet nativo del
/// sistema operativo (`compartirPdfProvider`,
/// historia_clinica_pdf_providers.dart) — nunca por un canal orientado al
/// dueño ni por un link público (D-05).
class HistoriaClinicaPdfService {
  HistoriaClinicaPdfService({CargarFuentesPdf? cargarFuentes})
    : _cargarFuentes = cargarFuentes ?? _cargarFuentesReales;

  final CargarFuentesPdf _cargarFuentes;

  /// Una entrada por consulta, de la más antigua a la más reciente — un
  /// documento clínico se lee en orden cronológico (D-04), al contrario de
  /// `HistoriaClinicaTimeline`, que en pantalla muestra la más reciente
  /// primero. Ninguna sección queda con un valor vacío o solo espacios: usa
  /// 'Sin registrar' en su lugar (mismo criterio que la línea de tiempo).
  List<({String fecha, List<({String etiqueta, String valor})> secciones})>
  entradasDe(List<Consulta> consultas) {
    final ordenadas = List<Consulta>.of(consultas)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    return [
      for (final c in ordenadas)
        (
          fecha: formatearFecha(c.fecha),
          secciones: [
            (etiqueta: 'Anamnesis', valor: _oSinRegistrar(c.anamnesis)),
            (
              etiqueta: 'Examen físico',
              valor: c.examenFisico.estaVacio
                  ? 'Sin registrar'
                  : lineasExamenFisico(c.examenFisico).join('; '),
            ),
            (etiqueta: 'Diagnóstico', valor: c.diagnostico),
            (etiqueta: 'Tratamiento', valor: c.tratamiento),
            (etiqueta: 'Evolución', valor: _oSinRegistrar(c.evolucion)),
          ],
        ),
    ];
  }

  String _oSinRegistrar(String? texto) {
    final t = texto?.trim();
    return (t == null || t.isEmpty) ? 'Sin registrar' : t;
  }

  /// Ensambla y devuelve los bytes del PDF completo. Cualquier fallo
  /// (descarga de fuentes, ensamblado del documento, etc.) se traduce
  /// siempre en el mismo [ConsultaFailure] — nunca llega una excepción
  /// cruda a la pantalla. Una lista de [consultas] vacía es válida: produce
  /// un PDF con solo el encabezado del paciente y el mensaje de historial
  /// vacío (D-04), nunca lanza.
  Future<Uint8List> generar({
    required Mascota mascota,
    required List<Consulta> consultas,
    DateTime? generadoEn,
  }) async {
    try {
      final fuentes = await _cargarFuentes();
      final estiloRegular = pw.TextStyle(font: fuentes.regular);
      final estiloBold = pw.TextStyle(font: fuentes.bold);
      final entradas = entradasDe(consultas);
      final raza = mascota.raza;
      final fechaNacimiento = mascota.fechaNacimiento;

      final doc = pw.Document(
        theme: pw.ThemeData.withFont(base: fuentes.regular, bold: fuentes.bold),
      );

      doc.addPage(
        pw.MultiPage(
          header: (context) => pw.Text(
            'Historia clínica: ${mascota.nombre}',
            style: estiloBold.copyWith(fontSize: 16),
          ),
          footer: (context) => pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: estiloRegular.copyWith(fontSize: 9),
          ),
          build: (context) => [
            pw.Text('Especie: ${mascota.especie.etiqueta}', style: estiloRegular),
            pw.Text(
              'Raza: ${(raza == null || raza.isEmpty) ? 'Sin registrar' : raza}',
              style: estiloRegular,
            ),
            pw.Text(
              'Fecha de nacimiento: '
              '${fechaNacimiento == null ? 'Sin registrar' : formatearFecha(fechaNacimiento)}',
              style: estiloRegular,
            ),
            pw.Text(
              'Dueño: ${mascota.duenoNombre ?? 'Sin registrar'}',
              style: estiloRegular,
            ),
            pw.Text(
              'Generado el ${formatearFecha(generadoEn ?? DateTime.now())}',
              style: estiloRegular,
            ),
            pw.SizedBox(height: 12),
            pw.Divider(),
            if (entradas.isEmpty)
              pw.Text('Aún no hay consultas registradas', style: estiloRegular)
            else
              for (final entrada in entradas) ...[
                pw.SizedBox(height: 8),
                pw.Text(entrada.fecha, style: estiloBold),
                for (final seccion in entrada.secciones)
                  pw.Text(
                    '${seccion.etiqueta}: ${seccion.valor}',
                    style: estiloRegular,
                  ),
                pw.Divider(),
              ],
          ],
        ),
      );

      return doc.save();
    } catch (_) {
      throw const ConsultaFailure(
        'No pudimos generar el PDF. Intenta de nuevo.',
      );
    }
  }

  /// Nombre de archivo seguro a partir de [nombreMascota]: recorta
  /// espacios, reemplaza cualquier carácter fuera de `[A-Za-z0-9]` por
  /// `_`, y recorta guiones bajos sobrantes en los extremos. Un nombre
  /// vacío después de limpiar cae en 'paciente'.
  static String nombreArchivo(String nombreMascota) {
    final limpio = nombreMascota
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final base = limpio.isEmpty ? 'paciente' : limpio;
    return 'historia_clinica_$base.pdf';
  }
}
