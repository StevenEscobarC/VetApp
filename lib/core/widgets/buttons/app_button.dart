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
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: switch (variant) {
                AppButtonVariant.primary => Theme.of(
                  context,
                ).colorScheme.onPrimary,
                _ => Theme.of(context).colorScheme.primary,
              },
            ),
          )
        : icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(label),
            ],
          );

    final button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
        onPressed: effectiveOnPressed,
        child: child,
      ),
      AppButtonVariant.outline => OutlinedButton(
        onPressed: effectiveOnPressed,
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: effectiveOnPressed,
        child: child,
      ),
      AppButtonVariant.destructive => TextButton(
        onPressed: effectiveOnPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.destructive,
          minimumSize: const Size(
            AppSpacing.touchTarget,
            AppSpacing.touchTarget,
          ),
        ),
        child: child,
      ),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
