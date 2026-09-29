import 'package:aia_mobile/app.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_screen.dart';
import 'package:aia_mobile/features/home/presentation/home_screen.dart';
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

  testWidgets('sign-in lands on the adult dashboard', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(393, 852) * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AiAcademyApp());

    // `/home` is the adult dashboard and nothing reads `user_type` to choose
    // between it and Junior Home yet — that is its own issue. Junior Home is
    // therefore registered on no route at all: the `/dev/junior-home` preview
    // door existed only for the visual QA of Issue #98 and has been removed.
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final home = app.routes?['/home'];

    expect(home, isNotNull);
    expect(home!(tester.element(find.byType(MaterialApp))), isA<HomeScreen>());
    expect(app.routes, isNot(contains('/dev/junior-home')));
  });
}
