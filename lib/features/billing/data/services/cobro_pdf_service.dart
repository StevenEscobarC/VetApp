import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/utils/formato_hora.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../clinical_history/data/services/historia_clinica_pdf_service.dart'
    show CargarFuentesPdf;
import '../../../vaccination/data/services/carne_pdf_service.dart'
    show
        CargarFuenteDisplayPdf,
        CargarLogoPdf,
        ValidarImagenPdf,
        imagenDecodificable;
import '../../domain/cobro_failure.dart';
import '../../domain/entities/cobro.dart';
import '../../domain/numeracion.dart';
import '../../domain/pesos_en_letras.dart';

Future<({pw.Font regular, pw.Font bold})> _cargarFuentesReales() async {
  final regular = await PdfGoogleFonts.figtreeRegular();
  final bold = await PdfGoogleFonts.figtreeSemiBold();
  return (regular: regular, bold: bold);
}

PdfColor _color(int argb) => PdfColor.fromInt(argb);

/// Textos del documento, separados por bloque. [CobroPdfService.textosPdf]
/// los aplana para los tests y `generar` los pinta: así la prueba revisa el
/// mismo contenido que se imprime sin tener que leer el PDF.
typedef _Textos = ({
  String titulo,
  String numero,
  String fecha,
  String clinica,
  List<String> clinicaLineas,
  bool anulada,
  String? etiquetaCliente,
  List<String> partes,
  String? debeA,
  String? laSuma,
  List<String> estado,
  String? emitidaPor,
});

/// Genera el PDF A4 de una cotización o cuenta de cobro (D-04, D-22..D-24),
/// de la misma familia visual que el carné. Solo imprime lo que el cliente
/// necesita: nunca su teléfono (D-24), y el título es lo único que dice qué
/// documento es (D-01: no es un documento tributario).
class CobroPdfService {
  CobroPdfService({
    CargarFuentesPdf? cargarFuentes,
    CargarFuenteDisplayPdf? cargarFuenteDisplay,
    CargarLogoPdf? cargarLogo,
    ValidarImagenPdf? validarImagen,
    Duration timeoutLogo = const Duration(seconds: 5),
  }) : _cargarFuentes = cargarFuentes ?? _cargarFuentesReales,
       _cargarFuenteDisplay = cargarFuenteDisplay,
       _cargarLogo = cargarLogo,
       _validarImagen = validarImagen ?? imagenDecodificable,
       _timeoutLogo = timeoutLogo;

  final CargarFuentesPdf _cargarFuentes;
  final CargarFuenteDisplayPdf? _cargarFuenteDisplay;
  final CargarLogoPdf? _cargarLogo;
  final ValidarImagenPdf _validarImagen;
  final Duration _timeoutLogo;

  static const _columnas = [
    'Descripción',
    'Cant.',
    'Valor unitario',
    'Subtotal',
  ];

  Future<pw.Font> _fuenteDisplay(pw.Font respaldo) async {
    final cargar = _cargarFuenteDisplay;
    if (cargar == null) return respaldo;
    try {
      return await cargar();
    } catch (_) {
      return respaldo;
    }
  }

  /// Logo decodificado o null; nunca lanza. La ruta llega null del servidor
  /// cuando el plan no permite logo.
  Future<pw.MemoryImage?> _logo(String? path) async {
    final cargar = _cargarLogo;
    if (path == null || path.isEmpty || cargar == null) return null;
    try {
      final bytes = await cargar(path).timeout(_timeoutLogo);
      if (!await _validarImagen(bytes)) return null;
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  static String? _lleno(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static _Textos _textos(Cobro c, ClinicaCobroPdf clinica) {
    final nit = _lleno(clinica.nit);
    final nitTexto = nit == null ? null : formatearNit(nit);
    final direccion = [
      ?_lleno(clinica.direccion),
      ?_lleno(clinica.ciudad),
    ].join(' · ');
    final tel = _lleno(clinica.telefono);
    final cedula = _lleno(c.clienteCedula);
    final mascota = _lleno(c.mascotaNombre);
    final nombreClinica = clinica.nombre.trim();

    final estado = <String>[];
    if (c.anulada) {
      final cuando = c.anuladaAt;
      final frase = StringBuffer('Anulada');
      if (cuando != null) {
        frase.write(' el ${formatearFecha(diaBogota(cuando))}');
      }
      frase.write('.');
      final motivo = _lleno(c.motivoAnulacion);
      if (motivo != null) frase.write(' Motivo: $motivo');
      estado.add(frase.toString());
    } else if (c.esCotizacion) {
      final v = c.validaHasta;
      if (v != null) {
        estado.add(
          'Válida por $kDiasValidezCotizacion días, hasta el '
          '${formatearFecha(v)}.',
        );
      }
      final n = c.convertidaEnNumero;
      if (c.convertida && n != null) {
        estado.add(
          'Convertida en ${formatearNumeroCobro(TipoCobro.cuentaCobro, n)}',
        );
      }
    } else if (c.pagada) {
      estado.add(
        [
          'Estado: Pagada',
          if (c.pagadaEl != null) ' el ${formatearFecha(c.pagadaEl!)}',
          if (c.metodoPago != null) ' · ${c.metodoPago!.etiqueta}',
        ].join(),
      );
    } else {
      estado.add('Estado: Pendiente de pago');
    }

    final autor = _lleno(c.autorNombre);
    return (
      titulo: c.tipo.etiqueta,
      numero: c.numeroTexto,
      fecha: 'Fecha: ${formatearFecha(c.fecha)}',
      clinica: nombreClinica,
      clinicaLineas: [
        if (nitTexto != null) 'NIT o cédula: $nitTexto',
        if (direccion.isNotEmpty) direccion,
        if (tel != null) 'Tel. $tel',
      ],
      anulada: c.anulada,
      etiquetaCliente: c.esCuentaCobro ? 'Cliente' : null,
      partes: [
        if (c.esCuentaCobro) c.clienteNombre else 'Cliente: ${c.clienteNombre}',
        if (cedula != null) 'C.C. ${formatearCedula(cedula)}',
        if (mascota != null) 'Mascota: $mascota',
      ],
      debeA: c.esCuentaCobro
          ? 'Debe a: $nombreClinica'
                '${nitTexto == null ? '' : ', NIT o cédula $nitTexto'}'
          : null,
      laSuma: c.esCuentaCobro
          ? 'La suma de: ${pesosEnLetras(c.totalCop)} '
                '(${formatearCop(c.totalCop)})'
          : null,
      estado: estado,
      emitidaPor: autor == null ? null : 'Emitida por Dr(a). $autor',
    );
  }

  /// Cada texto fuera de la tabla, en el orden en que se lee el documento.
  @visibleForTesting
  static List<String> textosPdf(Cobro c, ClinicaCobroPdf clinica) {
    final t = _textos(c, clinica);
    return [
      t.titulo,
      if (t.anulada) 'ANULADA',
      t.numero,
      t.fecha,
      t.clinica,
      ...t.clinicaLineas,
      ?t.etiquetaCliente,
      ...t.partes,
      ?t.debeA,
      ?t.laSuma,
      ...t.estado,
      ?t.emitidaPor,
    ];
  }

  /// Filas de la tabla: descripción, cantidad, valor unitario y subtotal.
  @visibleForTesting
  static List<List<String>> filasPdf(Cobro c) => [
    for (final i in c.items)
      [
        i.descripcion,
        '${i.cantidad}',
        formatearCop(i.precioUnitarioCop),
        formatearCop(i.subtotalCop),
      ],
  ];

  Future<Uint8List> generar({
    required Cobro cobro,
    required ClinicaCobroPdf clinica,
    required DateTime generadoEn,
  }) async {
    try {
      final fuentes = await _cargarFuentes();
      final display = await _fuenteDisplay(fuentes.bold);
      final logo = await _logo(clinica.logoPath);
      final regular = pw.TextStyle(font: fuentes.regular, fontSize: 10);
      final bold = pw.TextStyle(font: fuentes.bold, fontSize: 10);
      final primary = _color(AppColors.primary.toARGB32());
      final destructive = _color(AppColors.destructive.toARGB32());
      final t = _textos(cobro, clinica);
      final filas = filasPdf(cobro);
      final bogota = aBogota(generadoEn);
      final generado =
          'Generado el ${formatearFecha(bogota)} · ${hora12(bogota)}';

      final doc = pw.Document(
        theme: pw.ThemeData.withFont(base: fuentes.regular, bold: fuentes.bold),
      );

      pw.Widget celda(
        String texto,
        pw.TextStyle style, {
        bool derecha = false,
      }) => pw.Container(
        constraints: const pw.BoxConstraints(minHeight: 22),
        alignment: derecha ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: pw.Text(texto, style: style),
      );

      final sello = pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: destructive, width: 1),
        ),
        child: pw.Text(
          'ANULADA',
          style: bold.copyWith(fontSize: 10, color: destructive),
        ),
      );

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          header: (context) => pw.Column(
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logo != null) ...[
                    pw.Image(logo, height: 48, fit: pw.BoxFit.contain),
                    pw.SizedBox(width: 8),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          t.clinica,
                          style: pw.TextStyle(font: display, fontSize: 18),
                        ),
                        for (final l in t.clinicaLineas)
                          pw.Text(l, style: regular),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          if (t.anulada) ...[sello, pw.SizedBox(width: 6)],
                          pw.Text(
                            t.titulo,
                            style: pw.TextStyle(font: display, fontSize: 16),
                          ),
                        ],
                      ),
                      pw.Text(t.numero, style: bold.copyWith(fontSize: 12)),
                      pw.Text(t.fecha, style: regular),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Container(height: 1, color: primary),
              pw.SizedBox(height: 10),
            ],
          ),
          footer: (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    generado,
                    style: regular.copyWith(fontSize: 8),
                  ),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: regular.copyWith(fontSize: 8),
                ),
                pw.Expanded(
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'Hecho con VetApp',
                      style: regular.copyWith(fontSize: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          build: (context) => [
            if (t.etiquetaCliente != null)
              pw.Text(t.etiquetaCliente!, style: regular),
            for (var i = 0; i < t.partes.length; i++)
              pw.Text(
                t.partes[i],
                style: i == 0 && t.etiquetaCliente != null ? bold : regular,
              ),
            if (t.debeA != null) ...[
              pw.SizedBox(height: 8),
              pw.Text(t.debeA!, style: bold),
            ],
            if (t.laSuma != null) pw.Text(t.laSuma!, style: regular),
            pw.SizedBox(height: 14),
            pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(3.4),
                1: pw.FlexColumnWidth(0.8),
                2: pw.FlexColumnWidth(1.6),
                3: pw.FlexColumnWidth(1.6),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: _color(AppColors.surfaceMuted.toARGB32()),
                  ),
                  children: [
                    for (var j = 0; j < _columnas.length; j++)
                      celda(_columnas[j], bold, derecha: j > 0),
                  ],
                ),
                for (var i = 0; i < filas.length; i++)
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i.isEven
                          ? _color(AppColors.surface.toARGB32())
                          : PdfColors.white,
                    ),
                    children: [
                      for (var j = 0; j < filas[i].length; j++)
                        celda(filas[i][j], regular, derecha: j > 0),
                    ],
                  ),
                pw.TableRow(
                  children: [
                    celda('Total', bold.copyWith(fontSize: 12)),
                    pw.SizedBox(),
                    pw.SizedBox(),
                    celda(
                      formatearCop(cobro.totalCop),
                      bold.copyWith(fontSize: 12),
                      derecha: true,
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            for (final e in t.estado)
              pw.Text(
                e,
                style: t.anulada
                    ? regular.copyWith(color: destructive)
                    : regular,
              ),
            if (t.emitidaPor != null) ...[
              pw.SizedBox(height: 14),
              pw.Text(t.emitidaPor!, style: regular),
            ],
          ],
        ),
      );

      return await doc.save();
    } catch (_) {
      throw const CobroFailure('No pudimos generar el PDF. Intenta de nuevo.');
    }
  }

  /// `Cuenta_de_cobro_CC-0012.pdf` / `Cotizacion_COT-0004.pdf`: sin datos
  /// personales en el nombre del archivo.
  static String nombreArchivo(Cobro c) {
    final base = c.esCotizacion ? 'Cotizacion' : 'Cuenta_de_cobro';
    return '${base}_${c.numeroTexto}.pdf';
  }
}
