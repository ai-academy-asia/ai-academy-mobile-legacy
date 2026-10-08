import 'dart:io';

import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_bottom_nav.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_tabs.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// The teacher bar's icon states (Issue #241): every tab is its gray outline
/// glyph when inactive and the same glyph filled blue when active — never
/// the outline merely recoloured.
void main() {
  const blue = Color(0xFF2970FF);

  /// In bar order: each tab's outline glyph and its filled export.
  const glyphs = [
    AppIcons.house,
    AppIcons.calendar,
    AppIcons.exam,
    AppIcons.user,
  ];
  const filled = [
    'nav_home_selected.svg',
    'nav_schedule_active.svg',
    'nav_grades_active.svg',
    'nav_profile_selected.svg',
  ];

  Future<void> pumpNav(WidgetTester tester, TeacherTab current) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: TeacherBottomNav(current: current),
          ),
        ),
      );

  for (final current in TeacherTab.values) {
    testWidgets('with ${current.name} active, it is drawn filled blue and the '
        'others gray outlines', (tester) async {
      await pumpNav(tester, current);

      for (var i = 0; i < glyphs.length; i++) {
        if (i == current.index) {
          // The filled export, never the outline recoloured.
          expect(find.byIcon(glyphs[i]), findsNothing, reason: filled[i]);
        } else {
          expect(
            tester.widget<Icon>(find.byIcon(glyphs[i])).color,
            AppColors.textSecondary,
            reason: '${glyphs[i]}',
          );
        }
      }
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svg.bytesLoader.toString(), contains(filled[current.index]));
      expect(svg.colorFilter, const ColorFilter.mode(blue, BlendMode.srcIn));
    });
  }

  testWidgets('keeps Нүүр, Хуваарь, Дүнгийн хуудас, Профайл, with Профайл '
      'inert', (tester) async {
    await pumpNav(tester, TeacherTab.home);

    final items = tester.widget<AppBottomNav>(find.byType(AppBottomNav)).items;
    expect([for (final item in items) item.icon], glyphs);
    expect(items.last.onTap, isNull);
  });

  test(
    'the generated fills are real files drawn on the font glyph\'s em box',
    () {
      // Generated from Phosphor.ttf's own contours, at the glyph's 1024-unit em
      // box and 24pt — so they sit exactly where the outline glyph does.
      for (final asset in [
        'nav_schedule_active.svg',
        'nav_grades_active.svg',
      ]) {
        final svg = File('assets/icons/$asset').readAsStringSync();
        expect(svg, contains('viewBox="0 0 1024 1024"'), reason: asset);
        expect(svg, contains('width="24" height="24"'), reason: asset);
        expect(svg, contains('fill-rule="evenodd"'), reason: asset);
      }
    },
  );
}
