import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Dark Mode Phase 6c (Issue #270): the Quiz — its screen, result screen,
/// answer and feedback cards, progress header, result rows and the preview
/// card Exercise Detail draws — reads its colours only through
/// `context.palette`, so an approved `AppPalette.dark` reaches it without
/// editing these files again. The flow is shared by Adult and Junior.
///
/// The same three checks as `exercise_detail_palette_scope_test.dart`, over
/// this scope, with no exceptions:
///
///  * **No direct colour reads** — `AppColors.`, a feature palette, the
///    retired `exerciseBorderColor` alias, a colour literal, a `Colors.`
///    constant or a Material theme colour.
///  * **No colour hidden in a shared text style.** Every use of a
///    colour-baking `AppTypography` style supplies the palette's colour with
///    `.copyWith(… color: …)`, and no file-level style bakes one.
///  * **No widget left on Material's default colour.** A `Divider` or
///    progress indicator given no colour draws one derived from the
///    `ColorScheme`, not a palette role.
void main() {
  /// The Phase 6c files, under `lib/features/course_learning/presentation/`.
  const scope = [
    'course_quiz_screen.dart',
    'course_quiz_result_screen.dart',
    'widgets/quiz_answer_card.dart',
    'widgets/quiz_feedback_card.dart',
    'widgets/quiz_preview_card.dart',
    'widgets/quiz_progress_header.dart',
    'widgets/quiz_result_question_row.dart',
  ];

  final legacy = RegExp(
    r'\b(AppColors|HomePalette|PaymentFlowPalette|JuniorPalette'
    r'|TeacherScheduleColors|GradebookColors|TeacherPillColors)\.\w+'
    r'|\bexerciseBorderColor\b'
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

  Map<String, String> sources() => {
    for (final path in scope)
      path: File(
        'lib/features/course_learning/presentation/$path',
      ).readAsStringSync(),
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

  test('the Phase 6c scope reads colours only via context.palette', () {
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

  test('no Phase 6c use of a colour-baking text style keeps its colour', () {
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

  test('no Phase 6c divider or progress indicator falls back to Material', () {
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
