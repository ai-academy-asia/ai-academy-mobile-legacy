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
/// Нүүр, Хуваарь (Issue #231) and Дүнгийн хуудас (Issue #233) switch
/// through [openTeacherTab]. The teacher Profile has no screen, so its tab
/// stays inert ([AppBottomNavItem.onTap] null). The `dungiin-huudas`
/// reference draws a different bar (Хуваарь, Дүнгийн хуудас, Хөтөлбөр,
/// Профайл); the app keeps this one by instruction.
///
/// The selected Хуваарь draws the outline calendar in the bar's blue, and the
/// selected Дүнгийн хуудас the outline "A+" sheet: the references' filled
/// glyphs have not been exported.
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
        AppBottomNavItem(
          icon: AppIcons.exam,
          label: TeacherHomeStrings.navGrades,
          onTap: open(TeacherTab.grades),
        ),
        const AppBottomNavItem(
          icon: AppIcons.user,
          label: TeacherHomeStrings.navProfile,
        ),
      ],
    );
  }
}
