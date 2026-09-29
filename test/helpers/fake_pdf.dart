import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

/// Fuentes offline para [HistoriaClinicaPdfService] en tests: los fonts
/// base14 (Helvetica) que trae el paquete `pdf` sin tocar la red, en vez de
/// `PdfGoogleFonts.notoSansRegular()`/`.notoSansBold()` (que descargan sobre
/// HTTPS en el primer uso) — mismo seam de test que `capturadorFalso`
/// (test/helpers/fake_fotos.dart) usa para `capturadorFotoProvider`.
Future<({pw.Font regular, pw.Font bold})> fuentesDePrueba() async {
  return (regular: pw.Font.helvetica(), bold: pw.Font.helveticaBold());
}

/// Simula una descarga de fuentes fallida (ej. sin red en el primer
/// export) — [HistoriaClinicaPdfService.generar] debe traducir esto en un
/// `ConsultaFailure`, nunca dejar la excepción cruda propagarse.
Future<({pw.Font regular, pw.Font bold})> fuentesQueFallan() {
  throw Exception('sin red');
}

/// Registra cada llamada a `compartirPdfProvider` sin tocar el share sheet
/// nativo del sistema operativo — mismo patrón "resultado fijo o error fijo
/// + bitácora de llamadas" que [FakeMascotaFotoDatasource]
/// (test/helpers/fake_fotos.dart). El método `call` calza con el typedef
/// `CompartirPdf`, así que una instancia de esta clase puede pasarse
/// directamente donde se espera esa función (clases invocables de Dart).
class CompartirPdfFalso {
  CompartirPdfFalso({this.error});

  final Object? error;

  /// Cada llamada, en el orden en que ocurrieron.
  final List<({Uint8List bytes, String filename})> llamadas = [];

  Future<void> call({
    required Uint8List bytes,
    required String filename,
  }) async {
    llamadas.add((bytes: bytes, filename: filename));
    if (error != null) throw error!;
  }
}
