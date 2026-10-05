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

  for (final current in StudentTab.values) {
    testWidgets('with ${current.name} current, every tab keeps its one glyph '
        'and only the colour marks the selection', (tester) async {
      await pumpNav(tester, current);

      // No tab swaps in other artwork when selected (Issue #188).
      expect(find.byType(SvgPicture), findsNothing);
      for (var i = 0; i < glyphs.length; i++) {
        final icon = tester.widget<Icon>(find.byIcon(glyphs[i]));
        expect(
          icon.color,
          i == current.index
              ? const Color(0xFF2970FF)
              : AppColors.textSecondary,
        );
      }
    });
  }

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
    expect(nav.items.map((item) => item.selectedAsset), [null, null, null]);
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
