import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/core/theme/app_theme.dart';
import 'package:vetapp/core/widgets/media/app_photo_picker.dart';

import 'helpers/fake_fotos.dart';

Widget _envuelto(Widget child) {
  return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
}

void main() {
  testWidgets('sin foto muestra el placeholder de pata y ninguna imagen', (
    tester,
  ) async {
    await tester.pumpWidget(_envuelto(const AppPhotoPicker()));
    await tester.pump();

    expect(find.byIcon(Icons.pets), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
    'con fotoPath+signedUrl construye un CachedNetworkImage con '
    'cacheKey == fotoPath',
    (tester) async {
      await tester.pumpWidget(
        _envuelto(
          const AppPhotoPicker(
            fotoPath: 'cli-1/m-1/1.jpg',
            signedUrl: 'https://example.test/signed?token=abc',
          ),
        ),
      );
      await tester.pump();

      final img = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(img.cacheKey, 'cli-1/m-1/1.jpg');
      expect(img.imageUrl, 'https://example.test/signed?token=abc');
    },
  );

  test('imagenRed construye un CachedNetworkImage con el cacheKey dado', () {
    final widget =
        AppPhotoPicker.imagenRed(
              url: 'https://example.test/signed?token=xyz',
              cacheKey: 'cli-1/m-2/2.jpg',
              size: 56,
            )
            as ClipOval;
    final image = widget.child as CachedNetworkImage;
    expect(image.cacheKey, 'cli-1/m-2/2.jpg');
    expect(image.imageUrl, 'https://example.test/signed?token=xyz');
  });

  testWidgets(
    'tocar el avatar llama a onTomarFoto una sola vez y no abre menú',
    (tester) async {
      var llamadas = 0;
      await tester.pumpWidget(
        _envuelto(AppPhotoPicker(onTomarFoto: () => llamadas++)),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Tomar foto'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.camera_alt_outlined));
      await tester.pump();

      expect(llamadas, 1);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    '"Elegir de galería" solo aparece cuando onElegirGaleria no es null y '
    'lo invoca al tocarlo',
    (tester) async {
      await tester.pumpWidget(_envuelto(const AppPhotoPicker()));
      await tester.pump();
      expect(find.text('Elegir de galería'), findsNothing);

      var llamadas = 0;
      await tester.pumpWidget(
        _envuelto(AppPhotoPicker(onElegirGaleria: () => llamadas++)),
      );
      await tester.pump();
      expect(find.text('Elegir de galería'), findsOneWidget);

      await tester.tap(find.text('Elegir de galería'));
      await tester.pump();
      expect(llamadas, 1);
    },
  );

  testWidgets(
    'isUploading muestra un spinner y localBytes muestra la vista previa',
    (tester) async {
      await tester.pumpWidget(
        _envuelto(AppPhotoPicker(localBytes: kFotoPrueba, isUploading: true)),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    },
  );
}
