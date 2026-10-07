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

  test('a teacher lands on Teacher Home', () {
    expect(homeRouteFor(UserType.teacher), HomeRoutes.teacher);
  });

  test('staff and unknown keep the pre-user_type landing', () {
    // No staff mobile experience exists; sign-in always went to `/home`, and
    // still does for these.
    for (final type in [UserType.staff, UserType.unknown]) {
      expect(homeRouteFor(type), '/home', reason: type.name);
    }
  });
}
