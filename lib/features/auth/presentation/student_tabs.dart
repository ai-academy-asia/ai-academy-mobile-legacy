import 'package:flutter/widgets.dart';

import 'home_route.dart';

/// The student tab bar's three destinations, in the order `AppBottomNav`
/// draws them.
///
/// Junior and adult students see different Home screens but the same three
/// tabs, so the bar on every screen that draws it — `HomeScreen`,
/// `JuniorHomeScreen`, `CohortListScreen`, `ProfileScreen` — switches tab
/// through [openStudentTab] rather than each one choosing its own push or pop.
enum StudentTab {
  /// Нүүр — the Home the signed-in account landed on, adult or junior.
  home,

  /// The student's own enrolled cohorts — the adult bar's Хичээл, the junior
  /// bar's Сурлагын явц.
  progress,

  /// Профайл.
  profile,
}

/// The two tab routes `AiAcademyApp` registers besides the [HomeRoutes].
abstract final class StudentTabRoutes {
  /// `CohortListScreen(enrolledOnly: true)`.
  static const String progress = '/my-cohorts';

  /// `ProfileScreen`.
  static const String profile = '/profile';
}

/// Switches the student tab bar to [tab].
///
/// Home is always the root of the stack once signed in — sign-in and the
/// splash hand-off both *replace* their route with it — so Home is reached by
/// popping back to it, and every other tab is pushed directly on top of it,
/// replacing whatever tab was there. The stack is therefore never deeper than
/// Home plus one tab, and moving between tabs never piles up duplicates.
///
/// Which Home that is needs no `user_type` here: it is whichever one
/// `homeRouteFor` put at the root.
void openStudentTab(BuildContext context, StudentTab tab) {
  final navigator = Navigator.of(context);
  switch (tab) {
    case StudentTab.home:
      navigator.popUntil(_isHome);
    case StudentTab.progress:
      navigator.pushNamedAndRemoveUntil(StudentTabRoutes.progress, _isHome);
    case StudentTab.profile:
      navigator.pushNamedAndRemoveUntil(StudentTabRoutes.profile, _isHome);
  }
}

/// Either Home route, by name. `isFirst` is the fallback for a stack that (in
/// a test, say) never carries a route actually named after one, so popping
/// always terminates.
bool _isHome(Route<dynamic> route) =>
    route.isFirst ||
    route.settings.name == HomeRoutes.adult ||
    route.settings.name == HomeRoutes.junior;
