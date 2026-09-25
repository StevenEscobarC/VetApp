import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../buttons/app_button.dart';

/// Avatar circular camera-first para la foto de una mascota (D-05, PAT-03).
/// Prioridad de contenido: [localBytes] (vista previa local) > [fotoPath] +
/// [signedUrl] (foto ya subida) > placeholder de pata (sin foto). Tocar el
/// avatar (o su badge de cámara) llama a [onTomarFoto] directamente — nunca
/// abre un menú/bottom sheet intermedio. "Elegir de galería" es la única
/// acción secundaria, y solo aparece si [onElegirGaleria] no es null.
///
/// Regla no negociable: todo [CachedNetworkImage] construido aquí usa
/// `cacheKey: fotoPath` (la ruta estable del objeto), nunca la URL firmada
/// como clave — la URL cambia en cada `createSignedUrl` y sin `cacheKey` el
/// caché de disco nunca acierta (02-RESEARCH.md Pitfall 1).
class AppPhotoPicker extends StatelessWidget {
  const AppPhotoPicker({
    super.key,
    this.fotoPath,
    this.signedUrl,
    this.localBytes,
    this.size = 96,
    this.isUploading = false,
    this.onTomarFoto,
    this.onElegirGaleria,
  });

  final String? fotoPath;
  final String? signedUrl;
  final Uint8List? localBytes;
  final double size;
  final bool isUploading;
  final VoidCallback? onTomarFoto;
  final VoidCallback? onElegirGaleria;

  /// Construye la imagen de red cacheada correctamente — [cacheKey] SIEMPRE
  /// debe ser la ruta estable del objeto (`foto_path`), nunca [url] (la URL
  /// firmada).
  static Widget imagenRed({
    required String url,
    required String cacheKey,
    required double size,
  }) {
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        cacheKey: cacheKey,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => _placeholder(size),
        errorWidget: (_, _, _) => _placeholder(size),
      ),
    );
  }

  static Widget _placeholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.pets, color: AppColors.textMuted, size: size * 0.5),
    );
  }

  Widget _contenido() {
    if (localBytes != null) {
      return ClipOval(
        child: Image.memory(
          localBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    if (fotoPath != null && signedUrl != null) {
      return imagenRed(url: signedUrl!, cacheKey: fotoPath!, size: size);
    }
    return _placeholder(size);
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        Opacity(opacity: isUploading ? 0.5 : 1, child: _contenido()),
        if (isUploading)
          Positioned.fill(
            child: Center(
              child: SizedBox(
                width: size * 0.3,
                height: size * 0.3,
                child: const CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
        if (onTomarFoto != null)
          Positioned(
            bottom: 0,
            right: 0,
            child: Semantics(
              label: 'Tomar foto',
              child: Tooltip(
                message: 'Tomar foto',
                child: Container(
                  width: size * 0.32,
                  height: size * 0.32,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.onPrimary,
                    size: size * 0.18,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: onTomarFoto == null
              ? avatar
              : InkWell(
                  onTap: onTomarFoto,
                  customBorder: const CircleBorder(),
                  child: avatar,
                ),
        ),
        if (onElegirGaleria != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Elegir de galería',
            icon: Icons.photo_library_outlined,
            onPressed: onElegirGaleria,
            variant: AppButtonVariant.text,
            expand: false,
          ),
        ],
      ],
    );
  }
}
