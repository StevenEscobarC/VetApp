import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/core/theme/app_colors.dart';
import 'package:vetapp/core/theme/app_spacing.dart';
import 'package:vetapp/core/theme/app_theme.dart';

// Uses `testWidgets` (not plain `test`) so the fake-async test zone absorbs
// google_fonts' fire-and-forget network font fetch, matching the pattern
// already proven in test/widget_test.dart.
void main() {
  group('AppTheme tokens', () {
    testWidgets('light colorScheme.primary is terracota', (tester) async {
      expect(AppTheme.light.colorScheme.primary, const Color(0xFFC67139));
    });

    testWidgets('light scaffoldBackgroundColor is crema', (tester) async {
      expect(AppTheme.light.scaffoldBackgroundColor, const Color(0xFFF5EAD8));
    });

    testWidgets('light colorScheme surface and outline match tokens', (
      tester,
    ) async {
      expect(AppTheme.light.colorScheme.surface, const Color(0xFFEEE7DB));
      expect(AppTheme.light.colorScheme.outline, const Color(0xFFDCD3C4));
    });

    testWidgets('light inputDecorationTheme.fillColor is surfaceMuted', (
      tester,
    ) async {
      expect(
        AppTheme.light.inputDecorationTheme.fillColor,
        const Color(0xFFEBDDC5),
      );
    });

    testWidgets(
      'dark colorScheme.primary stays terracota and background is dark',
      (tester) async {
        expect(AppTheme.dark.colorScheme.primary, const Color(0xFFC67139));
        expect(AppTheme.dark.scaffoldBackgroundColor, const Color(0xFF1C1712));
      },
    );

    testWidgets(
      'light navigationBarTheme highlights selected icon in terracota',
      (tester) async {
        final iconTheme = AppTheme.light.navigationBarTheme.iconTheme?.resolve({
          WidgetState.selected,
        });
        expect(iconTheme?.color, const Color(0xFFC67139));
      },
    );
  });

  group('AppTypography', () {
    testWidgets('headlineSmall uses Caprasimo at 20px', (tester) async {
      final style = AppTheme.light.textTheme.headlineSmall!;
      expect(style.fontFamily, contains('Caprasimo'));
      expect(style.fontSize, 20);
    });

    testWidgets('displaySmall uses Caprasimo at 28px', (tester) async {
      final style = AppTheme.light.textTheme.displaySmall!;
      expect(style.fontFamily, contains('Caprasimo'));
      expect(style.fontSize, 28);
    });

    testWidgets('titleLarge uses Caprasimo at 20px', (tester) async {
      final style = AppTheme.light.textTheme.titleLarge!;
      expect(style.fontFamily, contains('Caprasimo'));
      expect(style.fontSize, 20);
    });

    testWidgets('bodyLarge uses Figtree at 16px with 1.5 line height', (
      tester,
    ) async {
      final style = AppTheme.light.textTheme.bodyLarge!;
      expect(style.fontFamily, contains('Figtree'));
      expect(style.fontSize, 16);
      expect(style.height, 1.5);
    });

    testWidgets('labelLarge uses Figtree at 14px semibold', (tester) async {
      final style = AppTheme.light.textTheme.labelLarge!;
      expect(style.fontFamily, contains('Figtree'));
      expect(style.fontSize, 14);
      expect(style.fontWeight, FontWeight.w600);
    });

    testWidgets('no text style uses Noto', (tester) async {
      final textTheme = AppTheme.light.textTheme;
      final styles = <TextStyle?>[
        textTheme.displayLarge,
        textTheme.displayMedium,
        textTheme.displaySmall,
        textTheme.headlineLarge,
        textTheme.headlineMedium,
        textTheme.headlineSmall,
        textTheme.titleLarge,
        textTheme.titleMedium,
        textTheme.titleSmall,
        textTheme.bodyLarge,
        textTheme.bodyMedium,
        textTheme.bodySmall,
        textTheme.labelLarge,
        textTheme.labelMedium,
        textTheme.labelSmall,
      ];
      for (final style in styles) {
        expect(style?.fontFamily?.contains('Noto') ?? false, isFalse);
      }
    });
  });

  group('component themes (08-02)', () {
    const sel = {WidgetState.selected};
    const none = <WidgetState>{};
    const dis = {WidgetState.disabled};

    BorderRadius radio(double r) => BorderRadius.circular(r);

    testWidgets('textButtonTheme foreground is AA in both modes', (
      tester,
    ) async {
      final light = AppTheme.light.textButtonTheme.style!;
      final dark = AppTheme.dark.textButtonTheme.style!;
      expect(light.foregroundColor?.resolve(none), AppColors.primaryText);
      expect(dark.foregroundColor?.resolve(none), AppColors.primaryHover);
      expect(
        light.minimumSize?.resolve(none),
        const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
      );
      expect(
        dark.minimumSize?.resolve(none),
        const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
      );
    });

    testWidgets('switchTheme uses brand tokens', (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final cs = theme.colorScheme;
        final s = theme.switchTheme;
        expect(s.thumbColor?.resolve(sel), cs.onPrimary);
        expect(s.trackColor?.resolve(sel), cs.primary);
        expect(s.trackColor?.resolve(none), cs.surfaceContainerHighest);
        expect(s.trackOutlineColor?.resolve(none), cs.outline);
      }
    });

    testWidgets('checkboxTheme uses brand tokens', (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final cs = theme.colorScheme;
        final c = theme.checkboxTheme;
        expect(c.fillColor?.resolve(sel), cs.primary);
        expect(c.checkColor?.resolve(sel), cs.onPrimary);
        expect(c.side?.color, cs.outline);
        final shape = c.shape as RoundedRectangleBorder;
        expect(shape.borderRadius, radio(AppSpacing.radiusSm));
      }
    });

    testWidgets('floatingActionButtonTheme uses brand tokens', (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final cs = theme.colorScheme;
        final f = theme.floatingActionButtonTheme;
        expect(f.backgroundColor, cs.primary);
        expect(f.foregroundColor, cs.onPrimary);
        final shape = f.shape as RoundedRectangleBorder;
        expect(shape.borderRadius, radio(AppSpacing.radiusLg));
        expect(f.extendedTextStyle, theme.textTheme.labelLarge);
      }
    });

    testWidgets('dialogTheme uses brand tokens', (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final cs = theme.colorScheme;
        final d = theme.dialogTheme;
        expect(d.backgroundColor, cs.surface);
        final shape = d.shape as RoundedRectangleBorder;
        expect(shape.borderRadius, radio(AppSpacing.radiusLg));
        expect(d.titleTextStyle, theme.textTheme.titleLarge);
        expect(d.contentTextStyle, theme.textTheme.bodyLarge);
      }
    });

    testWidgets('snackBarTheme uses brand tokens', (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final cs = theme.colorScheme;
        final s = theme.snackBarTheme;
        expect(s.backgroundColor, cs.onSurface);
        expect(s.contentTextStyle?.color, cs.surface);
        expect(
          s.contentTextStyle?.fontSize,
          theme.textTheme.bodyLarge?.fontSize,
        );
        expect(s.behavior, isNull);
      }
      expect(
        AppTheme.light.snackBarTheme.actionTextColor,
        AppColors.primaryHover,
      );
      expect(
        AppTheme.dark.snackBarTheme.actionTextColor,
        AppColors.primaryText,
      );
    });

    testWidgets('datePickerTheme uses brand tokens', (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final cs = theme.colorScheme;
        final d = theme.datePickerTheme;
        expect(d.backgroundColor, cs.surface);
        expect(d.headerBackgroundColor, cs.primary);
        expect(d.headerForegroundColor, cs.onPrimary);
        final shape = d.shape as RoundedRectangleBorder;
        expect(shape.borderRadius, radio(AppSpacing.radiusLg));
        expect(d.dayBackgroundColor?.resolve(sel), cs.primary);
        expect(d.dayForegroundColor?.resolve(sel), cs.onPrimary);
      }
    });

    testWidgets('bottomSheetTheme uses brand tokens', (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final cs = theme.colorScheme;
        final b = theme.bottomSheetTheme;
        expect(b.backgroundColor, cs.surface);
        expect(b.modalBackgroundColor, cs.surface);
        expect(b.dragHandleColor, cs.outline);
        final shape = b.shape as RoundedRectangleBorder;
        expect(
          shape.borderRadius,
          const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg),
          ),
        );
      }
    });

    testWidgets('outlinedButtonTheme disabled colors come from the scheme', (
      tester,
    ) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final cs = theme.colorScheme;
        final o = theme.outlinedButtonTheme.style!;
        expect(o.backgroundColor?.resolve(dis), cs.surfaceContainerHighest);
        expect(o.foregroundColor?.resolve(dis), cs.onSurfaceVariant);
        expect(o.foregroundColor?.resolve(none), cs.primary);
      }
    });
  });
}
