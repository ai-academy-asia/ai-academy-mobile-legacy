import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Dark Mode Phase 2 (Issue #256): every role's light value is written once,
/// in `lib/core/theme/app_colors.dart`. A colour literal elsewhere in `lib/`
/// with one of those values is a copy that a theme change would miss, so it
/// must alias the `AppColors` role (or move to `context.palette`) instead.
void main() {
  test('no AppColors value is repeated as a literal elsewhere in lib/', () {
    final literal = RegExp(r'Color\((0x[0-9A-Fa-f]{8})\)');
    String key(String hex) => hex.toUpperCase();

    final source = File('lib/core/theme/app_colors.dart').readAsStringSync();
    final roleValues = {
      for (final match in literal.allMatches(source)) key(match.group(1)!),
    };
    expect(roleValues, isNotEmpty);

    final copies = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('core/theme/app_colors.dart'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final match in literal.allMatches(lines[i])) {
          if (roleValues.contains(key(match.group(1)!))) {
            copies.add('${file.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
    }
    expect(copies, isEmpty, reason: copies.join('\n'));
  });
}
