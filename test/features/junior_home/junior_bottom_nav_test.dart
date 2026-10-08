import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/features/auth/presentation/student_tabs.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// The junior bar's icon states (Issues #190, #241): every tab is its gray
/// outline glyph when inactive and the same glyph filled blue when active.
void main() {
  const blue = Color(0xFF2970FF);

  Future<void> pumpNav(WidgetTester tester, StudentTab current) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: JuniorBottomNav(current: current),
          ),
        ),
      );

  void expectOutlineGray(WidgetTester tester, IconData glyph) => expect(
    tester.widget<Icon>(find.byIcon(glyph)).color,
    AppColors.textSecondary,
    reason: '$glyph',
  );

  void expectFilledExport(WidgetTester tester, String asset) {
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.bytesLoader.toString(), contains(asset));
    expect(svg.colorFilter, const ColorFilter.mode(blue, BlendMode.srcIn));
  }

  testWidgets('Нүүр active: the house Fill in blue; the others gray outlines', (
    tester,
  ) async {
    await pumpNav(tester, StudentTab.home);

    expect(find.byIcon(AppIcons.house), findsNothing);
    expectFilledExport(tester, 'nav_home_selected.svg');
    expectOutlineGray(tester, Icons.event_available_outlined);
    expectOutlineGray(tester, AppIcons.user);
  });

  testWidgets('Сурлагын явц active: the filled calendar-check in blue; the '
      'others gray outlines', (tester) async {
    await pumpNav(tester, StudentTab.progress);

    // Material's pair: the same calendar-check, outline and filled.
    expect(find.byIcon(Icons.event_available_outlined), findsNothing);
    expect(tester.widget<Icon>(find.byIcon(Icons.event_available)).color, blue);
    expect(find.byType(SvgPicture), findsNothing);
    expectOutlineGray(tester, AppIcons.house);
    expectOutlineGray(tester, AppIcons.user);
  });

  testWidgets('Профайл active: the user Fill in blue; the others gray '
      'outlines', (tester) async {
    await pumpNav(tester, StudentTab.profile);

    expect(find.byIcon(AppIcons.user), findsNothing);
    expectFilledExport(tester, 'nav_profile_selected.svg');
    expectOutlineGray(tester, AppIcons.house);
    expectOutlineGray(tester, Icons.event_available_outlined);
  });
}
