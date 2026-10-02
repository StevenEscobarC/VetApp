import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/clinica_failure.dart';

/// Storage del logo en el bucket privado `clinica-logos`. Siempre se maneja la
/// **ruta** del objeto, nunca la URL firmada. Cada logo nuevo usa una ruta
/// nueva (`{clinica_id}/logo-{epoch_ms}.jpg`, misma forma que el SQL) para que
/// el `cacheKey` cambie al reemplazarlo.
class ClinicaLogoDatasource {
  ClinicaLogoDatasource(this._client);

  final SupabaseClient _client;

  static const bucket = 'clinica-logos';

  static String rutaLogo(String clinicaId, int epochMs) =>
      '$clinicaId/logo-$epochMs.jpg';

  Future<String> upload({
    required String clinicaId,
    required Uint8List bytes,
  }) async {
    final path = rutaLogo(clinicaId, DateTime.now().millisecondsSinceEpoch);
    try {
      await _client.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      return path;
    } on StorageException catch (_) {
      throw const ClinicaFailure('No pudimos subir el logo. Intenta de nuevo.');
    } catch (_) {
      throw const ClinicaFailure('No pudimos subir el logo. Intenta de nuevo.');
    }
  }

  Future<String> signedUrlFor(String path) async {
    try {
      return await _client.storage.from(bucket).createSignedUrl(path, 3600);
    } on StorageException catch (_) {
      throw const ClinicaFailure('No pudimos cargar el logo.');
    } catch (_) {
      throw const ClinicaFailure('No pudimos cargar el logo.');
    }
  }

  /// Bytes del logo (los usa el PDF del carné).
  Future<Uint8List> descargar(String path) async {
    try {
      return await _client.storage.from(bucket).download(path);
    } on StorageException catch (_) {
      throw const ClinicaFailure('No pudimos cargar el logo.');
    } catch (_) {
      throw const ClinicaFailure('No pudimos cargar el logo.');
    }
  }

  Future<void> eliminar(String path) async {
    try {
      await _client.storage.from(bucket).remove([path]);
    } on StorageException catch (_) {
      throw const ClinicaFailure('No pudimos subir el logo. Intenta de nuevo.');
    } catch (_) {
      throw const ClinicaFailure('No pudimos subir el logo. Intenta de nuevo.');
    }
  }
}
