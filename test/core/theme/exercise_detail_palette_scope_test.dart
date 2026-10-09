import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Dark Mode Phase 6b (Issue #268): Exercise Detail — the screen, its video
/// header, tabs, Note / Course materials / Assignment content and their
/// widgets — reads its colours only through `context.palette`, so an
/// approved `AppPalette.dark` reaches it without editing these files again.
/// The flow is shared by Adult and Junior.
///
/// Three checks over this scope:
///
///  * **No direct colour reads** — `AppColors.`, a feature palette, the
///    `exerciseBorderColor` alias, a colour literal, a `Colors.` constant or
///    a Material theme colour — outside the documented exceptions below.
///  * **No colour hidden in a shared text style.** Every use of a
///    colour-baking `AppTypography` style supplies the palette's colour with
///    `.copyWith(… color: …)`, and no file-level style bakes one.
///  * **No widget left on Material's default colour.** A `Divider` or
///    progress indicator given no colour draws one derived from the
///    `ColorScheme`, not a palette role.
///
/// Quiz (`QuizPreviewCard` included) is Phase 6c; Module List and Lesson
/// List are 6a (`learning_entry_palette_scope_test.dart`).
void main() {
  /// The Phase 6b files, under `lib/features/course_learning/presentation/`.
  const scope = [
    'course_exercise_detail_screen.dart',
    'widgets/exercise_video_header.dart',
    'widgets/exercise_tabs.dart',
    'widgets/exercise_info_section.dart',
    'widgets/exercise_text_field.dart',
    'widgets/exercise_submit_button.dart',
    'widgets/course_materials_tab.dart',
    'widgets/course_material_card.dart',
    'widgets/note_tab.dart',
    'widgets/mentor_feedback_card.dart',
    'widgets/assignment_tab.dart',
    'widgets/assignment_upload_dropzone.dart',
    'widgets/assignment_attachment_card.dart',
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

  test('the Phase 6b scope reads colours only via context.palette', () {
    /// Allowed on purpose — each says why.
    bool allowed(String file, String line) => switch (file) {
      // The alias itself, kept only for the Quiz widgets that still import
      // it (`QuizPreviewCard`, `QuizProgressHeader`) until Phase 6c. No 6b
      // file reads it: any other mention in scope is caught.
      'widgets/exercise_text_field.dart' =>
        line == 'const Color exerciseBorderColor = AppColors.outline;',
      _ => false,
    };

    final offenders = <String>[];
    for (final MapEntry(key: file, value: source) in sources().entries) {
      final lines = source.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (isComment(line) || !legacy.hasMatch(line)) continue;
        if (allowed(file, line)) continue;
        offenders.add('$file:${i + 1}: ${line.trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no Phase 6b use of a colour-baking text style keeps its colour', () {
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

  test('no Phase 6b divider or progress indicator falls back to Material', () {
    /// Allowed on purpose — each says why.
    bool allowed(String file, String call) =>
        // The section rule above Mentor Feedback has always drawn Material's
        // `outlineVariant` (`#C5C6D0`), not `AppPalette.divider`
        // (`#EAEDF0`). Giving it the role would change pixels, so whether it
        // should is a PRODUCT DECISION (Issue #268). Exactly this call.
        file == 'widgets/assignment_tab.dart' &&
        call == 'const Divider(height: 1)';

    final offenders = <String>[];
    for (final MapEntry(key: file, value: source) in sources().entries) {
      for (final m in RegExp(
        r'(?:const\s+)?\b(Divider|VerticalDivider|CircularProgressIndicator'
        r'|LinearProgressIndicator)\(',
      ).allMatches(source)) {
        final args = callArguments(source, m);
        final call = source.substring(m.start, m.end + args.length);
        if (args.contains(RegExp(r'\bcolor:'))) continue;
        if (allowed(file, call)) continue;
        offenders.add(
          '$file:${lineOf(source, m.start)}: ${m.group(1)} sets no colour',
        );
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
