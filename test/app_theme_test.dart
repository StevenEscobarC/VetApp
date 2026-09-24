import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/core/theme/app_theme.dart';

void main() {
  group('AppTheme tokens', () {
    test('light colorScheme.primary is terracota', () {
      expect(AppTheme.light.colorScheme.primary, const Color(0xFFC67139));
    });

    test('light scaffoldBackgroundColor is crema', () {
      expect(AppTheme.light.scaffoldBackgroundColor, const Color(0xFFF5EAD8));
    });

    test('light colorScheme surface and outline match tokens', () {
      expect(AppTheme.light.colorScheme.surface, const Color(0xFFEEE7DB));
      expect(AppTheme.light.colorScheme.outline, const Color(0xFFDCD3C4));
    });

    test('light inputDecorationTheme.fillColor is surfaceMuted', () {
      expect(
        AppTheme.light.inputDecorationTheme.fillColor,
        const Color(0xFFEBDDC5),
      );
    });

    test('dark colorScheme.primary stays terracota and background is dark', () {
      expect(AppTheme.dark.colorScheme.primary, const Color(0xFFC67139));
      expect(AppTheme.dark.scaffoldBackgroundColor, const Color(0xFF1C1712));
    });

    test('light navigationBarTheme highlights selected icon in terracota', () {
      final iconTheme = AppTheme
          .light
          .navigationBarTheme
          .iconTheme
          ?.resolve({WidgetState.selected});
      expect(iconTheme?.color, const Color(0xFFC67139));
    });
  });

  group('AppTypography', () {
    test('headlineSmall uses Caprasimo at 20px', () {
      final style = AppTheme.light.textTheme.headlineSmall!;
      expect(style.fontFamily, contains('Caprasimo'));
      expect(style.fontSize, 20);
    });

    test('displaySmall uses Caprasimo at 28px', () {
      final style = AppTheme.light.textTheme.displaySmall!;
      expect(style.fontFamily, contains('Caprasimo'));
      expect(style.fontSize, 28);
    });

    test('titleLarge uses Caprasimo at 20px', () {
      final style = AppTheme.light.textTheme.titleLarge!;
      expect(style.fontFamily, contains('Caprasimo'));
      expect(style.fontSize, 20);
    });

    test('bodyLarge uses Figtree at 16px with 1.5 line height', () {
      final style = AppTheme.light.textTheme.bodyLarge!;
      expect(style.fontFamily, contains('Figtree'));
      expect(style.fontSize, 16);
      expect(style.height, 1.5);
    });

    test('labelLarge uses Figtree at 14px semibold', () {
      final style = AppTheme.light.textTheme.labelLarge!;
      expect(style.fontFamily, contains('Figtree'));
      expect(style.fontSize, 14);
      expect(style.fontWeight, FontWeight.w600);
    });

    test('no text style uses Noto', () {
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
