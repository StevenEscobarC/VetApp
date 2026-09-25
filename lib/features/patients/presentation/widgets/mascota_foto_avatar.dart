import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/media/app_photo_picker.dart';
import '../providers/mascota_foto_providers.dart';

/// Resuelve la URL firmada para [fotoPath] (si existe) y la pasa a
/// [AppPhotoPicker] — usada tanto en la ficha (96px) como en las filas de
/// `PacientesListScreen` (56px, sin callbacks: la fila entera es el tap
/// target, no la miniatura). Mientras la URL carga o si falla, el picker
/// recibe `fotoPath: null` (placeholder de pata) — nunca una imagen rota.
class MascotaFotoAvatar extends ConsumerWidget {
  const MascotaFotoAvatar({
    super.key,
    this.fotoPath,
    this.size = 96,
    this.isUploading = false,
    this.onTomarFoto,
    this.onElegirGaleria,
  });

  final String? fotoPath;
  final double size;
  final bool isUploading;
  final VoidCallback? onTomarFoto;
  final VoidCallback? onElegirGaleria;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = fotoPath;
    if (path == null) {
      return _picker();
    }

    final urlAsync = ref.watch(mascotaFotoUrlProvider(path));
    return urlAsync.when(
      data: (url) => _picker(fotoPath: path, signedUrl: url),
      loading: _picker,
      error: (_, _) => _picker(),
    );
  }

  AppPhotoPicker _picker({String? fotoPath, String? signedUrl}) {
    return AppPhotoPicker(
      fotoPath: fotoPath,
      signedUrl: signedUrl,
      size: size,
      isUploading: isUploading,
      onTomarFoto: onTomarFoto,
      onElegirGaleria: onElegirGaleria,
    );
  }
}
