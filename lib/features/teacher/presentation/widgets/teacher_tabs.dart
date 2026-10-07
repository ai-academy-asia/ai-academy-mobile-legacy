import 'package:flutter/widgets.dart';

import '../../../auth/presentation/home_route.dart';

/// The teacher tab bar's destinations, in the order `TeacherBottomNav`
/// draws them.
enum TeacherTab {
  /// Нүүр — Teacher Home.
  home,

  /// Хуваарь — Teacher Schedule (Issue #231).
  schedule,

  /// Дүнгийн хуудас — Teacher Gradebook (Issue #233).
  grades,

  /// Профайл — no screen yet.
  profile,
}

/// The routes `AiAcademyApp` registers for the teacher tabs after Home.
abstract final class TeacherTabRoutes {
  static const String schedule = '/teacher-schedule';

  /// Teacher Gradebook (Issue #233).
  static const String gradebook = '/teacher-gradebook';
}

/// Switches the teacher tab bar to [tab], the way `openStudentTab` switches
/// the student bars: Teacher Home is the root of the stack, reached by
/// popping back to it; any other tab is pushed directly on top of it. Tabs
/// with no screen are never passed here.
void openTeacherTab(BuildContext context, TeacherTab tab) {
  final navigator = Navigator.of(context);
  switch (tab) {
    case TeacherTab.home:
      navigator.popUntil(_isTeacherHome);
    case TeacherTab.schedule:
      navigator.pushNamedAndRemoveUntil(
        TeacherTabRoutes.schedule,
        _isTeacherHome,
      );
    case TeacherTab.grades:
      navigator.pushNamedAndRemoveUntil(
        TeacherTabRoutes.gradebook,
        _isTeacherHome,
      );
    case TeacherTab.profile:
      break;
  }
}

/// Teacher Home, by name. `isFirst` is the fallback for a stack that never
/// carries a route named after it, so popping always terminates.
bool _isTeacherHome(Route<dynamic> route) =>
    route.isFirst || route.settings.name == HomeRoutes.teacher;
