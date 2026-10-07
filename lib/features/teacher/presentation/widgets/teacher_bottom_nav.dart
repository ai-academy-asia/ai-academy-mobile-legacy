import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../teacher_home_strings.dart';

/// Phosphor "House" Fill — the export `AdultBottomNav` draws.
const String _homeFilled = 'assets/icons/nav_home_selected.svg';

/// The teacher tab bar, as the `teacher-homepage` reference draws it: the
/// app-wide [AppBottomNav] with its defaults and four tabs — Нүүр, Хуваарь,
/// Дүнгийн хуудас, Профайл. With the bar's 16pt insets the tab centres fall
/// at 61, 151, 242 and 332, where the reference puts them.
///
/// The one override is [AppBottomNav.labelSize]: the reference sets its
/// labels at 10, not the student bars' 12 — every label's ink measures 0.82
/// of the 12pt one, width and height alike — which is what keeps
/// "Дүнгийн хуудас" on one line in its 90pt tab.
///
/// Only Нүүр has a screen. The other three are inert ([AppBottomNavItem.onTap]
/// null) until their own tasks build them: Schedule, the grade sheet and the
/// teacher Profile are out of Teacher Home's scope (Issue #229).
class TeacherBottomNav extends StatelessWidget {
  const TeacherBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppBottomNav(
      currentIndex: 0,
      labelSize: 10,
      items: [
        AppBottomNavItem(
          icon: AppIcons.house,
          selectedAsset: _homeFilled,
          label: TeacherHomeStrings.navHome,
        ),
        AppBottomNavItem(
          icon: AppIcons.calendar,
          label: TeacherHomeStrings.navSchedule,
        ),
        AppBottomNavItem(
          icon: AppIcons.exam,
          label: TeacherHomeStrings.navGrades,
        ),
        AppBottomNavItem(
          icon: AppIcons.user,
          label: TeacherHomeStrings.navProfile,
        ),
      ],
    );
  }
}
