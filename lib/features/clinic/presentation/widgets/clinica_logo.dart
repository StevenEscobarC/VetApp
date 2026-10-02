import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../providers/clinica_providers.dart';

/// Logo cuadrado con esquinas redondeadas de la clínica (D-26). Prioridad:
/// [localBytes] > [logoPath] > nada. Sin logo o ante error no muestra
/// placeholder ni ícono: no ocupa espacio (solo reserva el cuadrado mientras
/// carga). El `cacheKey` es la ruta estable, nunca la URL firmada.
class ClinicaLogo extends ConsumerWidget {
  const ClinicaLogo({
    super.key,
    this.logoPath,
    this.localBytes,
    this.size = 40,
  });

  final String? logoPath;
  final Uint8List? localBytes;
  final double size;

  Widget _envolver(Widget imagen) {
    return KeyedSubtree(
      key: const Key('logo-clinica'),
      child: Semantics(
        label: 'Logo de la clínica',
        image: true,
        child: SizedBox.square(
          dimension: size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: imagen,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = localBytes;
    if (bytes != null) {
      return _envolver(
        Image.memory(bytes, width: size, height: size, fit: BoxFit.cover),
      );
    }
    final path = logoPath;
    if (path == null || path.isEmpty) return const SizedBox.shrink();

    return ref
        .watch(clinicaLogoUrlProvider(path))
        .when(
          data: (url) => _envolver(
            CachedNetworkImage(
              imageUrl: url,
              cacheKey: logoPath,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, _) => SizedBox.square(dimension: size),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          loading: () => SizedBox.square(dimension: size),
          error: (_, _) => const SizedBox.shrink(),
        );
  }
}
