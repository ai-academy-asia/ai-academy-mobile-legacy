import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Dark Mode Phase 9 (Issue #276): Login, Reset Password, the manager
/// contact sheet, the sign-out dialog and Splash read their colours only
/// through `context.palette`. No earlier phase migrated `auth/` or
/// `splash/`; the candidate dark theme showed Login still light.
///
/// Every `.dart` file under `lib/features/auth/presentation/` and
/// `lib/features/splash/presentation/` is scanned, with the Teacher guard's
/// three checks and one exception, below.
void main() {
  final legacy = RegExp(
    r'\b(AppColors|HomePalette|PaymentFlowPalette|JuniorPalette'
    r'|TeacherScheduleColors|GradebookColors|TeacherPillColors'
    r'|TeacherHomeColors)\b'
    r'|\bColor\(0x[0-9A-Fa-f]+\)'
    r'|\bColor\.from(ARGB|RGBO)\('
    // `Colors.transparent` is no colour at all, so it reads the same in
    // every theme.
    r'|\bColors\.(?!transparent\b)\w+'
    r'|\.colorScheme\b'
    r'|\b(primaryColor|canvasColor|scaffoldBackgroundColor|cardColor'
    r'|dividerColor|disabledColor)\b',
  );

  bool isComment(String line) => line.trimLeft().startsWith('//');

  const roots = [
    'lib/features/auth/presentation/',
    'lib/features/splash/presentation/',
  ];

  Map<String, String> sources() => {
    for (final root in roots)
      for (final file in Directory(
        root,
      ).listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart'))
          file.path.substring('lib/features/'.length): file.readAsStringSync(),
  };

  int lineOf(String source, int offset) =>
      '\n'.allMatches(source.substring(0, offset)).length + 1;

  /// The text of the call whose `(` ends [match], up to its matching `)`.
  String callArguments(String source, Match match) {
    var depth = 1;
    var i = match.end;
    while (depth > 0 && i < source.length) {
      if (source[i] == '(') depth++;
      if (source[i] == ')') depth--;
      i++;
    }
    return source.substring(match.end, i);
  }

  test('the scan finds the auth and splash screens', () {
    // A moved or renamed folder must fail here, not pass by scanning nothing.
    expect(
      sources().keys,
      containsAll([
        'auth/presentation/login_screen.dart',
        'auth/presentation/reset_password_screen.dart',
        'auth/presentation/widgets/manager_contact_sheet.dart',
        'auth/presentation/widgets/sign_out_confirmation_dialog.dart',
        'splash/presentation/splash_screen.dart',
      ]),
    );
  });

  test('auth and splash read colours only via context.palette', () {
    final offenders = <String>[];
    for (final MapEntry(key: file, value: source) in sources().entries) {
      final lines = source.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (isComment(line) || !legacy.hasMatch(line)) continue;
        // The wordmark's *authored* colour, compared with the theme's to
        // decide whether a tint is needed at all — as the Home header does.
        if (file == 'splash/presentation/splash_screen.dart' &&
            line.trim() ==
                'colorFilter: context.palette.wordmark == AppColors.wordmark') {
          continue;
        }
        offenders.add('$file:${i + 1}: ${line.trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test(
    'no auth or splash use of a colour-baking text style keeps its colour',
    () {
      final typography = File(
        'lib/core/theme/app_typography.dart',
      ).readAsStringSync();
      final bakedTypography = {
        for (final m in RegExp(
          r'static const TextStyle (\w+) = TextStyle\(([\s\S]*?)\);',
        ).allMatches(typography))
          if (m.group(2)!.contains('color:')) m.group(1)!,
      };
      expect(bakedTypography, isNotEmpty);

      final offenders = <String>[];
      for (final MapEntry(key: file, value: source) in sources().entries) {
        final declarations = [
          for (final m in RegExp(
            r'^(?:const|final) TextStyle (\w+) = ([\s\S]*?);$',
            multiLine: true,
          ).allMatches(source))
            (name: m.group(1)!, start: m.start, end: m.end, init: m.group(2)!),
        ];

        // A file's own top-level style may not bake a colour.
        for (final d in declarations) {
          if (d.init.contains(RegExp(r'\bcolor:'))) {
            offenders.add(
              '$file:${lineOf(source, d.start)}: top-level style '
              '${d.name} bakes a colour',
            );
          }
        }

        // Patterns whose every use must supply a colour: the baked
        // `AppTypography` styles, and this file's own styles derived from
        // one (which keep its colour until a use supplies another).
        final baked = [
          for (final name in bakedTypography)
            RegExp(r'\bAppTypography\.' + name + r'\b'),
          for (final d in declarations)
            if (bakedTypography.any((t) => d.init.contains('AppTypography.$t')))
              RegExp(r'(?<![\w.])' + d.name + r'\b'),
        ];

        for (final pattern in baked) {
          for (final m in pattern.allMatches(source)) {
            final lineStart = source.lastIndexOf('\n', m.start) + 1;
            final line = source.substring(
              lineStart,
              source.indexOf('\n', m.start),
            );
            if (isComment(line)) continue;
            // A declaration's own initializer, or its name, is not a use.
            if (declarations.any(
              (d) => d.start <= m.start && m.start < d.end,
            )) {
              continue;
            }
            // The use must be followed by `.copyWith(` whose arguments set
            // `color:` — the palette's colour, by the first check above.
            final copyWith = RegExp(
              r'\s*\.copyWith\(',
            ).matchAsPrefix(source, m.end);
            final suppliesColour =
                copyWith != null &&
                callArguments(source, copyWith).contains(RegExp(r'\bcolor:'));
            if (!suppliesColour) {
              offenders.add(
                '$file:${lineOf(source, m.start)}: ${line.trim()} '
                '(${pattern.pattern} keeps its built-in colour)',
              );
            }
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    },
  );

  test(
    'no auth or splash divider or progress indicator falls back to Material',
    () {
      final offenders = <String>[];
      for (final MapEntry(key: file, value: source) in sources().entries) {
        for (final m in RegExp(
          r'(?:const\s+)?\b(Divider|VerticalDivider|CircularProgressIndicator'
          r'|LinearProgressIndicator)\(',
        ).allMatches(source)) {
          final args = callArguments(source, m);
          if (args.contains(RegExp(r'\bcolor:'))) continue;
          offenders.add(
            '$file:${lineOf(source, m.start)}: ${m.group(1)} sets no colour',
          );
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    },
  );
}
