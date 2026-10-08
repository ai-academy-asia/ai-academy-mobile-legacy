import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Dark Mode Phase 5 (Issue #262): the Adult experience reads its colours
/// only through `context.palette`, so an approved `AppPalette.dark` reaches
/// it without editing these screens again.
///
/// Fails on any `AppColors.`, feature-palette (`HomePalette.`,
/// `PaymentFlowPalette.`, `JuniorPalette.`) or colour-literal read in the
/// Adult features, outside the few documented exceptions below.
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

  /// Allowed on purpose — each line says why.
  final allowed = <String, RegExp>{
    // The legacy palette itself: aliases of the `AppColors` roles, kept for
    // the Junior and Teacher code that still names it (Phases 7 and 8).
    'home/presentation/widgets/home_palette.dart': RegExp('.'),
    // `PaymentFlowPalette`'s own members: aliases of the roles, pinned by
    // `app_palette_test.dart`. Screens read the roles, not these.
    'home/presentation/payment_flow/payment_flow_widgets.dart': RegExp(
      r'^\s*static const Color \w+ = AppColors\.\w+;$',
    ),
    // The wordmark's *authored* colour, compared with the theme's to decide
    // whether a tint is needed at all (see `AppSvgIcon`).
    'home/presentation/widgets/home_header.dart': RegExp(
      r'context\.palette\.wordmark == AppColors\.wordmark',
    ),
    // The public Profile text styles keep their light colours for the
    // Teacher Profile, which reads them directly until Phase 8; the Adult
    // parts and screen apply the palette's colour over them.
    'profile/presentation/widgets/profile_parts.dart': RegExp(
      r'^\s*color: AppColors\.(textPrimary|textSecondary),$',
    ),
  };

  final legacy = RegExp(
    r'\b(AppColors|HomePalette|PaymentFlowPalette|JuniorPalette)\.\w+'
    r'|Color\(0x[0-9A-Fa-f]+\)'
    r'|\bColors\.(white|black)\w*',
  );

  test('the Adult features read colours only via context.palette', () {
    final offenders = <String>[];
    for (final feature in adultFeatures) {
      final dir = Directory('lib/features/$feature');
      if (!dir.existsSync()) continue;
      for (final file in dir.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final relative = file.path.substring('lib/features/'.length);
        final exception = allowed[relative];
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          if (!legacy.hasMatch(line)) continue;
          if (exception != null && exception.hasMatch(line)) continue;
          offenders.add('$relative:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
