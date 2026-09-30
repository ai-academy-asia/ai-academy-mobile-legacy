import 'package:aia_mobile/app.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_screen.dart';
import 'package:aia_mobile/features/home/presentation/home_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('registers the cohort list as the /cohorts route', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(393, 852) * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AiAcademyApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final builder = app.routes?['/cohorts'];

    expect(builder, isNotNull);
    // Built, not pumped: the real screen would reach for the real API.
    expect(
      builder!(tester.element(find.byType(MaterialApp))),
      isA<CohortListScreen>(),
    );
  });

  testWidgets('registers the student\'s cohort list as /my-cohorts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(393, 852) * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AiAcademyApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final builder = app.routes?['/my-cohorts'];

    expect(builder, isNotNull);
    // Built, not pumped: the real screen would reach for the real API.
    final screen = builder!(tester.element(find.byType(MaterialApp)));
    expect(screen, isA<CohortListScreen>());
    expect((screen as CohortListScreen).enrolledOnly, isTrue);
  });

  testWidgets('registers both homes sign-in can land on', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(393, 852) * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AiAcademyApp());

    // `homeRouteFor` picks between these two by `user_type`. The
    // `/dev/junior-home` preview door of Issue #98 stays removed.
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final context = tester.element(find.byType(MaterialApp));
    final home = app.routes?['/home'];
    final juniorHome = app.routes?['/junior-home'];

    expect(home, isNotNull);
    // Built, not pumped: the real screens would reach for the real API.
    expect(home!(context), isA<HomeScreen>());
    expect(juniorHome, isNotNull);
    expect(juniorHome!(context), isA<JuniorHomeScreen>());
    expect(app.routes, isNot(contains('/dev/junior-home')));
  });
}
