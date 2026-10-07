import 'package:flutter/material.dart';

import '../domain/user_type.dart';
import 'reset_password_screen.dart';
import 'reset_password_strings.dart';

/// The route a signed-in account lands on — the one place `user_type` picks
/// an app experience. Both sign-in (`LoginScreen`) and a launch that finds a
/// live session already held (`SplashScreen`) go through here, and through
/// [openSignedIn], so the two cannot disagree.
///
/// `child` and `teacher` have experiences of their own: Junior Home, and
/// Teacher Home (Issue #229) — a teacher's token is refused by the student
/// dashboard's `GET /me/cohorts` (`403 forbidden`, confirmed live), so a
/// teacher must never land there. Everything else lands where sign-in always
/// has:
///
///   * `staff` — back-office, "not a mobile user" per the API index; today's
///     behaviour, not a new screen.
///   * `unknown` — a response without `user_type`; also today's behaviour.
String homeRouteFor(UserType userType) => switch (userType) {
  UserType.child => HomeRoutes.junior,
  UserType.teacher => HomeRoutes.teacher,
  UserType.adult ||
  UserType.staff ||
  UserType.unknown => HomeRoutes.adult,
};

/// Opens the signed-in experience in place of the current route — the one
/// hand-off both sign-in (`LoginScreen`) and a restored session
/// (`SplashScreen`) make, so neither can skip what the other enforces.
///
/// When the account must change its password (`GET /auth/me`
/// `must_change_password`, Issue #182) it is **required**: the existing
/// "Нууц үгээ тохируулах" screen (`ResetPasswordScreen`, Figma `Sign in - 6`
/// … `10`) replaces the current route instead of [homeRoute]. That screen
/// draws no skip or back control, and nothing sits under it to pop back to,
/// so Home is reached only by changing the password: then the screen's own
/// success message shows and [openHome] runs.
///
/// [openHome] defaults to replacing the route with [homeRoute]; `LoginScreen`
/// passes its injected `onSignedIn` through it.
void openSignedIn(
  BuildContext context, {
  required String homeRoute,
  required bool mustChangePassword,
  void Function(BuildContext context)? openHome,
}) {
  void goHome(BuildContext context) => openHome != null
      ? openHome(context)
      : Navigator.of(context).pushReplacementNamed(homeRoute);

  if (!mustChangePassword) {
    goHome(context);
    return;
  }
  Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (context) => ResetPasswordScreen(
        onCompleted: () {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(content: Text(ResetPasswordStrings.success)),
          );
          goHome(context);
        },
      ),
    ),
  );
}

/// The two landing routes `AiAcademyApp` registers.
abstract final class HomeRoutes {
  /// The adult dashboard — `HomeScreen`.
  static const String adult = '/home';

  /// Home for a student in kids mode — `JuniorHomeScreen`.
  static const String junior = '/junior-home';

  /// Home for a teacher — `TeacherHomeScreen` (Issue #229).
  static const String teacher = '/teacher-home';
}
