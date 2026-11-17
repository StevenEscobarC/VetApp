import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

enum AppButtonVariant { primary, outline, text, destructive }

/// Reusable button covering the three variants the theme defines.
/// Handles a loading state (disables + spinner) so callers never
/// have to build that logic themselves.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.cuadrado = false,
    this.lado = AppSpacing.touchTarget,
    this.contenido,
    this.botonKey,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  /// Modo icono cuadrado (steppers): botón de [lado] x [lado] sin padding,
  /// que muestra solo el [icon] (o [contenido]) y expone [label] como
  /// semántica. Ignora [expand]. Sin Tooltip a propósito: robaría el
  /// long-press que usan los steppers.
  final bool cuadrado;

  /// Lado del botón en modo [cuadrado]; por defecto el touch target (48).
  final double lado;

  /// Reemplaza el hijo por defecto (icono/etiqueta) en cualquier modo, p. ej.
  /// icono + etiqueta corta, o etiqueta + chevron. [label] sigue dando la
  /// semántica.
  final Widget? contenido;

  /// Key reenviada al botón Material interno, para que los tests puedan
  /// encontrar el `OutlinedButton`/`ElevatedButton`/`TextButton` por key.
  final Key? botonKey;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final Widget child;
    if (isLoading) {
      child = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: switch (variant) {
            AppButtonVariant.primary => Theme.of(context).colorScheme.onPrimary,
            _ => Theme.of(context).colorScheme.primary,
          },
        ),
      );
    } else if (contenido != null) {
      child = contenido!;
    } else if (cuadrado) {
      child = icon == null ? Text(label) : Icon(icon, size: 20);
    } else if (icon == null) {
      child = Text(label);
    } else {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(label),
        ],
      );
    }

    final effectiveChild = cuadrado
        ? Semantics(label: label, excludeSemantics: true, child: child)
        : child;

    final squareStyle = cuadrado
        ? ButtonStyle(
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            minimumSize: WidgetStatePropertyAll(Size.square(lado)),
            fixedSize: WidgetStatePropertyAll(Size.square(lado)),
          )
        : null;

    final button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
        key: botonKey,
        onPressed: effectiveOnPressed,
        style: squareStyle,
        child: effectiveChild,
      ),
      AppButtonVariant.outline => OutlinedButton(
        key: botonKey,
        onPressed: effectiveOnPressed,
        style: squareStyle,
        child: effectiveChild,
      ),
      AppButtonVariant.text => TextButton(
        key: botonKey,
        onPressed: effectiveOnPressed,
        style: squareStyle,
        child: effectiveChild,
      ),
      AppButtonVariant.destructive => TextButton(
        key: botonKey,
        onPressed: effectiveOnPressed,
        style: _destructiveStyle(squareStyle),
        child: effectiveChild,
      ),
    };

    if (cuadrado) return button;
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  static ButtonStyle _destructiveStyle(ButtonStyle? squareStyle) {
    final base = TextButton.styleFrom(
      foregroundColor: AppColors.destructive,
      minimumSize: const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
    );
    // El estilo cuadrado (si aplica) gana sobre el tamaño mínimo base.
    return squareStyle?.merge(base) ?? base;
  }
}
