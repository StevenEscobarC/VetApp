import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Caprasimo (single weight, display/headings) paired with Figtree
/// (body/UI text) per the approved mockup — see
/// `.planning/design/DESIGN-REFERENCE.md`.
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(Color foreground) {
    final headingBase = GoogleFonts.caprasimoTextTheme();
    final bodyBase = GoogleFonts.figtreeTextTheme();

    final colored = bodyBase
        .copyWith(
          displayLarge: headingBase.displayLarge,
          displayMedium: headingBase.displayMedium,
          displaySmall: headingBase.displaySmall,
          headlineLarge: headingBase.headlineLarge,
          headlineMedium: headingBase.headlineMedium,
          headlineSmall: headingBase.headlineSmall,
          titleLarge: headingBase.titleLarge,
        )
        .apply(
          bodyColor: foreground,
          displayColor: foreground,
        );

    return colored.copyWith(
      displaySmall: colored.displaySmall?.copyWith(fontSize: 28, height: 1.2),
      headlineSmall: colored.headlineSmall?.copyWith(fontSize: 20, height: 1.2),
      titleLarge: colored.titleLarge?.copyWith(fontSize: 20, height: 1.2),
      bodyLarge: colored.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: colored.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      labelLarge: colored.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: colored.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  static final TextTheme light = textTheme(AppColors.foreground);
  static final TextTheme dark = textTheme(AppColors.foregroundDark);
}
