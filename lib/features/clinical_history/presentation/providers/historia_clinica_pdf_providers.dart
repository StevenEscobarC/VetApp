import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../data/services/historia_clinica_pdf_service.dart';
import '../../domain/consulta_failure.dart';

/// Instancia del servicio de PDF — sin estado propio, así que un
/// `Provider` simple es suficiente (no necesita `autoDispose`).
final historiaClinicaPdfServiceProvider = Provider<HistoriaClinicaPdfService>(
  (ref) => HistoriaClinicaPdfService(),
);

/// Entrega los bytes de un PDF al share sheet nativo del sistema operativo
/// — inyectable para que los tests nunca toquen el canal de plataforma
/// real (mismo patrón que `capturadorFotoProvider`,
/// lib/features/patients/presentation/providers/mascota_foto_providers.dart).
/// Solo el share nativo (Android `Intent.ACTION_SEND` / iOS
/// `UIActivityViewController`): nunca sube el archivo ni genera un link
/// público (D-05).
typedef CompartirPdf =
    Future<void> Function({required Uint8List bytes, required String filename});

final compartirPdfProvider = Provider<CompartirPdf>((ref) {
  return ({required Uint8List bytes, required String filename}) async {
    try {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (_) {
      throw const ConsultaFailure(
        'No pudimos generar el PDF. Intenta de nuevo.',
      );
    }
  };
});
