import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
        final iconTheme = AppTheme.light.navigationBarTheme.iconTheme
            ?.resolve({WidgetState.selected});
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
}
