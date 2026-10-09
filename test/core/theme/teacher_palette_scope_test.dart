import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Dark Mode Phase 8 (Issue #274): Teacher — Home, Schedule (its blue band,
/// week strip, grid and session sheet), Profile, Request and the Gradebook —
/// reads its colours only through `context.palette`, so an approved
/// `AppPalette.dark` reaches it without editing these files again.
///
/// Every `.dart` file under `lib/features/teacher/presentation/` is scanned —
/// the folder, not a list — with the same three checks as the Junior guard
/// and no exceptions:
///
///  * **No direct colour reads** — `AppColors.`, a feature palette (the
///    retired `TeacherScheduleColors`, `GradebookColors`,
///    `TeacherPillColors` and `TeacherHomeColors` included), a colour
///    literal, a `Colors.` constant or a Material theme colour.
///  * **No colour hidden in a text style.** Every use of a colour-baking
///    `AppTypography` style supplies the palette's colour, and no file-level
///    style bakes one.
///  * **No widget left on Material's default colour.**
///
/// The authored SVG icons (the bell, the bottom bar's tab glyphs, the track
/// badges) are assets, not colour reads, so none is an exception here.
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

  const root = 'lib/features/teacher/presentation/';

  Map<String, String> sources() => {
    for (final file in Directory(
      root,
    ).listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart'))
        file.path.substring(root.length): file.readAsStringSync(),
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

  test('the scan finds the Teacher screens and widgets', () {
    // A moved or renamed folder must fail here, not pass by scanning nothing.
    expect(
      sources().keys,
      containsAll([
        'teacher_home_screen.dart',
        'teacher_schedule_screen.dart',
        'teacher_profile_screen.dart',
        'gradebook_submission_screen.dart',
        'widgets/teacher_week_grid.dart',
        'widgets/teacher_session_sheet.dart',
      ]),
    );
  });

  test('Teacher reads colours only via context.palette', () {
    final offenders = <String>[];
    for (final MapEntry(key: file, value: source) in sources().entries) {
      final lines = source.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (isComment(line) || !legacy.hasMatch(line)) continue;
        offenders.add('$file:${i + 1}: ${line.trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no Teacher use of a colour-baking text style keeps its colour', () {
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
          if (declarations.any((d) => d.start <= m.start && m.start < d.end)) {
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
  });

  test('no Teacher divider or progress indicator falls back to Material', () {
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
  });
}
