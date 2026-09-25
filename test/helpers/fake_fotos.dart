import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vetapp/core/utils/captura_foto.dart';
import 'package:vetapp/features/patients/data/datasources/mascota_foto_datasource.dart';

/// In-memory [MascotaFotoDatasource] stand-in so no test in this phase
/// touches real Supabase Storage. Mirrors [FakeMascotaRepository]'s "fixed
/// result or fixed error" shape (test/helpers/fake_mascotas.dart). [uploads]
/// logs every [upload] call as a (clinicaId, mascotaId) pair so tests can
/// assert exactly-once-after-create behavior without inspecting a real
/// Storage payload.
class FakeMascotaFotoDatasource implements MascotaFotoDatasource {
  FakeMascotaFotoDatasource({this.error});

  final Object? error;

  /// (clinicaId, mascotaId) pairs, in call order.
  final List<(String, String)> uploads = [];

  /// Object paths passed to [eliminar], in call order.
  final List<String> eliminados = [];

  @override
  Future<String> upload({
    required String clinicaId,
    required String mascotaId,
    required Uint8List bytes,
  }) async {
    uploads.add((clinicaId, mascotaId));
    if (error != null) throw error!;
    return '$clinicaId/$mascotaId/fake.jpg';
  }

  @override
  Future<String> signedUrlFor(String path) async {
    if (error != null) throw error!;
    return 'https://example.test/signed/$path?token=t';
  }

  @override
  Future<void> eliminar(String path) async {
    eliminados.add(path);
    if (error != null) throw error!;
  }
}

/// Valid 1x1 transparent PNG bytes (67 bytes) — safe to decode via
/// `Image.memory` in widget tests without triggering a decode error. Same
/// fixture used by the `transparent_image` pub.dev package. Not `const`:
/// `Uint8List.fromList` has no const constructor, so this is `final` — the
/// value is still a single, immutable, process-wide instance for tests.
final Uint8List kFotoPrueba = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Builds a fixed [CapturadorFoto] that always returns [bytes] (or `null`,
/// simulating a cancelled pick) — the test seam for `capturadorFotoProvider`.
CapturadorFoto capturadorFalso(Uint8List? bytes) {
  return (BuildContext context, FuenteFoto fuente) async => bytes;
}
