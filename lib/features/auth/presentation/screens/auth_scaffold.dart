import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Shared wrapper for the three unauthenticated screens (login, register,
/// reset password). Renders the approved brand block (paw mark + "VetApp" +
/// tagline) above the screen's own [title]/[subtitle]/[children], per
/// 01-UI-SPEC.md.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.error,
    this.success,
  });

  final String title;
  final String subtitle;
  final String? error;
  final String? success;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.pets, size: 42, color: colorScheme.primary),
                  const SizedBox(height: AppSpacing.sm),
                  Text('VetApp', style: textTheme.displaySmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tu consultorio veterinario en el bolsillo',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(title, style: textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(subtitle, style: textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.lg),
                  if (error != null) ...[
                    Text(error!, style: TextStyle(color: colorScheme.error)),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (success != null) ...[
                    Text(success!, style: const TextStyle(color: AppColors.success)),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
