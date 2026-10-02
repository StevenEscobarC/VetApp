import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Iniciales de [nombre] (máximo dos); '?' si está vacío.
String inicialesDe(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (partes.isEmpty) return '?';
  return partes.take(2).map((p) => p[0].toUpperCase()).join();
}

/// Identidad visual de un veterinario: círculo con iniciales y un color de una
/// paleta de 4 (nunca el terracota de marca). El color nunca es la única señal
/// — siempre hay iniciales y una etiqueta semántica con el nombre completo —
/// para cumplir la regla `color-not-only`.
class VetAvatar extends StatelessWidget {
  const VetAvatar({
    super.key,
    required this.nombre,
    this.indice = 0,
    this.size = 40,
    this.retirado = false,
  });

  final String nombre;
  final int indice;
  final double size;
  final bool retirado;

  static const List<Color> _paleta = [
    AppColors.success,
    AppColors.vetSlate,
    AppColors.vetPlum,
    AppColors.primaryStrong,
  ];

  /// Color de paleta para [indice]; lo reusan las marcas de color por
  /// veterinario (p. ej. la franja de la tarjeta de cita).
  static Color colorDe(int indice) => _paleta[indice % _paleta.length];

  @override
  Widget build(BuildContext context) {
    final color = colorDe(indice);
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: retirado ? Colors.transparent : color,
        border: retirado ? Border.all(color: AppColors.border) : null,
      ),
      child: Text(
        inicialesDe(nombre),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: retirado ? AppColors.textMuted : AppColors.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return Semantics(
      label: 'Dr(a). $nombre',
      excludeSemantics: true,
      child: retirado
          ? Tooltip(message: 'Veterinario retirado', child: avatar)
          : avatar,
    );
  }
}
