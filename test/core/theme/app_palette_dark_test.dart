import 'dart:io';
import 'dart:math' as math;

import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/core/theme/app_theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dark Mode Phase 9 (Issue #276): the **candidate** dark palette — the
/// proposal's values, not approved — is complete, documented, measured and
/// unreachable.
void main() {
  const dark = AppPalette.dark;

  /// Every role's candidate value and where it comes from. Hex literals, so a
  /// silent change to `AppPalette.dark` fails here.
  final roles = <String, (Color, Color, String)>{
    'pageBackground': (
      dark.pageBackground,
      const Color(0xFF0F1217),
      'PROPOSED',
    ),
    'surfaceSubtle': (dark.surfaceSubtle, const Color(0xFF14181E), 'PROPOSED'),
    'surface': (dark.surface, const Color(0xFF1A1F27), 'PROPOSED'),
    'surfaceElevated': (
      dark.surfaceElevated,
      const Color(0xFF232934),
      'PROPOSED',
    ),
    'surfaceMuted': (dark.surfaceMuted, const Color(0xFF20252E), 'PROPOSED'),
    'surfaceTile': (dark.surfaceTile, const Color(0xFF14181E), 'DERIVED'),
    'textPrimary': (dark.textPrimary, const Color(0xFFECEFF3), 'PROPOSED'),
    'textSecondary': (dark.textSecondary, const Color(0xFFA3ACB9), 'PROPOSED'),
    'textTitle': (dark.textTitle, const Color(0xFFF5F7FA), 'PROPOSED'),
    'textStrong': (dark.textStrong, const Color(0xFFECEFF3), 'DERIVED'),
    'textSupporting': (dark.textSupporting, const Color(0xFFA3ACB9), 'DERIVED'),
    'textMuted': (dark.textMuted, const Color(0xFFA3ACB9), 'DERIVED'),
    'textInactive': (dark.textInactive, const Color(0xFF6E7682), 'PROPOSED'),
    'textLocked': (dark.textLocked, const Color(0xFF6E7682), 'DERIVED'),
    'iconInk': (dark.iconInk, const Color(0xFFECEFF3), 'DERIVED'),
    'wordmark': (dark.wordmark, const Color(0xFFF5F7FA), 'DERIVED'),
    'border': (dark.border, const Color(0xFF3A424E), 'PROPOSED'),
    'borderFocused': (dark.borderFocused, const Color(0xFFECEFF3), 'PROPOSED'),
    'divider': (dark.divider, const Color(0xFF2A303A), 'PROPOSED'),
    'outline': (dark.outline, const Color(0xFF3A424E), 'DERIVED'),
    'outlineSubtle': (dark.outlineSubtle, const Color(0xFF2A303A), 'DERIVED'),
    'primary': (dark.primary, const Color(0xFF296CFF), 'PROPOSED'),
    'onPrimary': (dark.onPrimary, const Color(0xFFFFFFFF), 'PROPOSED'),
    'primaryDepth': (dark.primaryDepth, const Color(0xFF1D4FC4), 'PROPOSED'),
    'accent': (dark.accent, const Color(0xFF2970FF), 'PROPOSED'),
    'accentText': (dark.accentText, const Color(0xFF6E9BFF), 'PROPOSED'),
    'accentSubtle': (dark.accentSubtle, const Color(0xFF1A2A47), 'PROPOSED'),
    'accentSubtleOutline': (
      dark.accentSubtleOutline,
      const Color(0xFF2A78B8),
      'UNRESOLVED',
    ),
    'linkInk': (dark.linkInk, const Color(0xFF6E9BFF), 'DERIVED'),
    'disabled': (dark.disabled, const Color(0xFF20252E), 'UNRESOLVED'),
    'disabledInk': (dark.disabledInk, const Color(0xFF6E7682), 'PROPOSED'),
    'neutralDepth': (dark.neutralDepth, const Color(0xFF0B0E12), 'PROPOSED'),
    'subtleDepth': (dark.subtleDepth, const Color(0xFF0B0E12), 'DERIVED'),
    'error': (dark.error, const Color(0xFFFF7A70), 'PROPOSED'),
    'errorInk': (dark.errorInk, const Color(0xFFFF7A70), 'PROPOSED'),
    'errorFill': (dark.errorFill, const Color(0xFF341A1C), 'PROPOSED'),
    'errorOutline': (dark.errorOutline, const Color(0xFFC2453F), 'PROPOSED'),
    'success': (dark.success, const Color(0xFF45D18C), 'DERIVED'),
    'successInk': (dark.successInk, const Color(0xFF45D18C), 'PROPOSED'),
    'successFill': (dark.successFill, const Color(0xFF0F2E20), 'PROPOSED'),
    'successOutline': (
      dark.successOutline,
      const Color(0xFF2E8F5E),
      'PROPOSED',
    ),
    'successLabel': (dark.successLabel, const Color(0xFF45D18C), 'DERIVED'),
    'successFillStrong': (
      dark.successFillStrong,
      const Color(0xFF0F2E20),
      'UNRESOLVED',
    ),
    'warning': (dark.warning, const Color(0xFFF5B547), 'DERIVED'),
    'warningFill': (dark.warningFill, const Color(0xFF33280F), 'PROPOSED'),
    'warningOutline': (
      dark.warningOutline,
      const Color(0xFFA87A1E),
      'PROPOSED',
    ),
    'warningInk': (dark.warningInk, const Color(0xFFF5B547), 'PROPOSED'),
    'infoInk': (dark.infoInk, const Color(0xFF5CB8FF), 'PROPOSED'),
    'infoFill': (dark.infoFill, const Color(0xFF132A42), 'PROPOSED'),
    'barrier': (dark.barrier, const Color(0xB3000000), 'PROPOSED'),
    'sheetHandle': (dark.sheetHandle, const Color(0xFF4A525E), 'PROPOSED'),
    'shadow': (dark.shadow, const Color(0x00000000), 'PROPOSED'),
    'shadowSubtle': (dark.shadowSubtle, const Color(0x00000000), 'DERIVED'),
    'accentOutline': (
      dark.accentOutline,
      const Color(0xFF2970FF),
      'UNRESOLVED',
    ),
    'timelineConnector': (
      dark.timelineConnector,
      const Color(0xFF3A424E),
      'UNRESOLVED',
    ),
    'textFaint': (dark.textFaint, const Color(0xFF6E7682), 'DERIVED'),
    'textDeep': (dark.textDeep, const Color(0xFFECEFF3), 'DERIVED'),
    'textStatLabel': (dark.textStatLabel, const Color(0xFFA3ACB9), 'DERIVED'),
    'attendanceGradientStart': (
      dark.attendanceGradientStart,
      const Color(0xFF175FEF),
      'PROPOSED',
    ),
    'attendanceGradientEnd': (
      dark.attendanceGradientEnd,
      const Color(0xFF518BFF),
      'PROPOSED',
    ),
    'surfaceTinted': (dark.surfaceTinted, const Color(0xFF1A1F27), 'DERIVED'),
    'scrim': (dark.scrim, const Color(0x94000000), 'PROPOSED'),
    'learningHeroTint': (
      dark.learningHeroTint,
      const Color(0xFF1A2A47),
      'UNRESOLVED',
    ),
    'surfaceLocked': (
      dark.surfaceLocked,
      const Color(0xFF20252E),
      'UNRESOLVED',
    ),
    'cardDepth': (dark.cardDepth, const Color(0xFF0B0E12), 'DERIVED'),
    'outlineFaint': (dark.outlineFaint, const Color(0xFF2A303A), 'UNRESOLVED'),
    'videoSurface': (dark.videoSurface, const Color(0xFF080F35), 'PROPOSED'),
    'mediaControl': (dark.mediaControl, const Color(0xFFFFFFFF), 'DERIVED'),
    'onMediaControl': (dark.onMediaControl, const Color(0xE6000000), 'DERIVED'),
    'mediaControlOutline': (
      dark.mediaControlOutline,
      const Color(0xFFD6DBE1),
      'DERIVED',
    ),
    'onMedia': (dark.onMedia, const Color(0xFFFFFFFF), 'DERIVED'),
    'progressTrack': (dark.progressTrack, const Color(0xFF2A303A), 'DERIVED'),
    'textAnswerLetter': (
      dark.textAnswerLetter,
      const Color(0xFFA3ACB9),
      'DERIVED',
    ),
    'juniorCard': (dark.juniorCard, const Color(0xFF1A2235), 'PROPOSED'),
    'juniorCardBorder': (
      dark.juniorCardBorder,
      const Color(0xFF2E3A5C),
      'PROPOSED',
    ),
    'juniorMapSky': (dark.juniorMapSky, const Color(0xFF2A4A73), 'PROPOSED'),
    'calendarNeutral': (
      dark.calendarNeutral,
      const Color(0xFF20252E),
      'PROPOSED',
    ),
    'calendarLesson': (
      dark.calendarLesson,
      const Color(0xFF1A2A47),
      'PROPOSED',
    ),
    'calendarMissed': (
      dark.calendarMissed,
      const Color(0xFF3A1F22),
      'PROPOSED',
    ),
    'juniorMutedFill': (
      dark.juniorMutedFill,
      const Color(0xFF20252E),
      'UNRESOLVED',
    ),
    'juniorHeaderRule': (
      dark.juniorHeaderRule,
      const Color(0xFF2A303A),
      'DERIVED',
    ),
    'onJuniorMapSky': (dark.onJuniorMapSky, const Color(0xFFFFFFFF), 'DERIVED'),
    'scheduleBand': (dark.scheduleBand, const Color(0xFF1F4FC9), 'PROPOSED'),
    'scheduleHeld': (dark.scheduleHeld, const Color(0xFF1A2A47), 'PROPOSED'),
    'scheduleHeldInk': (
      dark.scheduleHeldInk,
      const Color(0xFFA3ACB9),
      'PROPOSED',
    ),
    'teacherTitle': (dark.teacherTitle, const Color(0xFFECEFF3), 'DERIVED'),
    'teacherNameInk': (dark.teacherNameInk, const Color(0xFFECEFF3), 'DERIVED'),
    'teacherRoleInk': (dark.teacherRoleInk, const Color(0xFFA3ACB9), 'DERIVED'),
    'teacherDetailInk': (
      dark.teacherDetailInk,
      const Color(0xFFA3ACB9),
      'DERIVED',
    ),
    'teacherCaptionInk': (
      dark.teacherCaptionInk,
      const Color(0xFFA3ACB9),
      'DERIVED',
    ),
    'teacherSheetRule': (
      dark.teacherSheetRule,
      const Color(0xFF2A303A),
      'DERIVED',
    ),
    'dangerOutline': (dark.dangerOutline, const Color(0xFFC2453F), 'DERIVED'),
    'avatarPlaceholder': (
      dark.avatarPlaceholder,
      const Color(0xFF20252E),
      'UNRESOLVED',
    ),
    'avatarPlaceholderInk': (
      dark.avatarPlaceholderInk,
      const Color(0xFF6E7682),
      'UNRESOLVED',
    ),
  };

  test('every role has a candidate dark value and a recorded status', () {
    final source = File('lib/core/theme/app_palette.dart').readAsStringSync();
    final declared = RegExp(
      r'required this\.(\w+),',
    ).allMatches(source).map((m) => m.group(1)!).toList();
    expect(declared, hasLength(94));
    expect(roles.keys.toSet(), declared.toSet());
    for (final MapEntry(key: role, value: (actual, expected, status))
        in roles.entries) {
      expect(actual, expected, reason: role);
      expect(status, isIn(['PROPOSED', 'DERIVED', 'UNRESOLVED']));
      // The code says the same as the table.
      expect(
        source,
        contains(RegExp('// $status:[^\\n]*\\n\\s*$role:')),
        reason: '$role is not marked $status in AppPalette.dark',
      );
    }
  });

  test('the proposal documents every role\'s candidate value and status', () {
    final doc = File(
      'docs/design-system/DARK_MODE_DESIGN_PROPOSAL.md',
    ).readAsStringSync();
    for (final MapEntry(key: role, value: (_, expected, status))
        in roles.entries) {
      final hex = expected
          .toARGB32()
          .toRadixString(16)
          .toUpperCase()
          .padLeft(8, '0');
      expect(
        doc,
        contains('| `$role` | `#$hex` | $status |'),
        reason: '$role is missing from the §18 table or disagrees with it',
      );
    }
  });

  test('dark is a different palette, and light is untouched', () {
    expect(identical(AppPalette.light, dark), isFalse);
    expect(dark.pageBackground, isNot(AppPalette.light.pageBackground));
    expect(AppTheme.light.extension<AppPalette>(), same(AppPalette.light));
    expect(AppTheme.light.brightness, Brightness.light);
  });

  test('AppTheme.dark carries the candidate (proposal §5, §6, §9)', () {
    final theme = AppTheme.dark;
    expect(theme.extension<AppPalette>(), same(AppPalette.dark));
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, dark.pageBackground);
    expect(theme.colorScheme.primary, dark.accent);
    expect(theme.colorScheme.surface, dark.surfaceElevated);
    expect(theme.colorScheme.error, dark.error);
    expect(theme.textSelectionTheme.cursorColor, dark.borderFocused);
    expect(
      theme.textSelectionTheme.selectionColor,
      dark.accentText.withValues(alpha: 0.3),
    );
  });

  group('the candidate is unreachable from production code (Phase 10)', () {
    test('the default mode is light', () {
      expect(AppThemeController().mode, ThemeMode.light);
      expect(AppThemeController.instance.mode, ThemeMode.light);
    });

    /// Every non-comment line of `lib/`, as `path:line: text`.
    List<(String, int, String)> libLines() => [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          for (final (i, line) in file.readAsLinesSync().indexed)
            if (!line.trimLeft().startsWith('//')) (file.path, i + 1, line),
    ];

    /// The lines of `lib/` matching [pattern], less the [allowed] ones.
    List<String> offenders(
      RegExp pattern,
      bool Function(String path, String line) allowed,
    ) => [
      for (final (path, number, line) in libLines())
        if (pattern.hasMatch(line) && !allowed(path, line.trim()))
          '$path:$number: ${line.trim()}',
    ];

    const controller = 'lib/core/theme/app_theme_controller.dart';

    test(
      'nothing refers to setMode but its declaration — no call, no '
      'tear-off such as `onChanged: AppThemeController.instance.setMode`',
      () {
        final found = offenders(
          RegExp(r'\bsetMode\b'),
          (path, line) =>
              path == controller && line == 'void setMode(ThemeMode mode) {',
        );
        expect(found, isEmpty, reason: found.join('\n'));
      },
    );

    test('nothing names ThemeMode.dark or ThemeMode.system', () {
      final found = offenders(
        RegExp(r'\bThemeMode\.(dark|system)\b'),
        (_, _) => false,
      );
      expect(found, isEmpty, reason: found.join('\n'));
    });

    test('no AppThemeController is built with a mode — only the light '
        'default (its own declaration excepted)', () {
      final found = offenders(
        RegExp(r'\bAppThemeController\(\s*[^)\s]'),
        (path, line) =>
            path == controller &&
            line == 'AppThemeController([this._mode = ThemeMode.light]);',
      );
      expect(found, isEmpty, reason: found.join('\n'));
    });

    test('AppTheme.dark / AppPalette.dark appear only in lib/core/theme/ '
        'and in app.dart\'s darkTheme registration', () {
      final found = offenders(
        RegExp(r'\b(AppTheme|AppPalette)\.dark\b'),
        (path, line) =>
            path.startsWith('lib/core/theme/') ||
            (path == 'lib/app.dart' && line == 'darkTheme: AppTheme.dark,'),
      );
      expect(found, isEmpty, reason: found.join('\n'));
    });
  });

  group('measured contrast (WCAG 2.x) of the candidate', () {
    double luminance(Color c) {
      double channel(double v) => v <= 0.03928
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * channel(c.r) +
          0.7152 * channel(c.g) +
          0.0722 * channel(c.b);
    }

    double ratio(Color a, Color b) {
      final (x, y) = (luminance(a), luminance(b));
      return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
    }

    // Measured, not claimed: each figure is this palette's real ratio,
    // rounded to 2 places, and the same figure the docs record (§18).
    final measured = <String, (Color, Color, double)>{
      'textPrimary on surface': (dark.textPrimary, dark.surface, 14.35),
      'textPrimary on pageBackground': (
        dark.textPrimary,
        dark.pageBackground,
        16.27,
      ),
      'textPrimary on surfaceElevated': (
        dark.textPrimary,
        dark.surfaceElevated,
        12.66,
      ),
      'textTitle on surface': (dark.textTitle, dark.surface, 15.42),
      'textSecondary on surface': (dark.textSecondary, dark.surface, 7.22),
      'textSecondary on surfaceElevated': (
        dark.textSecondary,
        dark.surfaceElevated,
        6.37,
      ),
      'accentText on surface': (dark.accentText, dark.surface, 6.14),
      'accentText on accentSubtle': (dark.accentText, dark.accentSubtle, 5.32),
      'errorInk on errorFill': (dark.errorInk, dark.errorFill, 6.31),
      'error on surface': (dark.error, dark.surface, 6.52),
      'successInk on successFill': (dark.successInk, dark.successFill, 7.51),
      'warningInk on warningFill': (dark.warningInk, dark.warningFill, 7.98),
      'infoInk on infoFill': (dark.infoInk, dark.infoFill, 6.79),
      'scheduleHeldInk on scheduleHeld': (
        dark.scheduleHeldInk,
        dark.scheduleHeld,
        6.25,
      ),
      'onPrimary on scheduleBand': (dark.onPrimary, dark.scheduleBand, 6.95),
      'textPrimary on juniorCard': (dark.textPrimary, dark.juniorCard, 13.75),
      'onJuniorMapSky on juniorMapSky': (
        dark.onJuniorMapSky,
        dark.juniorMapSky,
        9.03,
      ),
      'onMedia on videoSurface': (dark.onMedia, dark.videoSurface, 18.58),
      // Below 4.5:1 — recorded, not hidden (§18): white on the unchanged
      // brand blues (the same as light), the deliberately quiet inactive
      // text, and the UNRESOLVED disabled fill.
      'onPrimary on primary': (dark.onPrimary, dark.primary, 4.48),
      'onPrimary on accent': (dark.onPrimary, dark.accent, 4.32),
      'textInactive on surface': (dark.textInactive, dark.surface, 3.61),
      'disabledInk on disabled': (dark.disabledInk, dark.disabled, 3.35),
      'accent (non-text) on surface': (dark.accent, dark.surface, 3.83),
    };

    for (final MapEntry(key: pair, value: (fg, bg, expected))
        in measured.entries) {
      test(pair, () {
        expect(ratio(fg, bg), closeTo(expected, 0.005));
      });
    }

    test('every body-text pair above meets AA (4.5:1)', () {
      const belowAa = {
        'onPrimary on primary',
        'onPrimary on accent',
        'textInactive on surface',
        'disabledInk on disabled',
        'accent (non-text) on surface',
      };
      for (final MapEntry(key: pair, value: (fg, bg, _)) in measured.entries) {
        if (belowAa.contains(pair)) continue;
        expect(ratio(fg, bg), greaterThanOrEqualTo(4.5), reason: pair);
      }
    });
  });
}
