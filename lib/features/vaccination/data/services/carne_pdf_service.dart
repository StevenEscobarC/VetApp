import 'dart:ui' as ui;

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
import '../../domain/entities/carne.dart';
import '../../domain/entities/protocolo.dart';
import '../../domain/vacuna_failure.dart';

Future<({pw.Font regular, pw.Font bold})> _cargarFuentesReales() async {
  final regular = await PdfGoogleFonts.figtreeRegular();
  final bold = await PdfGoogleFonts.figtreeSemiBold();
  return (regular: regular, bold: bold);
}

/// Carga la fuente de display (Caprasimo) del PDF. Seam aparte del
/// [CargarFuentesPdf] compartido para no tocar el PDF de historia clínica.
typedef CargarFuenteDisplayPdf = Future<pw.Font> Function();

/// Descarga los bytes del logo de la clínica a partir de su ruta en storage.
typedef CargarLogoPdf = Future<Uint8List> Function(String path);

/// Decide si unos bytes son una imagen que el renderizador puede decodificar.
typedef ValidarImagenPdf = Future<bool> Function(Uint8List bytes);

/// Valida con `dart:ui` que [bytes] decodifican a una imagen; así unos bytes
/// corruptos nunca llegan a `pw.MemoryImage` ni rompen `doc.save()`.
Future<bool> imagenDecodificable(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      frame.image.dispose();
      return true;
    } finally {
      codec.dispose();
    }
  } catch (_) {
    return false;
  }
}

/// Nombre corto del propietario (D-20): primera palabra + inicial de la
/// segunda ('María F.'); igual que `_nombre_corto` en SQL.
String propietarioCorto(String nombre) {
  final p = nombre.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
  final l = p.toList();
  if (l.isEmpty) return '';
  if (l.length == 1) return l.first;
  return '${l.first} ${l[1].substring(0, 1).toUpperCase()}.';
}

PdfColor _color(int argb) => PdfColor.fromInt(argb);

/// Genera el certificado A4 del carné de vacunación (VAC-04, D-15..D-23).
/// Solo contiene datos mínimos: propietario como 'Nombre I.', sin teléfono
/// ni dirección del dueño, sin dosis anuladas ni historia clínica.
class CarnePdfService {
  CarnePdfService({
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

  /// Estilos Display 28 (nombre de la mascota) y Heading 20 ('Carné de
  /// vacunación') con la fuente de display (UI-SPEC Typography).
  @visibleForTesting
  static ({pw.TextStyle nombre, pw.TextStyle titulo}) estilosTitulo(
    pw.Font display,
  ) => (
    nombre: pw.TextStyle(font: display, fontSize: 28),
    titulo: pw.TextStyle(font: display, fontSize: 20),
  );

  Future<pw.Font> _fuenteDisplay(pw.Font respaldo) async {
    final cargar = _cargarFuenteDisplay;
    if (cargar == null) return respaldo;
    try {
      return await cargar();
    } catch (_) {
      return respaldo;
    }
  }

  /// Logo decodificado o null; nunca lanza (D-26, T-05-54).
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

  static const _columnas = [
    'Fecha',
    'Biológico',
    'Producto',
    'Lote',
    'Próxima',
    'Estado',
    'Aplicó',
  ];

  static String _estadoTexto(EstadoCarne e) => switch (e) {
    EstadoCarne.alDia => 'Al día',
    EstadoCarne.proxima => 'Próxima',
    EstadoCarne.vencida => 'Vencida',
    EstadoCarne.completo => 'Al día',
  };

  static String _aplico(DosisCarne d) {
    if (d.externa) return 'Otra clínica';
    final v = d.veterinario;
    if (v == null || v.nombre.trim().isEmpty) return '—';
    final mat = v.matricula?.trim();
    final base = 'Dr(a). ${v.nombre.trim()}';
    return (mat == null || mat.isEmpty) ? base : '$base · Mat. $mat';
  }

  /// Filas de las dos tablas (sin anuladas, D-23), de la más antigua a la
  /// más reciente. Próxima/Estado solo en la dosis vigente de cada
  /// biológico; el resto muestra '—'.
  @visibleForTesting
  static ({List<List<String>> vacunacion, List<List<String>> desparasitacion})
  filasPdf(Carne carne) {
    final vac = <List<String>>[];
    final desp = <List<String>>[];
    final vigentes = {for (final b in carne.biologicos) b.ultimaDosisId: b};
    final dosis = carne.dosis.where((d) => !d.anulada).toList()
      ..sort((a, b) => a.fechaAplicacion.compareTo(b.fechaAplicacion));
    for (final d in dosis) {
      final b = vigentes[d.id];
      final fila = [
        formatearFecha(d.fechaAplicacion),
        d.biologicoNombre,
        d.producto ?? '—',
        d.lote ?? '—',
        b?.proximaFecha == null ? '—' : formatearFecha(b!.proximaFecha!),
        b == null ? '—' : _estadoTexto(b.estado),
        _aplico(d),
      ];
      (d.tipo == TipoDosis.vacuna ? vac : desp).add(fila);
    }
    return (vacunacion: vac, desparasitacion: desp);
  }

  Future<Uint8List> generar({
    required Carne carne,
    required DateTime generadoEn,
  }) async {
    try {
      final fuentes = await _cargarFuentes();
      final display = await _fuenteDisplay(fuentes.bold);
      final titulos = estilosTitulo(display);
      final logo = await _logo(carne.clinicaLogoPath);
      final regular = pw.TextStyle(font: fuentes.regular, fontSize: 10);
      final bold = pw.TextStyle(font: fuentes.bold, fontSize: 10);
      final primary = _color(AppColors.primary.toARGB32());
      final filas = filasPdf(carne);
      final bogota = aBogota(generadoEn);
      final generado =
          'Generado el ${formatearFecha(bogota)} · ${hora12(bogota)}';

      final veterinarios = <String, String>{};
      for (final d in carne.dosis) {
        if (d.anulada || d.externa) continue;
        final v = d.veterinario;
        if (v == null || v.nombre.trim().isEmpty) continue;
        veterinarios.putIfAbsent(v.nombre.trim(), () => _aplico(d));
      }

      final nacimiento = carne.fechaNacimiento;
      final especieRaza = [
        carne.especie,
        if (carne.raza.trim().isNotEmpty) carne.raza.trim(),
      ].join(' · ');

      final doc = pw.Document(
        theme: pw.ThemeData.withFont(base: fuentes.regular, bold: fuentes.bold),
      );

      pw.Widget tabla(String titulo, List<List<String>> datos) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: 14),
            pw.Text(titulo, style: bold.copyWith(fontSize: 13)),
            pw.SizedBox(height: 6),
            if (datos.isEmpty)
              pw.Text('Sin registros.', style: regular)
            else
              pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.3),
                  1: pw.FlexColumnWidth(1.6),
                  2: pw.FlexColumnWidth(1.6),
                  3: pw.FlexColumnWidth(1.1),
                  4: pw.FlexColumnWidth(1.3),
                  5: pw.FlexColumnWidth(1.2),
                  6: pw.FlexColumnWidth(2.2),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: _color(AppColors.surfaceMuted.toARGB32()),
                    ),
                    children: [
                      for (final c in _columnas)
                        _celda(c, bold.copyWith(fontSize: 10)),
                    ],
                  ),
                  for (var i = 0; i < datos.length; i++)
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: i.isEven
                            ? _color(AppColors.surface.toARGB32())
                            : PdfColors.white,
                      ),
                      children: [
                        for (var j = 0; j < datos[i].length; j++)
                          if (j == 5 && datos[i][j] == 'Vencida')
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(3),
                              child: pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 1,
                                ),
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(
                                    color: _color(
                                      AppColors.destructive.toARGB32(),
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: pw.Text(
                                  datos[i][j],
                                  style: regular.copyWith(
                                    fontSize: 10,
                                    color: _color(
                                      AppColors.destructive.toARGB32(),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            _celda(datos[i][j], regular.copyWith(fontSize: 10)),
                      ],
                    ),
                ],
              ),
          ],
        );
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          header: (context) => pw.Column(
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (logo != null) ...[
                    pw.ClipRRect(
                      horizontalRadius: 4,
                      verticalRadius: 4,
                      child: pw.Image(
                        logo,
                        width: 36,
                        height: 36,
                        fit: pw.BoxFit.cover,
                      ),
                    ),
                    pw.SizedBox(width: 8),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          carne.clinicaNombre,
                          style: bold.copyWith(fontSize: 13),
                        ),
                        if (carne.clinicaCiudad.trim().isNotEmpty)
                          pw.Text(carne.clinicaCiudad, style: regular),
                      ],
                    ),
                  ),
                  pw.Text('Carné de vacunación', style: titulos.titulo),
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
            pw.Text(carne.mascotaNombre, style: titulos.nombre),
            pw.Text(especieRaza, style: regular),
            if (nacimiento != null)
              pw.Text('Nació el ${formatearFecha(nacimiento)}', style: regular),
            pw.Text(
              'Propietario: ${propietarioCorto(carne.duenoNombre)}',
              style: regular,
            ),
            tabla('Vacunación', filas.vacunacion),
            tabla('Desparasitación', filas.desparasitacion),
            if (veterinarios.isNotEmpty) ...[
              pw.SizedBox(height: 28),
              pw.Wrap(
                spacing: 24,
                runSpacing: 20,
                children: [
                  for (final v in veterinarios.entries)
                    pw.SizedBox(
                      width: 200,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(height: 1, color: PdfColors.black),
                          pw.SizedBox(height: 3),
                          pw.Text(v.value, style: regular),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      );

      return await doc.save();
    } catch (_) {
      throw const VacunaFailure('No pudimos generar el PDF. Intenta de nuevo.');
    }
  }

  static pw.Widget _celda(String texto, pw.TextStyle style) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 5),
    child: pw.Text(texto, style: style),
  );

  /// `Carne_{Mascota}_{yyyy-mm-dd}.pdf` con nombre saneado.
  static String nombreArchivo(String nombreMascota, DateTime fecha) {
    final limpio = nombreMascota
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final base = limpio.isEmpty ? 'paciente' : limpio;
    String dos(int n) => n.toString().padLeft(2, '0');
    return 'Carne_${base}_${fecha.year}-${dos(fecha.month)}-${dos(fecha.day)}.pdf';
  }
}
