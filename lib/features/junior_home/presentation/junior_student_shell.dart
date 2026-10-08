import 'package:flutter/widgets.dart';

import '../../../shared/widgets/persistent_tab_shell.dart';
import '../../auth/presentation/student_tabs.dart';
import 'junior_home_screen.dart';
import 'junior_profile_screen.dart';
import 'junior_progress_screen.dart';
import 'widgets/junior_bottom_nav.dart';

/// The Junior Student app's three tabs — Нүүр, Сурлагын явц, Профайл — under
/// one persistent [JuniorBottomNav] (Issue #241), as [PersistentTabShell]
/// describes: a tab switch changes only the content above the bar, never
/// pushes a route, and keeps each opened tab as it was left.
///
/// `/junior-home`, `/junior-progress` and `/junior-profile` each open it on
/// their own tab. Deeper screens — course detail, lessons, the Profile's
/// actions — are still pushed over the whole shell.
class JuniorStudentShell extends StatelessWidget {
  const JuniorStudentShell({
    super.key,
    this.initialTab = StudentTab.home,
    this.home,
    this.progress,
    this.profile,
  });

  /// The tab shown first.
  final StudentTab initialTab;

  /// The three tab screens, each drawn without its own bar. Default to the
  /// real ones; injected in tests.
  final Widget? home;
  final Widget? progress;
  final Widget? profile;

  Widget _screenFor(StudentTab tab) => switch (tab) {
    StudentTab.home => home ?? const JuniorHomeScreen(showBottomNav: false),
    StudentTab.progress =>
      progress ?? const JuniorProgressScreen(showBottomNav: false),
    StudentTab.profile =>
      profile ?? const JuniorProfileScreen(showBottomNav: false),
  };

  @override
  Widget build(BuildContext context) {
    return PersistentTabShell(
      tabCount: StudentTab.values.length,
      initialIndex: initialTab.index,
      homeIndex: StudentTab.home.index,
      tabBuilder: (index) => _screenFor(StudentTab.values[index]),
      barBuilder: (current, select) => JuniorBottomNav(
        current: StudentTab.values[current],
        onSelect: (tab) => select(tab.index),
      ),
    );
  }
}
