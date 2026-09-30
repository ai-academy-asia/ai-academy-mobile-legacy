import 'package:aia_mobile/features/auth/domain/user_type.dart';
import 'package:aia_mobile/features/auth/presentation/home_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a child lands on Junior Home', () {
    expect(homeRouteFor(UserType.child), HomeRoutes.junior);
  });

  test('an adult lands on the adult dashboard', () {
    expect(homeRouteFor(UserType.adult), HomeRoutes.adult);
  });

  test('teacher, staff and unknown keep the pre-user_type landing', () {
    // No teacher or staff mobile experience exists; sign-in always went to
    // `/home`, and still does for these.
    for (final type in [UserType.teacher, UserType.staff, UserType.unknown]) {
      expect(homeRouteFor(type), '/home', reason: type.name);
    }
  });
}
