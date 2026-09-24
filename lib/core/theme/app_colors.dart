import 'package:flutter/material.dart';

/// VetApp visual system: terracota accents over a warm crema surface,
/// matching the approved mockup (`.planning/design/DESIGN-REFERENCE.md`).
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFC67139);
  static const Color primaryHover = Color(0xFFD67F48);
  static const Color primaryStrong = Color(0xFF8C491A);
  static const Color primaryText = Color(0xFF643312);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Legacy field names kept so existing widgets keep compiling, re-valued
  // onto the new terracota/crema palette.
  static const Color secondary = Color(0xFFEBDDC5); // surfaceMuted (nav pill)
  static const Color onSecondary = Color(0xFF8C491A); // primaryStrong
  static const Color accent = Color(0xFFD67F48);
  static const Color onAccent = Color(0xFFFFFFFF);

  static const Color background = Color(0xFFF5EAD8);
  static const Color backgroundAlt = Color(0xFFF0EEE6);
  static const Color surface = Color(0xFFEEE7DB);
  static const Color surfaceMuted = Color(0xFFEBDDC5);
  static const Color border = Color(0xFFDCD3C4);

  static const Color foreground = Color(0xFF201E1D);
  static const Color textSecondary = Color(0xFF474238);
  static const Color textMuted = Color(0xFF645C50);
  static const Color placeholder = Color(0xFF82796A);

  static const Color muted = Color(0xFFEBDDC5);
  static const Color mutedForeground = Color(0xFF645C50);

  static const Color destructive = Color(0xFFDC2626);
  static const Color onDestructive = Color(0xFFFFFFFF);
  static const Color warning = Color(0xFFD97706); // not in mockup extract
  static const Color success = Color(0xFF56633F);
  static const Color successBg = Color(0xFFF0FAE1);
  static const Color warningBg = Color(0xFFFFF2EB);

  static const Color ring = Color(0xFFC67139);

  // Dark mode: valores derivados, no aprobados en el mockup; reconfirmar en la Fase 8.
  static const Color backgroundDark = Color(0xFF1C1712);
  static const Color surfaceDark = Color(0xFF241E17);
  static const Color foregroundDark = Color(0xFFF5EAD8);
  static const Color mutedDark = Color(0xFF2E261D);
  static const Color mutedForegroundDark = Color(0xFF9C8F7B);
  static const Color borderDark = Color(0xFF3A2F23);
  static const Color textSecondaryDark = Color(0xFFC9BFAE);
}
