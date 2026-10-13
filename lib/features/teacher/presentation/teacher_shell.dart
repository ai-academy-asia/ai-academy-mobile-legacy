import 'package:flutter/widgets.dart';

import '../../../shared/widgets/persistent_tab_shell.dart';
import 'teacher_gradebook_screen.dart';
import 'teacher_profile_screen.dart';
import 'teacher_schedule_screen.dart';
import 'widgets/teacher_bottom_nav.dart';
import 'widgets/teacher_tabs.dart';

/// The Teacher app's tabs — Хуваарь, Хөтөлбөрүүд, Профайл — under one
/// persistent [TeacherBottomNav] (Issue #241), as [PersistentTabShell]
/// describes: a tab switch changes only the content above the bar, never
/// pushes a route, and keeps each opened tab as it was left.
///
/// Хуваарь is the Teacher area's first tab and default page (Issue #370 —
/// the redesign drops the former Нүүр tab): the shell opens on it, and system
/// back on another tab returns to it. Профайл is [TeacherProfileScreen]
/// (Issue #243).
///
/// The Teacher landing route (`/teacher-home`, where sign-in sends a teacher)
/// and `/teacher-schedule` open it on Хуваарь, `/teacher-gradebook` on
/// Хөтөлбөрүүд; Профайл has no route of its own — it is reached from the
/// bar. Deeper screens — session sheets, the request screen, Programs'
/// student list and student detail, Profile's Change password — are
/// still pushed over the whole shell.
class TeacherShell extends StatelessWidget {
  const TeacherShell({
    super.key,
    this.initialTab = TeacherTab.schedule,
    this.schedule,
    this.grades,
    this.profile,
  });

  /// The tab shown first.
  final TeacherTab initialTab;

  /// The three tab screens, each drawn without its own bar. Default to the
  /// real ones; injected in tests.
  final Widget? schedule;
  final Widget? grades;
  final Widget? profile;

  /// The tabs with content, in bar order — their index here is their index
  /// on the bar.
  static const List<TeacherTab> tabs = [
    TeacherTab.schedule,
    TeacherTab.grades,
    TeacherTab.profile,
  ];

  Widget _screenFor(TeacherTab tab) => switch (tab) {
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
      // System back returns to Хуваарь, the Teacher area's first tab.
      homeIndex: tabs.indexOf(TeacherTab.schedule),
      tabBuilder: (index) => _screenFor(tabs[index]),
      barBuilder: (current, select) => TeacherBottomNav(
        current: tabs[current],
        onSelect: (tab) => select(tabs.indexOf(tab)),
      ),
    );
  }
}
