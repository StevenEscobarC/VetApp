import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Colores de texto de Inicio según el brillo del tema: así ningún widget de
/// Inicio usa una constante de texto solo-claro y el modo oscuro sale bien
/// por construcción (UI-SPEC Color).
class InicioColores {
  InicioColores._();

  static bool _oscuro(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Cifras del mes: tono de dinero de la Fase 7, nunca el acento.
  static Color numero(BuildContext context) =>
      _oscuro(context) ? AppColors.primaryHover : AppColors.primaryText;

  /// "Hola,", mensajes de error y líneas meta.
  static Color secundario(BuildContext context) =>
      _oscuro(context) ? AppColors.textSecondaryDark : AppColors.textSecondary;

  /// Línea de clínica, kickers, chevrons.
  static Color tenue(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  /// Nombre y títulos.
  static Color principal(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  /// Barras de esqueleto (estáticas, sin shimmer).
  static Color esqueleto(BuildContext context) =>
      _oscuro(context) ? AppColors.mutedDark : AppColors.surfaceMuted;
}
