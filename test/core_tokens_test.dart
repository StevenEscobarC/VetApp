import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardas de fuente (08-02, DASH-04): los widgets de `lib/core/widgets` solo
/// usan tokens de [AppSpacing] para espacios, y la pantalla placeholder
/// eliminada en D-17 no reaparece en ningún archivo.
void main() {
  final gapLiteral = RegExp(r'SizedBox\((height|width): *[0-9]+(\.[0-9]+)?\)');
  final insetsLiteral = RegExp(
    r'EdgeInsets\.[a-zA-Z]+\([^)]*[^a-zA-Z_.0-9][0-9]+\b',
  );

  List<File> dartFiles(String root) => Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('lib/core/widgets has no numeric spacing literal', () {
    final hits = <String>[];
    for (final file in dartFiles('lib/core/widgets')) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (gapLiteral.hasMatch(line) || insetsLiteral.hasMatch(line)) {
          hits.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('the removed placeholder screen does not exist (D-17)', () {
    expect(
      File(
        'lib/features/home/presentation/screens/coming_soon_screen.dart',
      ).existsSync(),
      isFalse,
    );
  });

  test('no file in lib or test names the removed placeholder (D-17)', () {
    // Construidos por partes para que este archivo no se detecte a sí mismo.
    final banned = [
      ['Coming', 'Soon'].join(),
      ['Próxima', 'mente'].join(),
    ];
    final hits = <String>[];
    for (final file in [...dartFiles('lib'), ...dartFiles('test')]) {
      if (file.path.replaceAll('\\', '/').endsWith('core_tokens_test.dart')) {
        continue;
      }
      final text = file.readAsStringSync();
      for (final word in banned) {
        if (text.contains(word)) hits.add('${file.path}: $word');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
