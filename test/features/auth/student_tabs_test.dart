import 'package:aia_mobile/features/auth/presentation/home_route.dart';
import 'package:aia_mobile/features/auth/presentation/student_tabs.dart';
import 'package:flutter_test/flutter_test.dart';

/// The student tab routes, by track. Both tracks' tabs now switch inside a
/// persistent shell rather than by route — `AdultStudentShell` (#237) and
/// `JuniorStudentShell` (#241) — so their behaviour is covered by
/// `adult_student_shell_test.dart` and `junior_student_shell_test.dart`;
/// each route here only opens its track's shell on that tab.
void main() {
  test('each track names its own routes', () {
    expect(
      StudentTabRoutes.of(StudentTrack.adult, StudentTab.progress),
      '/my-cohorts',
    );
    expect(
      StudentTabRoutes.of(StudentTrack.adult, StudentTab.profile),
      '/profile',
    );
    expect(
      StudentTabRoutes.of(StudentTrack.junior, StudentTab.progress),
      '/junior-progress',
    );
    expect(
      StudentTabRoutes.of(StudentTrack.junior, StudentTab.profile),
      '/junior-profile',
    );
    expect(
      StudentTabRoutes.of(StudentTrack.junior, StudentTab.home),
      HomeRoutes.junior,
    );
    expect(
      StudentTabRoutes.of(StudentTrack.adult, StudentTab.home),
      HomeRoutes.adult,
    );
  });
}
