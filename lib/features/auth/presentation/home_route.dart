import '../domain/user_type.dart';

/// The route a signed-in account lands on — the one place `user_type` picks
/// an app experience. Both sign-in (`LoginScreen`) and a launch that finds a
/// live session already held (`SplashScreen`) go through here, so the two
/// cannot disagree.
///
/// Only `child` has an experience of its own. Everything else lands where
/// sign-in always has:
///
///   * `teacher` — there is no teacher mobile experience yet, so this keeps
///     today's behaviour (`/home`) rather than inventing one.
///   * `staff` — back-office, "not a mobile user" per the API index; also
///     today's behaviour, not a new screen.
///   * `unknown` — a response without `user_type`; also today's behaviour.
String homeRouteFor(UserType userType) => switch (userType) {
  UserType.child => HomeRoutes.junior,
  UserType.adult ||
  UserType.teacher ||
  UserType.staff ||
  UserType.unknown => HomeRoutes.adult,
};

/// The two landing routes `AiAcademyApp` registers.
abstract final class HomeRoutes {
  /// The adult dashboard — `HomeScreen`.
  static const String adult = '/home';

  /// Home for a student in kids mode — `JuniorHomeScreen`.
  static const String junior = '/junior-home';
}
