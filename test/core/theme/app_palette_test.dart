import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/home/presentation/widgets/home_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `AppPalette` (Issue #252): the light palette is today's app, exactly.
void main() {
  const light = AppPalette.light;

  test('every light role is the legacy constant it replaces', () {
    final roles = <String, (Color, Color)>{
      'pageBackground': (light.pageBackground, AppColors.background),
      'surface': (light.surface, AppColors.surface),
      'surfaceSubtle': (light.surfaceSubtle, AppColors.surfaceSubtle),
      'surfaceMuted': (light.surfaceMuted, AppColors.surfaceMuted),
      'textPrimary': (light.textPrimary, AppColors.textPrimary),
      'textSecondary': (light.textSecondary, AppColors.textSecondary),
      // Literals until now: the Notification header's title ink and a read
      // notification row's ink.
      'textTitle': (light.textTitle, const Color(0xFF191919)),
      'textInactive': (light.textInactive, const Color(0xFFB2B2B2)),
      'border': (light.border, AppColors.border),
      'borderFocused': (light.borderFocused, AppColors.borderFocused),
      'divider': (light.divider, HomePalette.headerRule),
      'primary': (light.primary, AppColors.blue),
      'onPrimary': (light.onPrimary, AppColors.onPrimary),
      'accent': (light.accent, HomePalette.accent),
      'accentSubtle': (light.accentSubtle, HomePalette.liveFill),
      'disabled': (light.disabled, AppColors.disabled),
      'error': (light.error, AppColors.error),
      'success': (light.success, AppColors.success),
      'warning': (light.warning, AppColors.warning),
    };
    for (final MapEntry(key: role, value: (actual, legacy)) in roles.entries) {
      expect(actual, legacy, reason: role);
    }
  });

  test('AppTheme.light carries the light palette', () {
    expect(AppTheme.light.extension<AppPalette>(), same(AppPalette.light));
  });

  test('copyWith changes only what it is given; lerp at 0 is the start', () {
    final changed = light.copyWith(accent: const Color(0xFF000000));
    expect(changed.accent, const Color(0xFF000000));
    expect(changed.divider, light.divider);
    expect(changed.textPrimary, light.textPrimary);

    final start = light.lerp(changed, 0);
    expect(start.accent, light.accent);
    expect(light.lerp(null, 0.5), same(light));
  });

  group('context.palette', () {
    Future<AppPalette> paletteUnder(WidgetTester tester, ThemeData? theme) {
      late AppPalette palette;
      return tester
          .pumpWidget(
            MaterialApp(
              theme: theme,
              home: Builder(
                builder: (context) {
                  palette = context.palette;
                  return const SizedBox();
                },
              ),
            ),
          )
          .then((_) => palette);
    }

    testWidgets('is the theme\'s palette', (tester) async {
      final custom = AppPalette.light.copyWith(accent: const Color(0xFF123456));
      final palette = await paletteUnder(
        tester,
        AppTheme.light.copyWith(extensions: [custom]),
      );
      expect(palette.accent, const Color(0xFF123456));
    });

    testWidgets('falls back to light when the theme carries none', (
      tester,
    ) async {
      expect(await paletteUnder(tester, null), same(AppPalette.light));
    });
  });
}
