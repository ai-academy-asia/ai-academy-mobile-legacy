import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Dark Mode Phase 6a (Issue #266): the Learning Flow's entry screens —
/// Course Module List, Lesson List and the widgets they share with the
/// Certificate screen — read their colours only through `context.palette`,
/// so an approved `AppPalette.dark` reaches them without editing these files
/// again. The flow is shared by Adult and Junior.
///
/// The same two checks as `adult_palette_scope_test.dart`, over this scope:
///
///  * **No direct colour reads** — `AppColors.`, a feature palette, a colour
///    literal, a `Colors.` constant or a Material theme colour — outside the
///    documented exception below.
///  * **No colour hidden in a shared text style.** Every use of a
///    colour-baking `AppTypography` style supplies the palette's colour with
///    `.copyWith(… color: …)`.
///
/// Exercise Detail, Materials/Notes/Assignment and Quiz are Phases 6b/6c and
/// are not checked here.
void main() {
  /// The Phase 6a files, under `lib/features/course_learning/`.
  const scope = [
    'presentation/course_module_list_screen.dart',
    'presentation/lesson_list_screen.dart',
    'presentation/widgets/course_module_card.dart',
    'presentation/widgets/lesson_list_item.dart',
    'presentation/widgets/certificate_preview.dart',
    'presentation/widgets/course_progress_cta_row.dart',
    'data/course_module_visuals.dart',
  ];

  final legacy = RegExp(
    r'\b(AppColors|HomePalette|PaymentFlowPalette|JuniorPalette'
    r'|TeacherScheduleColors|GradebookColors|TeacherPillColors)\.\w+'
    r'|\bColor\(0x[0-9A-Fa-f]+\)'
    r'|\bColor\.from(ARGB|RGBO)\('
    // `Colors.transparent` is no colour at all, so it reads the same in
    // every theme.
    r'|\bColors\.(?!transparent\b)\w+'
    r'|\.colorScheme\b'
    r'|\b(primaryColor|canvasColor|scaffoldBackgroundColor|cardColor'
    r'|dividerColor)\b',
  );

  bool isComment(String line) => line.trimLeft().startsWith('//');

  Map<String, String> sources() => {
    for (final path in scope)
      path: File('lib/features/course_learning/$path').readAsStringSync(),
  };

  int lineOf(String source, int offset) =>
      '\n'.allMatches(source.substring(0, offset)).length + 1;

  test('the Phase 6a scope reads colours only via context.palette', () {
    /// Allowed on purpose — each says why.
    bool allowed(String file, String line) => switch (file) {
      // The five module accents are authored artwork: each is sampled from
      // its `module_*.svg`'s own fill, and the contract has the client map a
      // module's `order` onto them. They are content colours, not theme
      // roles; their dark treatment is a PRODUCT DECISION
      // (`DARK_MODE_ARCHITECTURE_AUDIT.md`, `CourseModuleVisuals`).
      'data/course_module_visuals.dart' => RegExp(
        r'^\s*accentColor: Color\(0xFF[0-9A-F]{6}\),$',
      ).hasMatch(line),
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

  test('no Phase 6a use of a colour-baking text style keeps its colour', () {
    final typography = File(
      'lib/core/theme/app_typography.dart',
    ).readAsStringSync();
    final baked = [
      for (final m in RegExp(
        r'static const TextStyle (\w+) = TextStyle\(([\s\S]*?)\);',
      ).allMatches(typography))
        if (m.group(2)!.contains('color:'))
          RegExp(r'\bAppTypography\.' + m.group(1)! + r'\b'),
    ];
    expect(baked, isNotEmpty);

    final offenders = <String>[];
    for (final MapEntry(key: file, value: source) in sources().entries) {
      // A file's own top-level style may not bake a colour either.
      for (final m in RegExp(
        r'^(?:const|final) TextStyle (\w+) = ([\s\S]*?);$',
        multiLine: true,
      ).allMatches(source)) {
        if (m.group(2)!.contains('color:')) {
          offenders.add(
            '$file:${lineOf(source, m.start)}: top-level style '
            '${m.group(1)} bakes a colour',
          );
        }
      }

      for (final pattern in baked) {
        for (final m in pattern.allMatches(source)) {
          final lineStart = source.lastIndexOf('\n', m.start) + 1;
          final line = source.substring(
            lineStart,
            source.indexOf('\n', m.start),
          );
          if (isComment(line)) continue;
          // The use must be followed by `.copyWith(` whose arguments set
          // `color:` — the palette's colour, by the first check above.
          final rest = source.substring(m.end);
          final copyWith = RegExp(r'^\s*\.copyWith\(').firstMatch(rest);
          var suppliesColour = false;
          if (copyWith != null) {
            var depth = 1;
            var i = copyWith.end;
            while (depth > 0 && i < rest.length) {
              if (rest[i] == '(') depth++;
              if (rest[i] == ')') depth--;
              i++;
            }
            suppliesColour = rest
                .substring(copyWith.end, i)
                .contains(RegExp(r'\bcolor:'));
          }
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
}
