import 'package:flutter/widgets.dart';

import '../../../shared/widgets/persistent_tab_shell.dart';
import 'teacher_gradebook_screen.dart';
import 'teacher_home_screen.dart';
import 'teacher_profile_screen.dart';
import 'teacher_schedule_screen.dart';
import 'widgets/teacher_bottom_nav.dart';
import 'widgets/teacher_tabs.dart';

/// The Teacher app's tabs — Нүүр, Хуваарь, Дүнгийн хуудас, Профайл — under
/// one persistent [TeacherBottomNav] (Issue #241), as [PersistentTabShell]
/// describes: a tab switch changes only the content above the bar, never
/// pushes a route, and keeps each opened tab as it was left.
///
/// All four tabs have content; Профайл is [TeacherProfileScreen] (Issue
/// #243).
///
/// `/teacher-home`, `/teacher-schedule` and `/teacher-gradebook` each open it
/// on their own tab; Профайл has no route of its own — it is reached from
/// the bar. Deeper screens — session sheets, the request screen, Gradebook's
/// class, student and submission screens, Profile's Change password — are
/// still pushed over the whole shell.
class TeacherShell extends StatelessWidget {
  const TeacherShell({
    super.key,
    this.initialTab = TeacherTab.home,
    this.home,
    this.schedule,
    this.grades,
    this.profile,
  });

  /// The tab shown first.
  final TeacherTab initialTab;

  /// The four tab screens, each drawn without its own bar. Default to the
  /// real ones; injected in tests.
  final Widget? home;
  final Widget? schedule;
  final Widget? grades;
  final Widget? profile;

  /// The tabs with content, in bar order — their index here is their index
  /// on the bar.
  static const List<TeacherTab> tabs = [
    TeacherTab.home,
    TeacherTab.schedule,
    TeacherTab.grades,
    TeacherTab.profile,
  ];

  Widget _screenFor(TeacherTab tab) => switch (tab) {
    TeacherTab.home => home ?? const TeacherHomeScreen(showBottomNav: false),
    TeacherTab.schedule =>
      schedule ?? const TeacherScheduleScreen(showBottomNav: false),
    TeacherTab.grades =>
      grades ?? const TeacherGradebookScreen(showBottomNav: false),
    TeacherTab.profile => profile ?? const TeacherProfileScreen(),
  };

  @override
  Widget build(BuildContext context) {
    return PersistentTabShell(
      tabCount: tabs.length,
      initialIndex: tabs.indexOf(initialTab),
      homeIndex: tabs.indexOf(TeacherTab.home),
      tabBuilder: (index) => _screenFor(tabs[index]),
      barBuilder: (current, select) => TeacherBottomNav(
        current: tabs[current],
        onSelect: (tab) => select(tabs.indexOf(tab)),
      ),
    );
  }
}
