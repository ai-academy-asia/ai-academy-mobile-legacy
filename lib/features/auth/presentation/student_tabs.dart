import 'package:flutter/widgets.dart';

import 'home_route.dart';

/// The student tab bar's three destinations, in the order `AppBottomNav`
/// draws them.
enum StudentTab {
  /// Нүүр — the track's Home.
  home,

  /// The adult bar's Хичээл, the junior bar's Сурлагын явц.
  progress,

  /// Профайл.
  profile,
}

/// Which set of tab screens a bar belongs to.
///
/// The two tracks share the tab bar's *behaviour* but not its screens: the
/// Figma pack draws a Junior Home, a Junior "Сурлагын явц" and a Junior
/// Profile of their own, so a junior bar never opens an adult screen and an
/// adult bar never opens a junior one. `homeRouteFor` picks the track at
/// sign-in; every screen after that knows which track it belongs to, because
/// each track's screens are distinct widgets.
enum StudentTrack {
  /// `HomeScreen`, `CohortListScreen(enrolledOnly: true)`, `ProfileScreen`.
  adult,

  /// `JuniorHomeScreen`, `JuniorProgressScreen`, `JuniorProfileScreen`.
  junior,
}

/// The tab routes `AiAcademyApp` registers besides the [HomeRoutes].
abstract final class StudentTabRoutes {
  /// `CohortListScreen(enrolledOnly: true)`.
  static const String adultProgress = '/my-cohorts';

  /// `ProfileScreen`.
  static const String adultProfile = '/profile';

  /// `JuniorProgressScreen`.
  static const String juniorProgress = '/junior-progress';

  /// `JuniorProfileScreen`.
  static const String juniorProfile = '/junior-profile';

  /// The route [tab] opens on [track]'s bar. [StudentTab.home] is not pushed
  /// by name — see [openStudentTab] — but is answered too, for completeness.
  static String of(StudentTrack track, StudentTab tab) =>
      switch ((track, tab)) {
        (StudentTrack.adult, StudentTab.home) => HomeRoutes.adult,
        (StudentTrack.adult, StudentTab.progress) => adultProgress,
        (StudentTrack.adult, StudentTab.profile) => adultProfile,
        (StudentTrack.junior, StudentTab.home) => HomeRoutes.junior,
        (StudentTrack.junior, StudentTab.progress) => juniorProgress,
        (StudentTrack.junior, StudentTab.profile) => juniorProfile,
      };
}

/// Switches [track]'s tab bar to [tab].
///
/// Home is always the root of the stack once signed in — sign-in and the
/// splash hand-off both *replace* their route with it — so Home is reached by
/// popping back to it, and every other tab is pushed directly on top of it,
/// replacing whatever tab was there. The stack is therefore never deeper than
/// Home plus one tab, and moving between tabs never piles up duplicates.
void openStudentTab(BuildContext context, StudentTrack track, StudentTab tab) {
  final navigator = Navigator.of(context);
  if (tab == StudentTab.home) {
    navigator.popUntil(_isHome);
  } else {
    navigator.pushNamedAndRemoveUntil(StudentTabRoutes.of(track, tab), _isHome);
  }
}

/// Either Home route, by name. `isFirst` is the fallback for a stack that (in
/// a test, say) never carries a route actually named after one, so popping
/// always terminates.
bool _isHome(Route<dynamic> route) =>
    route.isFirst ||
    route.settings.name == HomeRoutes.adult ||
    route.settings.name == HomeRoutes.junior;
