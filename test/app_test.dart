import 'package:aia_mobile/app.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('registers the cohort list as the /cohorts route', (tester) async {
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
}
