import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Figtree keeps headings warm and distinctive while Noto Sans maintains
/// readable density in tables, forms, and clinical notes.
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(Color foreground) {
    final headingBase = GoogleFonts.figtreeTextTheme();
    final bodyBase = GoogleFonts.notoSansTextTheme();

    final colored = bodyBase
        .copyWith(
          displayLarge: headingBase.displayLarge,
          displayMedium: headingBase.displayMedium,
          displaySmall: headingBase.displaySmall,
          headlineLarge: headingBase.headlineLarge,
          headlineMedium: headingBase.headlineMedium,
          headlineSmall: headingBase.headlineSmall,
          titleLarge: headingBase.titleLarge,
          titleMedium: headingBase.titleMedium,
          titleSmall: headingBase.titleSmall,
        )
        .apply(
          bodyColor: foreground,
          displayColor: foreground,
        );

    return colored.copyWith(
      displaySmall: colored.displaySmall?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: colored.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: colored.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: colored.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: colored.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      labelLarge: colored.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  static final TextTheme light = textTheme(AppColors.foreground);
  static final TextTheme dark = textTheme(AppColors.foregroundDark);
}
