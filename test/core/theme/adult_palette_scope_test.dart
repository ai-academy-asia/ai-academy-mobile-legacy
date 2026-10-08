import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Dark Mode Phase 5 (Issue #262): the Adult experience reads its colours
/// only through `context.palette`, so an approved `AppPalette.dark` reaches
/// it without editing these screens again.
///
/// Two checks over the Adult features:
///
///  * **No direct colour reads** — `AppColors.`, a feature palette
///    (`HomePalette.`, `PaymentFlowPalette.`, `JuniorPalette.`) or a colour
///    literal — outside the few documented exceptions below.
///  * **No colour hidden in a shared text style.** A style that bakes a
///    colour (most `AppTypography` styles, the public Profile styles, a
///    file's own top-level style) paints that colour wherever it is used
///    as is. Every use must supply the palette's colour with
///    `.copyWith(… color: …)`.
void main() {
  /// The Adult features (and the Adult screens Junior also opens:
  /// Certificate, the attendance scanner). `course_learning` is shared by
  /// Adult and Junior and migrates in Phase 6.
  const adultFeatures = [
    'home',
    'cohorts',
    'courses',
    'profile',
    'payments',
    'enrollments',
    'certificates',
    'attendance',
  ];

  /// The public Profile text styles kept with their light colours for the
  /// Teacher Profile, which reads them directly until Phase 8. Only the
  /// colour lines inside these declarations are excepted — any other direct
  /// colour in `profile_parts.dart` is caught.
  const teacherSharedProfileStyles = {
    'profileHeadingStyle',
    'profileNameStyle',
    'captionStyle',
    'rowLabelStyle',
  };

  final legacy = RegExp(
    r'\b(AppColors|HomePalette|PaymentFlowPalette|JuniorPalette)\.\w+'
    r'|Color\(0x[0-9A-Fa-f]+\)'
    r'|\bColors\.(white|black)\w*',
  );

  bool isComment(String line) => line.trimLeft().startsWith('//');

  /// Every `.dart` file of the Adult features, as `feature/…` → source.
  Map<String, String> adultSources() => {
    for (final feature in adultFeatures)
      if (Directory('lib/features/$feature').existsSync())
        for (final file in Directory(
          'lib/features/$feature',
        ).listSync(recursive: true).whereType<File>())
          if (file.path.endsWith('.dart'))
            file.path.substring('lib/features/'.length): file
                .readAsStringSync(),
  };

  /// Top-level `const`/`final TextStyle name = …;` declarations of [source],
  /// as name → (start offset, end offset, initializer).
  Map<String, (int, int, String)> styleDeclarations(String source) => {
    for (final m in RegExp(
      r'^(?:const|final) TextStyle (\w+) = ([\s\S]*?);$',
      multiLine: true,
    ).allMatches(source))
      m.group(1)!: (m.start, m.end, m.group(2)!),
  };

  /// The 1-based line of [offset] in [source].
  int lineOf(String source, int offset) =>
      '\n'.allMatches(source.substring(0, offset)).length + 1;

  test('the Adult features read colours only via context.palette', () {
    final sources = adultSources();

    // `profile_parts.dart`: the lines inside the Teacher-shared styles.
    final profileParts =
        sources['profile/presentation/widgets/profile_parts.dart']!;
    final sharedStyleLines = <int>{
      for (final MapEntry(key: name, value: (start, end, _))
          in styleDeclarations(profileParts).entries)
        if (teacherSharedProfileStyles.contains(name))
          for (
            var line = lineOf(profileParts, start);
            line <= lineOf(profileParts, end);
            line++
          )
            line,
    };
    expect(sharedStyleLines, isNotEmpty);

    /// Allowed on purpose — each says why.
    bool allowed(String file, int lineNumber, String line) => switch (file) {
      // The legacy palette itself: aliases of the `AppColors` roles, kept
      // for the Junior and Teacher code that still names it (Phases 7, 8).
      'home/presentation/widgets/home_palette.dart' => true,
      // `PaymentFlowPalette`'s own members: aliases of the roles, pinned by
      // `app_palette_test.dart`. Screens read the roles, not these.
      'home/presentation/payment_flow/payment_flow_widgets.dart' => RegExp(
        r'^\s*static const Color \w+ = AppColors\.\w+;$',
      ).hasMatch(line),
      // The wordmark's *authored* colour, compared with the theme's to
      // decide whether a tint is needed at all (see `AppSvgIcon`).
      'home/presentation/widgets/home_header.dart' => line.contains(
        'context.palette.wordmark == AppColors.wordmark',
      ),
      'profile/presentation/widgets/profile_parts.dart' =>
        sharedStyleLines.contains(lineNumber) &&
            RegExp(
              r'^\s*color: AppColors\.(textPrimary|textSecondary),$',
            ).hasMatch(line),
      _ => false,
    };

    final offenders = <String>[];
    for (final MapEntry(key: file, value: source) in sources.entries) {
      final lines = source.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (isComment(line) || !legacy.hasMatch(line)) continue;
        if (allowed(file, i + 1, line)) continue;
        offenders.add('$file:${i + 1}: ${line.trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no Adult use of a colour-baking text style keeps its colour', () {
    // `AppTypography` styles that bake a colour.
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

    final sources = adultSources();
    final offenders = <String>[];
    for (final MapEntry(key: file, value: source) in sources.entries) {
      final declarations = styleDeclarations(source);

      // Patterns whose every use must supply a colour, mapped to the reason.
      final baked = <RegExp>[
        for (final name in bakedTypography)
          RegExp(r'\bAppTypography\.' + name + r'\b'),
        // The Teacher-shared Profile styles, used outside their own file.
        if (!file.endsWith('profile_parts.dart'))
          for (final name in teacherSharedProfileStyles)
            RegExp(r'(?<![\w.])' + name + r'\b'),
        // This file's own top-level styles that bake a colour, or derive
        // from a style that does without overriding it.
        for (final MapEntry(key: name, value: (_, _, init))
            in declarations.entries)
          if (init.contains('color: AppColors.') ||
              (bakedTypography.any((t) => init.contains('AppTypography.$t')) &&
                  !init.contains('color:')))
            RegExp(r'(?<![\w.])' + name + r'\b'),
      ];

      // Spans of the declarations themselves: a derived style's own
      // initializer is not a use.
      final declarationSpans = [
        for (final (start, end, _) in declarations.values) (start, end),
      ];

      for (final pattern in baked) {
        for (final m in pattern.allMatches(source)) {
          final lineStart = source.lastIndexOf('\n', m.start) + 1;
          final line = source.substring(
            lineStart,
            source.indexOf('\n', m.start),
          );
          if (isComment(line)) continue;
          if (line.trimLeft().startsWith(RegExp(r'(import|export) '))) {
            continue;
          }
          if (declarationSpans.any((s) => s.$1 <= m.start && m.start < s.$2)) {
            continue;
          }
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
