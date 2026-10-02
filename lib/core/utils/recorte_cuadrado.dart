import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Recorta la imagen a un cuadrado centrado de [lado] px sobre fondo blanco y
/// la devuelve como PNG.
///
/// Es un recorte centrado sin recortador interactivo: evita una dependencia
/// nueva y los logos suelen venir centrados. Volver a dibujar la imagen en un
/// canvas descarta además los metadatos (EXIF/GPS) del archivo original. El
/// fondo blanco evita que un logo con transparencia quede negro al pasar a
/// JPEG.
Future<Uint8List> recortarCuadradoPng(Uint8List bytes, {int lado = 512}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final origen = frame.image;
  try {
    final ancho = origen.width.toDouble();
    final alto = origen.height.toDouble();
    final ladoOrigen = ancho < alto ? ancho : alto;
    final src = ui.Rect.fromLTWH(
      (ancho - ladoOrigen) / 2,
      (alto - ladoOrigen) / 2,
      ladoOrigen,
      ladoOrigen,
    );
    final dst = ui.Rect.fromLTWH(0, 0, lado.toDouble(), lado.toDouble());

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, dst);
    canvas.drawRect(dst, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    canvas.drawImageRect(
      origen,
      src,
      dst,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final salida = await picture.toImage(lado, lado);
    try {
      final data = await salida.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('No se pudo codificar la imagen');
      }
      return data.buffer.asUint8List();
    } finally {
      salida.dispose();
      picture.dispose();
    }
  } finally {
    origen.dispose();
    codec.dispose();
  }
}

/// [recortarCuadradoPng] seguido de compresión JPEG (512 px, calidad 85).
Future<Uint8List> recortarCuadradoJpeg(Uint8List bytes) async {
  final png = await recortarCuadradoPng(bytes);
  return FlutterImageCompress.compressWithList(
    png,
    minWidth: 512,
    minHeight: 512,
    quality: 85,
    format: CompressFormat.jpeg,
  );
}

typedef RecortadorCuadrado = Future<Uint8List> Function(Uint8List bytes);
