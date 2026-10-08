import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/features/auth/presentation/student_tabs.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/home/presentation/widgets/adult_bottom_nav.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpNav(
    WidgetTester tester,
    StudentTab current, {
    VoidCallback? onCurrentTap,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        bottomNavigationBar: AdultBottomNav(
          current: current,
          onCurrentTap: onCurrentTap,
        ),
      ),
    ),
  );

  const glyphs = [AppIcons.house, AppIcons.bookOpenText, AppIcons.user];
  const filled = [
    'nav_home_selected.svg',
    'nav_courses_active.svg',
    'nav_profile_selected.svg',
  ];

  Iterable<String> drawnAssets(WidgetTester tester) => tester
      .widgetList<SvgPicture>(find.byType(SvgPicture))
      .map((svg) => svg.bytesLoader.toString());

  for (final current in StudentTab.values) {
    testWidgets('with ${current.name} current, the active tab is its own '
        'glyph filled blue and the others gray outlines', (tester) async {
      await pumpNav(tester, current);

      for (var i = 0; i < glyphs.length; i++) {
        if (i == current.index) {
          // The filled weight of the same glyph, never a font outline.
          expect(find.byIcon(glyphs[i]), findsNothing);
        } else {
          final icon = tester.widget<Icon>(find.byIcon(glyphs[i]));
          expect(icon.color, AppColors.textSecondary);
        }
      }
      final assets = drawnAssets(tester).toList();
      expect(assets, hasLength(1));
      expect(assets.single, contains(filled[current.index]));
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        svg.colorFilter,
        const ColorFilter.mode(Color(0xFF2970FF), BlendMode.srcIn),
      );
    });
  }

  testWidgets('a destination draws the same filled glyph on every screen', (
    tester,
  ) async {
    // The selected assets are fixed per destination, not per screen.
    final perScreen = <List<String?>>[];
    for (final current in StudentTab.values) {
      await pumpNav(tester, current);
      final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      perScreen.add([for (final item in nav.items) item.selectedAsset]);
    }
    expect(perScreen[1], perScreen[0]);
    expect(perScreen[2], perScreen[0]);
    for (var i = 0; i < filled.length; i++) {
      expect(perScreen[0][i], endsWith(filled[i]));
    }
  });

  testWidgets('draws the shared bar unmodified, with the adult labels', (
    tester,
  ) async {
    await pumpNav(tester, StudentTab.home);

    final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
    const shared = AppBottomNav(items: [], currentIndex: 0);
    expect(nav.iconSize, shared.iconSize);
    expect(nav.labelSize, shared.labelSize);
    expect(nav.horizontalPadding, shared.horizontalPadding);
    expect(nav.selectedColor, shared.selectedColor);
    expect(nav.items.map((item) => item.label), [
      HomeStrings.navHome,
      HomeStrings.navCourses,
      HomeStrings.navProfile,
    ]);
  });

  testWidgets('the current tab is inert unless the screen asks otherwise', (
    tester,
  ) async {
    await pumpNav(tester, StudentTab.progress);
    var nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
    expect(nav.items[1].onTap, isNull);

    var taps = 0;
    await pumpNav(tester, StudentTab.progress, onCurrentTap: () => taps++);
    nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
    nav.items[1].onTap!();
    expect(taps, 1);
  });
}
