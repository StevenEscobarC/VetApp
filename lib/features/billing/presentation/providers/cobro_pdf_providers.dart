import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../clinic/presentation/providers/clinica_providers.dart';
import '../../data/services/cobro_pdf_service.dart';
import '../../domain/cobro_failure.dart';

final cobroPdfServiceProvider = Provider<CobroPdfService>(
  (ref) => CobroPdfService(
    cargarFuenteDisplay: () => PdfGoogleFonts.caprasimoRegular(),
    cargarLogo: (path) =>
        ref.read(clinicaLogoDatasourceProvider).descargar(path),
  ),
);

/// Entrega el PDF al menú nativo de compartir con un [texto] opcional que
/// acompaña al archivo (en WhatsApp llega como mensaje). Inyectable para que
/// los tests nunca toquen el canal de plataforma. Nunca sube el archivo ni
/// genera un enlace público (D-16).
typedef CompartirPdfConTexto =
    Future<void> Function({
      required Uint8List bytes,
      required String filename,
      String? texto,
    });

final compartirCobroProvider = Provider<CompartirPdfConTexto>((ref) {
  return ({
    required Uint8List bytes,
    required String filename,
    String? texto,
  }) async {
    try {
      await Printing.sharePdf(bytes: bytes, filename: filename, body: texto);
    } catch (_) {
      throw const CobroFailure(
        'No pudimos abrir el menú de compartir. Intenta de nuevo.',
      );
    }
  };
});
