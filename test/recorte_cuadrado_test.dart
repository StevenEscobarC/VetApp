import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/utils/recorte_cuadrado.dart';

Future<Uint8List> _png(int w, int h, ui.Color? color) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
  );
  if (color != null) {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..color = color,
    );
  }
  final img = await recorder.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<ui.Image> _decodificar(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

void main() {
  testWidgets('recorta un PNG 300x200 a 512x512', (tester) async {
    await tester.runAsync(() async {
      final entrada = await _png(300, 200, const ui.Color(0xFFCC5533));
      final salida = await recortarCuadradoPng(entrada);
      final img = await _decodificar(salida);
      expect(img.width, 512);
      expect(img.height, 512);
    });
  });

  testWidgets('un PNG transparente queda con fondo blanco opaco', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final entrada = await _png(100, 100, null);
      final salida = await recortarCuadradoPng(entrada);
      final img = await _decodificar(salida);
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final px = data!.buffer.asUint8List();
      expect(px.sublist(0, 4), [255, 255, 255, 255]);
    });
  });
}
