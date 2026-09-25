import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Origen de la foto — la cámara es el camino principal (D-05), la galería
/// una acción secundaria explícita.
enum FuenteFoto { camara, galeria }

/// Firma inyectable vía `capturadorFotoProvider` — permite a los tests
/// sustituir por completo la cámara/galería/compresión reales sin tocar
/// ningún plugin nativo.
typedef CapturadorFoto =
    Future<Uint8List?> Function(BuildContext context, FuenteFoto fuente);

/// Flujo completo de captura (D-05): pre-chequeo de permiso de cámara ->
/// abrir cámara o galería -> comprimir antes de subir. Devuelve `null` si
/// el veterinario cancela la selección o si el permiso de cámara quedó
/// permanentemente denegado (tras mostrar el diálogo de "Abrir
/// configuración").
Future<Uint8List?> capturarFotoComprimida(
  BuildContext context,
  FuenteFoto fuente,
) async {
  if (fuente == FuenteFoto.camara) {
    var status = await Permission.camera.status;
    if (status.isDenied) {
      status = await Permission.camera.request();
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      if (context.mounted) {
        await _mostrarDialogoPermisoDenegado(context);
      }
      return null;
    }
  }

  final source = fuente == FuenteFoto.camara
      ? ImageSource.camera
      : ImageSource.gallery;
  final XFile? picked = await ImagePicker().pickImage(
    source: source,
    imageQuality: 85,
    maxWidth: 1600,
  );
  if (picked == null) return null;

  final compressed = await FlutterImageCompress.compressWithFile(
    picked.path,
    minWidth: 1024,
    minHeight: 1024,
    quality: 80,
    format: CompressFormat.jpeg,
  );
  return compressed ?? await picked.readAsBytes();
}

Future<void> _mostrarDialogoPermisoDenegado(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: const Text(
        'VetApp necesita acceso a la cámara para tomar fotos. '
        'Ábrelo en Configuración.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            openAppSettings();
          },
          child: const Text('Abrir configuración'),
        ),
      ],
    ),
  );
}
