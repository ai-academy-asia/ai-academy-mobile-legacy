import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/home/presentation/payment_flow/payment_flow_widgets.dart';
import 'package:aia_mobile/features/home/presentation/widgets/home_palette.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_home_palette.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/gradebook_widgets.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_pill_button.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_week_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `AppPalette` (Issues #252, #256): the light palette is today's app,
/// exactly, and the legacy palettes are aliases of its roles.
void main() {
  const light = AppPalette.light;

  test('every light role is exactly the value that shipped', () {
    // Hex literals, not `AppColors`: `AppColors` is now the roles' source,
    // so comparing to it would prove nothing. These are the values the app
    // drew before Phase 1 and Phase 2 (Issues #252, #256).
    final roles = <String, (Color, Color)>{
      'pageBackground': (light.pageBackground, const Color(0xFFF4F5F7)),
      'surfaceSubtle': (light.surfaceSubtle, const Color(0xFFF9FAFB)),
      'surface': (light.surface, const Color(0xFFFFFFFF)),
      'surfaceElevated': (light.surfaceElevated, const Color(0xFFFFFFFF)),
      'surfaceMuted': (light.surfaceMuted, const Color(0xFFEFF0F3)),
      'surfaceTile': (light.surfaceTile, const Color(0xFFF5F5F5)),
      'textPrimary': (light.textPrimary, const Color(0xE6000000)),
      'textSecondary': (light.textSecondary, const Color(0x80000000)),
      'textTitle': (light.textTitle, const Color(0xFF191919)),
      'textStrong': (light.textStrong, const Color(0xFF1A1A1A)),
      'textSupporting': (light.textSupporting, const Color(0xFF7D7D7E)),
      'textMuted': (light.textMuted, const Color(0xFF808080)),
      'textInactive': (light.textInactive, const Color(0xFFB2B2B2)),
      'textLocked': (light.textLocked, const Color(0xFFB5B5B5)),
      'iconInk': (light.iconInk, const Color(0xFF000000)),
      'wordmark': (light.wordmark, const Color(0xFF14053D)),
      'border': (light.border, const Color(0xFFE4E6EF)),
      'borderFocused': (light.borderFocused, const Color(0xE6000000)),
      'divider': (light.divider, const Color(0xFFEAEDF0)),
      'outline': (light.outline, const Color(0xFFD6DBE1)),
      'outlineSubtle': (light.outlineSubtle, const Color(0xFFE5E7EB)),
      'primary': (light.primary, const Color(0xFF296CFF)),
      'onPrimary': (light.onPrimary, const Color(0xFFFFFFFF)),
      'primaryDepth': (light.primaryDepth, const Color(0xFF004FED)),
      'accent': (light.accent, const Color(0xFF2970FF)),
      'accentText': (light.accentText, const Color(0xFF2970FF)),
      'accentSubtle': (light.accentSubtle, const Color(0xFFE5F4FF)),
      'linkInk': (light.linkInk, const Color(0xFF1501A6)),
      'disabled': (light.disabled, const Color(0xFFC9CBDA)),
      'disabledInk': (light.disabledInk, const Color(0xFFAEAFB0)),
      'neutralDepth': (light.neutralDepth, const Color(0xFFE0E0E0)),
      'subtleDepth': (light.subtleDepth, const Color(0x0A000000)),
      'error': (light.error, const Color(0xFFE5484D)),
      'errorInk': (light.errorInk, const Color(0xFFDC3412)),
      'errorFill': (light.errorFill, const Color(0xFFFFF5F5)),
      'errorOutline': (light.errorOutline, const Color(0xFFEF4444)),
      'success': (light.success, const Color(0xFF22A06B)),
      'successInk': (light.successInk, const Color(0xFF009951)),
      'successFill': (light.successFill, const Color(0xFFEBFFEE)),
      'successOutline': (light.successOutline, const Color(0xFF14AE5C)),
      'successLabel': (light.successLabel, const Color(0xFF14AE5C)),
      'successFillStrong': (light.successFillStrong, const Color(0xFFCCEBDC)),
      'warning': (light.warning, const Color(0xFFF0A22E)),
      'warningFill': (light.warningFill, const Color(0xFFFFFAE5)),
      'warningOutline': (light.warningOutline, const Color(0xFFEBA611)),
      'infoInk': (light.infoInk, const Color(0xFF0D99FF)),
      'infoFill': (light.infoFill, const Color(0xFFE5F4FF)),
      'barrier': (light.barrier, const Color(0x99000000)),
      'sheetHandle': (light.sheetHandle, const Color(0xFFDBDBDC)),
      'shadow': (light.shadow, const Color(0x1A000000)),
      'shadowSubtle': (light.shadowSubtle, const Color(0x14000000)),
      'accentOutline': (light.accentOutline, const Color(0xFF155EEF)),
      'timelineConnector': (light.timelineConnector, const Color(0xFFBAC5FF)),
      'textFaint': (light.textFaint, const Color(0x4D000000)),
      'textDeep': (light.textDeep, const Color(0xFF101828)),
      'textStatLabel': (light.textStatLabel, const Color(0xFF726D6D)),
      'attendanceGradientStart': (light.attendanceGradientStart, const Color(0xFF175FEF)),
      'attendanceGradientEnd': (light.attendanceGradientEnd, const Color(0xFF518BFF)),
      'surfaceTinted': (light.surfaceTinted, const Color(0xFFF8FAFF)),
      'scrim': (light.scrim, const Color(0x94000000)),
      'juniorCard': (light.juniorCard, const Color(0xFFEFF4FF)),
      'juniorCardBorder': (light.juniorCardBorder, const Color(0xFFD1D3F5)),
      'juniorMapSky': (light.juniorMapSky, const Color(0xFFBFD9F8)),
      'calendarNeutral': (light.calendarNeutral, const Color(0xFFF2F2F3)),
      'calendarLesson': (light.calendarLesson, const Color(0xFFE5F4FF)),
      'calendarMissed': (light.calendarMissed, const Color(0xFFFFE7E7)),
      'scheduleBand': (light.scheduleBand, const Color(0xFF2970FF)),
      'scheduleHeld': (light.scheduleHeld, const Color(0xFFEFF4FF)),
      'scheduleHeldInk': (light.scheduleHeldInk, const Color(0xFF787A80)),
    };
    for (final MapEntry(key: role, value: (actual, shipped)) in roles.entries) {
      expect(actual, shipped, reason: role);
    }
  });

  test('every legacy palette member is its role (Phase 2 aliases)', () {
    final aliases = <String, (Color, Color)>{
      'HomePalette.border': (HomePalette.border, light.outline),
      'HomePalette.headerRule': (HomePalette.headerRule, light.divider),
      'HomePalette.accent': (HomePalette.accent, light.accent),
      'HomePalette.activeOutline': (
        HomePalette.activeOutline,
        light.successOutline,
      ),
      'HomePalette.activeFill': (HomePalette.activeFill, light.successFill),
      'HomePalette.activeInk': (HomePalette.activeInk, light.successInk),
      'HomePalette.liveOutline': (HomePalette.liveOutline, light.infoInk),
      'HomePalette.liveFill': (HomePalette.liveFill, light.infoFill),
      'HomePalette.iconTileFill': (
        HomePalette.iconTileFill,
        light.surfaceSubtle,
      ),
      'HomePalette.overdueFill': (HomePalette.overdueFill, light.errorFill),
      'HomePalette.overdueOutline': (
        HomePalette.overdueOutline,
        light.errorOutline,
      ),
      'HomePalette.overdueInk': (HomePalette.overdueInk, light.errorInk),
      'HomePalette.contractFill': (HomePalette.contractFill, light.warningFill),
      'HomePalette.contractOutline': (
        HomePalette.contractOutline,
        light.warningOutline,
      ),
      'HomePalette.mutedFill': (HomePalette.mutedFill, light.surfaceSubtle),
      'HomePalette.mutedOutline': (HomePalette.mutedOutline, light.divider),
      'HomePalette.mutedInk': (HomePalette.mutedInk, light.disabledInk),
      'HomePalette.secondaryDepth': (
        HomePalette.secondaryDepth,
        light.subtleDepth,
      ),
      'JuniorPalette.mapField': (JuniorPalette.mapField, light.juniorMapSky),
      'JuniorPalette.accent': (JuniorPalette.accent, light.accent),
      'JuniorPalette.cardFill': (JuniorPalette.cardFill, light.juniorCard),
      'JuniorPalette.cardBorder': (
        JuniorPalette.cardBorder,
        light.juniorCardBorder,
      ),
      'JuniorPalette.muted': (JuniorPalette.muted, light.outline),
      'JuniorPalette.mutedFill': (JuniorPalette.mutedFill, light.divider),
      'JuniorPalette.pillFill': (JuniorPalette.pillFill, light.surfaceSubtle),
      'JuniorPalette.dayNeutral': (
        JuniorPalette.dayNeutral,
        light.calendarNeutral,
      ),
      'JuniorPalette.dayLesson': (
        JuniorPalette.dayLesson,
        light.calendarLesson,
      ),
      'JuniorPalette.dayMissed': (
        JuniorPalette.dayMissed,
        light.calendarMissed,
      ),
      'PaymentFlowPalette.barrier': (PaymentFlowPalette.barrier, light.barrier),
      'PaymentFlowPalette.handle': (
        PaymentFlowPalette.handle,
        light.sheetHandle,
      ),
      'PaymentFlowPalette.successFill': (
        PaymentFlowPalette.successFill,
        light.successFillStrong,
      ),
      'TeacherScheduleColors.gridLine': (
        TeacherScheduleColors.gridLine,
        light.divider,
      ),
      'TeacherScheduleColors.heldFill': (
        TeacherScheduleColors.heldFill,
        light.scheduleHeld,
      ),
      'TeacherScheduleColors.heldInk': (
        TeacherScheduleColors.heldInk,
        light.scheduleHeldInk,
      ),
      'TeacherScheduleColors.weekday': (
        TeacherScheduleColors.weekday,
        light.textInactive,
      ),
      'TeacherScheduleColors.barTrack': (
        TeacherScheduleColors.barTrack,
        light.outlineSubtle,
      ),
      'TeacherScheduleColors.handle': (
        TeacherScheduleColors.handle,
        light.sheetHandle,
      ),
      'GradebookColors.name': (GradebookColors.name, light.textMuted),
      'GradebookColors.link': (GradebookColors.link, light.linkInk),
      'TeacherPillColors.ink': (TeacherPillColors.ink, light.textStrong),
    };
    for (final MapEntry(key: name, value: (legacy, role)) in aliases.entries) {
      expect(legacy, role, reason: name);
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
