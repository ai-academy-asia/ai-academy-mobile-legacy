import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../teacher_home_strings.dart';
import 'teacher_tabs.dart';

/// Phosphor "House" Fill — the export `AdultBottomNav` draws.
const String _homeFilled = 'assets/icons/nav_home_selected.svg';

/// The teacher tab bar, as the `teacher-homepage` and `huvaari` references
/// draw it: the app-wide [AppBottomNav] with its defaults and four tabs —
/// Нүүр, Хуваарь, Дүнгийн хуудас, Профайл. With the bar's 16pt insets the
/// tab centres fall at 61, 151, 242 and 332, where the references put them.
///
/// The one override is [AppBottomNav.labelSize]: the reference sets its
/// labels at 10, not the student bars' 12 — every label's ink measures 0.82
/// of the 12pt one, width and height alike — which is what keeps
/// "Дүнгийн хуудас" on one line in its 90pt tab.
///
/// Нүүр and Хуваарь switch through [openTeacherTab] (Issue #231). The grade
/// sheet and the teacher Profile have no screens, so their tabs stay inert
/// ([AppBottomNavItem.onTap] null). The selected Хуваарь draws the outline
/// calendar in the bar's blue: the reference's filled glyph has not been
/// exported.
class TeacherBottomNav extends StatelessWidget {
  const TeacherBottomNav({this.current = TeacherTab.home, super.key});

  /// The tab whose screen this is. Drawn selected, and inert.
  final TeacherTab current;

  @override
  Widget build(BuildContext context) {
    VoidCallback? open(TeacherTab tab) =>
        tab == current ? null : () => openTeacherTab(context, tab);

    return AppBottomNav(
      currentIndex: current.index,
      labelSize: 10,
      items: [
        AppBottomNavItem(
          icon: AppIcons.house,
          selectedAsset: _homeFilled,
          label: TeacherHomeStrings.navHome,
          onTap: open(TeacherTab.home),
        ),
        AppBottomNavItem(
          icon: AppIcons.calendar,
          label: TeacherHomeStrings.navSchedule,
          onTap: open(TeacherTab.schedule),
        ),
        const AppBottomNavItem(
          icon: AppIcons.exam,
          label: TeacherHomeStrings.navGrades,
        ),
        const AppBottomNavItem(
          icon: AppIcons.user,
          label: TeacherHomeStrings.navProfile,
        ),
      ],
    );
  }
}
