import 'package:flutter/widgets.dart';

import '../../../shared/widgets/persistent_tab_shell.dart';
import 'teacher_gradebook_screen.dart';
import 'teacher_home_screen.dart';
import 'teacher_schedule_screen.dart';
import 'widgets/teacher_bottom_nav.dart';
import 'widgets/teacher_tabs.dart';

/// The Teacher app's tabs — Нүүр, Хуваарь, Дүнгийн хуудас, Профайл — under
/// one persistent [TeacherBottomNav] (Issue #241), as [PersistentTabShell]
/// describes: a tab switch changes only the content above the bar, never
/// pushes a route, and keeps each opened tab as it was left.
///
/// Three tabs have content. Профайл has no screen (a `PRODUCT DECISION`,
/// #241), so its bar item stays inert and the shell never selects it.
///
/// `/teacher-home`, `/teacher-schedule` and `/teacher-gradebook` each open it
/// on their own tab. Deeper screens — session sheets, the request screen,
/// Gradebook's class, student and submission screens — are still pushed over
/// the whole shell.
class TeacherShell extends StatelessWidget {
  const TeacherShell({
    super.key,
    this.initialTab = TeacherTab.home,
    this.home,
    this.schedule,
    this.grades,
  }) : assert(initialTab != TeacherTab.profile);

  /// The tab shown first. Never [TeacherTab.profile].
  final TeacherTab initialTab;

  /// The three tab screens, each drawn without its own bar. Default to the
  /// real ones; injected in tests.
  final Widget? home;
  final Widget? schedule;
  final Widget? grades;

  /// The tabs with content, in bar order — their index here is their index
  /// on the bar.
  static const List<TeacherTab> tabs = [
    TeacherTab.home,
    TeacherTab.schedule,
    TeacherTab.grades,
  ];

  Widget _screenFor(TeacherTab tab) => switch (tab) {
    TeacherTab.home => home ?? const TeacherHomeScreen(showBottomNav: false),
    TeacherTab.schedule =>
      schedule ?? const TeacherScheduleScreen(showBottomNav: false),
    TeacherTab.grades =>
      grades ?? const TeacherGradebookScreen(showBottomNav: false),
    // Never built: the bar keeps Профайл inert.
    TeacherTab.profile => const SizedBox.shrink(),
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
