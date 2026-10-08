import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../courses/fake_course_repository.dart';
import '../enrollments/fake_enrolled_cohorts_repository.dart';
import '../enrollments/fake_enrollment_repository.dart';
import 'fake_cohort_repository.dart';

/// A light-mode capture of the Cohort list — `CohortCard` in its states —
/// taken before any theme migration touches it (Dark Mode Phase 0, Issue
/// #252). It must stay byte-identical while colours move onto `AppPalette`.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('Cohort list', (tester) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: CohortListScreen(
          repository: FakeCohortRepository(
            cohorts: [
              sampleCohort(id: 1, name: 'Cohort 01', status: 'finished'),
              sampleCohort(id: 2, name: 'Cohort 02', status: 'active'),
              sampleCohort(id: 3, name: 'Cohort 03'),
            ],
          ),
          courseRepository: FakeCourseRepository(),
          enrollmentRepository: FakeEnrollmentRepository(),
          enrolledCohortsRepository: FakeEnrolledCohortsRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/cohort_list.png'),
    );
  });
}
