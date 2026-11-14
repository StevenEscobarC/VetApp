import 'dart:async';
import 'dart:typed_data';

import 'package:vetapp/features/billing/data/services/cobro_pdf_service.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';

/// Registra cada llamada a `compartirCobroProvider` sin tocar el menú nativo
/// de compartir. Calza con el typedef `CompartirPdfConTexto` (clase
/// invocable): se pasa como `.call`.
class CompartirCobroFalso {
  CompartirCobroFalso({this.error});

  final Object? error;

  final List<({Uint8List bytes, String filename, String? texto})> llamadas = [];

  Future<void> call({
    required Uint8List bytes,
    required String filename,
    String? texto,
  }) async {
    llamadas.add((bytes: bytes, filename: filename, texto: texto));
    if (error != null) throw error!;
  }
}

/// [CobroPdfService] de prueba: bytes fijos o error fijo, cuenta las
/// generaciones y, con [bloqueo], espera antes de devolver (para ver el
/// estado "Generando PDF…").
class CobroPdfServiceFalso implements CobroPdfService {
  CobroPdfServiceFalso({this.error});

  final Object? error;
  Completer<void>? bloqueo;
  final List<Cobro> generados = [];

  @override
  Future<Uint8List> generar({
    required Cobro cobro,
    required ClinicaCobroPdf clinica,
    required DateTime generadoEn,
  }) async {
    generados.add(cobro);
    final b = bloqueo;
    if (b != null) await b.future;
    if (error != null) throw error!;
    return Uint8List.fromList([37, 80, 68, 70]);
  }
}
