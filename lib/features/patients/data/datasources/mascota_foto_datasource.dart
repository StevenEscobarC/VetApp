import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/mascota_failure.dart';

/// Acceso a Supabase Storage para fotos de mascotas — bucket privado
/// `mascota-fotos` (Plan 01), RLS clinic-scoped vía
/// `(storage.foldername(name))[1] = mi_clinica_id()`. [upload] siempre
/// devuelve y [signedUrlFor]/`mascotas.foto_path` siempre almacenan la
/// **ruta** del objeto, nunca la URL firmada — la URL expira (1h aquí), la
/// ruta no (02-RESEARCH.md Pitfall 1).
class MascotaFotoDatasource {
  MascotaFotoDatasource(this._client);

  final SupabaseClient _client;

  static const _bucket = 'mascota-fotos';

  /// Sube [bytes] a `{clinicaId}/{mascotaId}/{epoch}.jpg` y devuelve la ruta
  /// del objeto (nunca una URL firmada).
  Future<String> upload({
    required String clinicaId,
    required String mascotaId,
    required Uint8List bytes,
  }) async {
    final path =
        '$clinicaId/$mascotaId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return path;
    } on StorageException catch (_) {
      throw const MascotaFailure(
        'No pudimos subir la foto. Intenta de nuevo.',
      );
    } catch (_) {
      throw const MascotaFailure(
        'No pudimos subir la foto. Intenta de nuevo.',
      );
    }
  }

  /// URL firmada (1h) para leer el objeto en [path] — se genera de nuevo en
  /// cada lectura, nunca se persiste.
  Future<String> signedUrlFor(String path) async {
    try {
      return await _client.storage.from(_bucket).createSignedUrl(path, 3600);
    } on StorageException catch (_) {
      throw const MascotaFailure('No pudimos cargar la foto.');
    } catch (_) {
      throw const MascotaFailure('No pudimos cargar la foto.');
    }
  }

  /// Elimina el objeto en [path] (reemplazo de foto desde la ficha, Plan
  /// 08).
  Future<void> eliminar(String path) async {
    try {
      await _client.storage.from(_bucket).remove([path]);
    } on StorageException catch (_) {
      throw const MascotaFailure(
        'No pudimos subir la foto. Intenta de nuevo.',
      );
    } catch (_) {
      throw const MascotaFailure(
        'No pudimos subir la foto. Intenta de nuevo.',
      );
    }
  }
}
