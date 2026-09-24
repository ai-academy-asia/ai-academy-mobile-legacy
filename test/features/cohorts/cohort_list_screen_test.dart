import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:aia_mobile/core/theme/app_dimens.dart';
import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_screen.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_strings.dart';
import 'package:aia_mobile/features/cohorts/presentation/widgets/cohort_card.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort.dart';
import 'package:aia_mobile/features/courses/presentation/course_detail_screen.dart';
import 'package:aia_mobile/features/enrollments/domain/enrolled_cohorts_repository.dart';
import 'package:aia_mobile/features/enrollments/domain/enrollment_failure.dart';
import 'package:aia_mobile/features/enrollments/presentation/enrollment_strings.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../courses/fake_course_repository.dart';
import '../enrollments/fake_enrolled_cohorts_repository.dart';
import '../enrollments/fake_enrollment_repository.dart';
import 'fake_cohort_repository.dart';

/// Loads the real Manrope face, the same reason the other screen tests do —
/// without it, card text is measured in the fallback font.
Future<void> _loadFonts() async {
  final loader = FontLoader('Manrope')
    ..addFont(rootBundle.load('assets/fonts/Manrope-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Manrope-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Manrope-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Manrope-Bold.ttf'));
  await loader.load();
}

/// The "Бүртгүүлсэн" row `CohortCard` no longer draws. Kept here, not in
/// `EnrollmentStrings`, only so the tests can assert it stays gone.
const String _enrolledLabel = 'Бүртгүүлсэн';

void main() {
  setUpAll(_loadFonts);

  Future<void> pumpList(
    WidgetTester tester,
    FakeCohortRepository repository, {
    FakeCourseRepository? courseRepository,
    FakeEnrollmentRepository? enrollmentRepository,
    FakeEnrolledCohortsRepository? enrolledCohortsRepository,
    int? courseId,
    bool enrolledOnly = false,
    Size size = const Size(393, 852),
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = size * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CohortListScreen(
          repository: repository,
          // Always fakes: the defaults would reach for the app-wide session
          // and the real API.
          courseRepository: courseRepository ?? FakeCourseRepository(),
          enrollmentRepository:
              enrollmentRepository ?? FakeEnrollmentRepository(),
          enrolledCohortsRepository:
              enrolledCohortsRepository ?? FakeEnrolledCohortsRepository(),
          courseId: courseId,
          enrolledOnly: enrolledOnly,
        ),
      ),
    );
  }

  group('header', () {
    testWidgets('is the title alone — no back arrow on a top-level screen', (
      tester,
    ) async {
      await pumpList(tester, FakeCohortRepository(cohorts: [sampleCohort()]));
      await tester.pumpAndSettle();

      expect(find.text(CohortListStrings.heading), findsOneWidget);
      expect(find.byIcon(AppIcons.caretLeft), findsNothing);
    });

    testWidgets('leaves 16 between the header rule and the first card', (
      tester,
    ) async {
      await pumpList(tester, FakeCohortRepository(cohorts: [sampleCohort()]));
      await tester.pumpAndSettle();

      final rule = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.color == AppColors.border &&
            widget.constraints?.maxHeight == AppDimens.borderWidth,
      );
      expect(rule, findsOneWidget);

      final gap =
          tester.getTopLeft(find.byType(CohortCard).first).dy -
          tester.getBottomLeft(rule).dy;
      expect(gap, AppDimens.screenPadding);
    });
  });

  group('bottom navigation', () {
    testWidgets('the home tab returns to the Home route', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          theme: AppTheme.light,
          initialRoute: '/home',
          routes: {'/home': (_) => const Scaffold(body: Text('home route'))},
        ),
      );

      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => CohortListScreen(
            repository: FakeCohortRepository(cohorts: [sampleCohort()]),
            courseRepository: FakeCourseRepository(),
            enrollmentRepository: FakeEnrollmentRepository(),
            enrolledCohortsRepository: FakeEnrolledCohortsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(CohortListStrings.heading), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.house));
      await tester.pumpAndSettle();

      expect(find.text('home route'), findsOneWidget);
      expect(find.text(CohortListStrings.heading), findsNothing);
    });

    testWidgets('the home tab returns to Home even from several screens deep', (
      tester,
    ) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          theme: AppTheme.light,
          initialRoute: '/home',
          routes: {'/home': (_) => const Scaffold(body: Text('home route'))},
        ),
      );

      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('intermediate screen')),
        ),
      );
      await tester.pumpAndSettle();

      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => CohortListScreen(
            repository: FakeCohortRepository(cohorts: [sampleCohort()]),
            courseRepository: FakeCourseRepository(),
            enrollmentRepository: FakeEnrollmentRepository(),
            enrolledCohortsRepository: FakeEnrolledCohortsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(AppIcons.house));
      await tester.pumpAndSettle();

      expect(find.text('home route'), findsOneWidget);
      expect(find.text('intermediate screen'), findsNothing);
      expect(find.text(CohortListStrings.heading), findsNothing);
    });
  });

  group('course detail navigation', () {
    testWidgets(
      'tapping a card opens Course Detail with the resolved catalog slug, '
      'not the cohort\'s own stale one',
      (tester) async {
        // Reproduces the real, confirmed drift `resolveCohortCourse`'s own
        // doc comment describes: `sampleCohort()`'s embedded course (id 6,
        // slug "summer-bootcamp-2027") shares its title with
        // `sampleCourse()`'s catalog entry (id 4, slug "summer-bootcamp").
        await pumpList(
          tester,
          FakeCohortRepository(cohorts: [sampleCohort()]),
          courseRepository: FakeCourseRepository(courses: [sampleCourse()]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(sampleCohort().name));
        await tester.pumpAndSettle();

        final detail = tester.widget<CourseDetailScreen>(
          find.byType(CourseDetailScreen),
        );
        expect(detail.slug, 'summer-bootcamp');
      },
    );

    testWidgets(
      'falls back to the cohort\'s own slug when the catalog has no match',
      (tester) async {
        await pumpList(
          tester,
          FakeCohortRepository(cohorts: [sampleCohort()]),
          courseRepository: FakeCourseRepository(courses: const []),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(sampleCohort().name));
        await tester.pumpAndSettle();

        final detail = tester.widget<CourseDetailScreen>(
          find.byType(CourseDetailScreen),
        );
        expect(detail.slug, 'summer-bootcamp-2027');
      },
    );
  });

  group('loading', () {
    testWidgets('shows a spinner while the first fetch is in flight', (
      tester,
    ) async {
      final repository = FakeCohortRepository(hold: true);
      await pumpList(tester, repository);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(CohortCard), findsNothing);
      expect(find.text(CohortListStrings.empty), findsNothing);

      repository.release();
      await tester.pumpAndSettle();
    });

    testWidgets('still shows the heading while loading', (tester) async {
      final repository = FakeCohortRepository(hold: true);
      await pumpList(tester, repository);
      await tester.pump();

      expect(find.text(CohortListStrings.heading), findsOneWidget);

      repository.release();
      await tester.pumpAndSettle();
    });
  });

  group('loaded', () {
    testWidgets('renders one card per cohort, in the order returned', (
      tester,
    ) async {
      final cohorts = [
        sampleCohort(id: 1, name: 'A'),
        sampleCohort(id: 2, name: 'B'),
        sampleCohort(id: 3, name: 'C'),
      ];
      await pumpList(tester, FakeCohortRepository(cohorts: cohorts));
      await tester.pumpAndSettle();

      expect(find.byType(CohortCard), findsNWidgets(3));
      final rendered = tester
          .widgetList<CohortCard>(find.byType(CohortCard))
          .map((card) => card.cohort.id)
          .toList();
      expect(rendered, [1, 2, 3]);
    });

    testWidgets('shows the confirmed fields of a cohort', (tester) async {
      await pumpList(tester, FakeCohortRepository(cohorts: [sampleCohort()]));
      await tester.pumpAndSettle();

      expect(find.text('Corporate Leaders 2026-08'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Зуны бүтээлч кэмп'), findsOneWidget);
    });
  });

  group('course filter', () {
    testWidgets('shows only cohorts matching the given course id', (
      tester,
    ) async {
      final cohorts = [
        sampleCohort(id: 1, courseId: 6),
        sampleCohort(id: 2, courseId: 9),
        sampleCohort(id: 3, courseId: 6),
      ];
      await pumpList(
        tester,
        FakeCohortRepository(cohorts: cohorts),
        courseId: 6,
      );
      await tester.pumpAndSettle();

      expect(find.byType(CohortCard), findsNWidgets(2));
      final rendered = tester
          .widgetList<CohortCard>(find.byType(CohortCard))
          .map((card) => card.cohort.id)
          .toList();
      expect(rendered, [1, 3]);
    });

    testWidgets('shows every cohort when no course id is given', (
      tester,
    ) async {
      final cohorts = [
        sampleCohort(id: 1, courseId: 6),
        sampleCohort(id: 2, courseId: 9),
      ];
      await pumpList(tester, FakeCohortRepository(cohorts: cohorts));
      await tester.pumpAndSettle();

      expect(find.byType(CohortCard), findsNWidgets(2));
    });

    testWidgets('shows the empty state when no cohort matches the course id', (
      tester,
    ) async {
      await pumpList(
        tester,
        FakeCohortRepository(cohorts: [sampleCohort(id: 1, courseId: 9)]),
        courseId: 6,
      );
      await tester.pumpAndSettle();

      expect(find.text(CohortListStrings.empty), findsOneWidget);
      expect(find.byType(CohortCard), findsNothing);
    });

    testWidgets('enrollment still works on a course-filtered list', (
      tester,
    ) async {
      final enrollments = FakeEnrollmentRepository();
      await pumpList(
        tester,
        FakeCohortRepository(cohorts: [sampleCohort(id: 1, courseId: 6)]),
        enrollmentRepository: enrollments,
        courseId: 6,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(AppButton, EnrollmentStrings.enroll),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(AppButton, EnrollmentStrings.enroll),
        findsNothing,
      );
      expect(enrollments.requests, [1]);
    });
  });

  group('empty', () {
    testWidgets('shows the empty message when there are no cohorts', (
      tester,
    ) async {
      await pumpList(tester, FakeCohortRepository(cohorts: const []));
      await tester.pumpAndSettle();

      expect(find.text(CohortListStrings.empty), findsOneWidget);
      expect(find.byType(CohortCard), findsNothing);
      expect(
        find.widgetWithText(AppButton, CohortListStrings.retry),
        findsNothing,
      );
    });
  });

  group('error', () {
    testWidgets('shows the matching message for each failure kind', (
      tester,
    ) async {
      final repository = FakeCohortRepository(
        failure: const ApiFailure(ApiFailureKind.network),
      );
      await pumpList(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text(CohortListStrings.networkError), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, CohortListStrings.retry),
        findsOneWidget,
      );
      expect(find.byType(CohortCard), findsNothing);
    });

    testWidgets('retrying re-fetches and, on success, shows the list', (
      tester,
    ) async {
      final repository = FakeCohortRepository(
        failure: const ApiFailure(ApiFailureKind.server),
      );
      await pumpList(tester, repository);
      await tester.pumpAndSettle();
      expect(repository.callCount, 1);

      repository.failure = null;
      repository.cohorts = [sampleCohort()];

      await tester.tap(find.widgetWithText(AppButton, CohortListStrings.retry));
      await tester.pumpAndSettle();

      expect(repository.callCount, 2);
      expect(find.text(CohortListStrings.serverError), findsNothing);
      expect(find.byType(CohortCard), findsOneWidget);
    });
  });

  group('pull to refresh', () {
    testWidgets('a loaded list re-fetches on pull', (tester) async {
      final repository = FakeCohortRepository(cohorts: [sampleCohort()]);
      await pumpList(tester, repository);
      await tester.pumpAndSettle();
      expect(repository.callCount, 1);

      await tester.fling(
        find.byType(CohortCard).first,
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(repository.callCount, 2);
    });
  });

  group('enrollment', () {
    Finder enrollButton() =>
        find.widgetWithText(AppButton, EnrollmentStrings.enroll);

    testWidgets('every card offers the enroll action', (tester) async {
      await pumpList(
        tester,
        FakeCohortRepository(
          cohorts: [sampleCohort(id: 1), sampleCohort(id: 2)],
        ),
      );
      await tester.pumpAndSettle();

      expect(enrollButton(), findsNWidgets(2));
    });

    testWidgets(
      'tapping enroll shows the button loading, then the enrolled state',
      (tester) async {
        final enrollments = FakeEnrollmentRepository(hold: true);
        await pumpList(
          tester,
          FakeCohortRepository(cohorts: [sampleCohort(id: 4)]),
          enrollmentRepository: enrollments,
        );
        await tester.pumpAndSettle();

        await tester.tap(enrollButton());
        await tester.pump();

        expect(
          tester.widget<AppButton>(find.byType(AppButton)).loading,
          isTrue,
        );
        expect(
          find.descendant(
            of: find.byType(CohortCard),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        expect(enrollments.requests, [4]);

        enrollments.release();
        await tester.pumpAndSettle();

        // No button, and no "enrolled" row taking its place.
        expect(find.text(_enrolledLabel), findsNothing);
        expect(find.byType(AppButton), findsNothing);
      },
    );

    testWidgets(
      'a failure shows its message in red and leaves the button to retry',
      (tester) async {
        final enrollments = FakeEnrollmentRepository(
          failure: const EnrollmentFailure(EnrollmentFailureKind.rejected),
        );
        await pumpList(
          tester,
          FakeCohortRepository(cohorts: [sampleCohort(id: 1)]),
          enrollmentRepository: enrollments,
        );
        await tester.pumpAndSettle();

        await tester.tap(enrollButton());
        await tester.pumpAndSettle();

        expect(find.text(EnrollmentStrings.rejected), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.text(EnrollmentStrings.rejected))
              .style
              ?.color,
          AppColors.error,
        );
        expect(enrollButton(), findsOneWidget);

        enrollments.failure = null;
        await tester.tap(enrollButton());
        await tester.pumpAndSettle();

        expect(find.text(EnrollmentStrings.rejected), findsNothing);
        expect(enrollButton(), findsNothing);
        expect(enrollments.requests, [1, 1]);
      },
    );

    testWidgets('an expired session tells the student to sign in again', (
      tester,
    ) async {
      await pumpList(
        tester,
        FakeCohortRepository(cohorts: [sampleCohort()]),
        enrollmentRepository: FakeEnrollmentRepository(
          failure: const EnrollmentFailure(
            EnrollmentFailureKind.sessionExpired,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(enrollButton());
      await tester.pumpAndSettle();

      expect(find.text(EnrollmentStrings.sessionExpired), findsOneWidget);
    });

    testWidgets('only the tapped card changes', (tester) async {
      await pumpList(
        tester,
        FakeCohortRepository(
          cohorts: [sampleCohort(id: 1), sampleCohort(id: 2)],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(enrollButton().first);
      await tester.pumpAndSettle();

      expect(enrollButton(), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CohortCard).at(1),
          matching: enrollButton(),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the enrolled state survives a pull to refresh', (
      tester,
    ) async {
      final cohorts = FakeCohortRepository(cohorts: [sampleCohort()]);
      await pumpList(tester, cohorts);
      await tester.pumpAndSettle();

      await tester.tap(enrollButton());
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(CohortCard).first,
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(cohorts.callCount, 2);
      expect(enrollButton(), findsNothing);
    });
  });

  group('already enrolled, from the server', () {
    Finder enrollButton() =>
        find.widgetWithText(AppButton, EnrollmentStrings.enroll);

    testWidgets('shows the enrolled label for a cohort GET /me/cohorts named', (
      tester,
    ) async {
      await pumpList(
        tester,
        FakeCohortRepository(
          cohorts: [sampleCohort(id: 1), sampleCohort(id: 2)],
        ),
        enrolledCohortsRepository: FakeEnrolledCohortsRepository(
          enrolledCohortIds: {1},
        ),
      );
      await tester.pumpAndSettle();

      expect(enrollButton(), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CohortCard).first,
          matching: enrollButton(),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'does not send an enroll request for an already-enrolled cohort',
      (tester) async {
        final enrollments = FakeEnrollmentRepository();
        await pumpList(
          tester,
          FakeCohortRepository(cohorts: [sampleCohort(id: 1)]),
          enrollmentRepository: enrollments,
          enrolledCohortsRepository: FakeEnrolledCohortsRepository(
            enrolledCohortIds: {1},
          ),
        );
        await tester.pumpAndSettle();

        expect(enrollButton(), findsNothing);
        expect(enrollments.requests, isEmpty);
      },
    );

    testWidgets('a cohort not on the list still offers the enroll button', (
      tester,
    ) async {
      await pumpList(
        tester,
        FakeCohortRepository(cohorts: [sampleCohort(id: 5)]),
        enrolledCohortsRepository: FakeEnrolledCohortsRepository(
          enrolledCohortIds: {1},
        ),
      );
      await tester.pumpAndSettle();

      expect(enrollButton(), findsOneWidget);
      expect(find.text(_enrolledLabel), findsNothing);
    });

    testWidgets(
      'a fetch failure shows its message and defaults every cohort to '
      'not-yet-enrolled',
      (tester) async {
        await pumpList(
          tester,
          FakeCohortRepository(cohorts: [sampleCohort(id: 1)]),
          enrolledCohortsRepository: FakeEnrolledCohortsRepository(
            failure: const EnrollmentFailure(EnrollmentFailureKind.network),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(EnrollmentStrings.networkError), findsOneWidget);
        expect(enrollButton(), findsOneWidget);
      },
    );

    testWidgets('tapping the retry link re-fetches and clears the message', (
      tester,
    ) async {
      final enrolledCohorts = FakeEnrolledCohortsRepository(
        failure: const EnrollmentFailure(EnrollmentFailureKind.server),
      );
      await pumpList(
        tester,
        FakeCohortRepository(cohorts: [sampleCohort(id: 1)]),
        enrolledCohortsRepository: enrolledCohorts,
      );
      await tester.pumpAndSettle();
      expect(enrolledCohorts.callCount, 1);

      enrolledCohorts.failure = null;
      enrolledCohorts.enrolledCohortIds = {1};

      await tester.tap(find.text(CohortListStrings.retry));
      await tester.pumpAndSettle();

      expect(enrolledCohorts.callCount, 2);
      expect(find.text(EnrollmentStrings.serverError), findsNothing);
      expect(enrollButton(), findsNothing);
    });

    testWidgets(
      'a session-expired failure reads the same as elsewhere on screen',
      (tester) async {
        await pumpList(
          tester,
          FakeCohortRepository(cohorts: [sampleCohort()]),
          enrolledCohortsRepository: FakeEnrolledCohortsRepository(
            failure: const EnrollmentFailure(
              EnrollmentFailureKind.sessionExpired,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(EnrollmentStrings.sessionExpired), findsOneWidget);
      },
    );

    testWidgets('pull to refresh also re-fetches the enrolled cohorts', (
      tester,
    ) async {
      final cohorts = FakeCohortRepository(cohorts: [sampleCohort()]);
      final enrolledCohorts = FakeEnrolledCohortsRepository();
      await pumpList(
        tester,
        cohorts,
        enrolledCohortsRepository: enrolledCohorts,
      );
      await tester.pumpAndSettle();
      expect(enrolledCohorts.callCount, 1);

      await tester.fling(
        find.byType(CohortCard).first,
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(cohorts.callCount, 2);
      expect(enrolledCohorts.callCount, 2);
    });
  });

  group('the student\'s own cohorts', () {
    Finder enrollButton() =>
        find.widgetWithText(AppButton, EnrollmentStrings.enroll);

    /// Three cohorts in the public list, the student enrolled in the active
    /// and the finished one — `GET /me/cohorts` naming only their ids.
    Future<void> pumpMine(
      WidgetTester tester, {
      List<EnrolledCohortSummary>? enrolled,
      FakeEnrolledCohortsRepository? enrolledCohortsRepository,
      FakeCohortRepository? repository,
    }) => pumpList(
      tester,
      repository ??
          FakeCohortRepository(
            cohorts: [
              sampleCohort(id: 1, name: 'Cohort 01', status: 'active'),
              sampleCohort(id: 2, name: 'Cohort 02', status: 'open'),
              sampleCohort(id: 3, name: 'Cohort 03', status: 'finished'),
            ],
          ),
      enrolledCohortsRepository:
          enrolledCohortsRepository ??
          FakeEnrolledCohortsRepository(
            enrolledCohorts:
                enrolled ??
                const [
                  EnrolledCohortSummary(cohortId: 1),
                  EnrolledCohortSummary(cohortId: 3),
                ],
          ),
      enrolledOnly: true,
    );

    testWidgets('shows every cohort the student is enrolled in, active and '
        'finished, and leaves the rest out', (tester) async {
      await pumpMine(tester);
      await tester.pumpAndSettle();

      final rendered = tester
          .widgetList<CohortCard>(find.byType(CohortCard))
          .map((card) => card.cohort.id)
          .toList();
      expect(rendered, [1, 3]);
      expect(find.text('Cohort 01'), findsOneWidget);
      expect(find.text('Cohort 03'), findsOneWidget);
      expect(find.text('Cohort 02'), findsNothing);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Finished'), findsOneWidget);
    });

    testWidgets('shows the real programme name on each card', (tester) async {
      await pumpMine(
        tester,
        repository: FakeCohortRepository(
          cohorts: [
            sampleCohort(
              id: 1,
              course: const CohortCourse(
                id: 6,
                slug: 'ai-engineer',
                title: LocalizedText(en: 'AI Engineer', mn: 'AI инженер'),
              ),
            ),
          ],
        ),
        enrolled: const [EnrolledCohortSummary(cohortId: 1)],
      );
      await tester.pumpAndSettle();

      expect(find.text('AI инженер'), findsOneWidget);
    });

    testWidgets('draws each cohort\'s own progress from GET /me/cohorts', (
      tester,
    ) async {
      await pumpMine(
        tester,
        enrolled: const [
          EnrolledCohortSummary(cohortId: 1, progressPct: 40),
          EnrolledCohortSummary(cohortId: 3, progressPct: 100),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text(CohortListStrings.percentComplete(40)), findsOneWidget);
      expect(find.text(CohortListStrings.percentComplete(100)), findsOneWidget);

      final bars = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .map((bar) => bar.value)
          .toList();
      expect(bars, [0.4, 1.0]);
    });

    testWidgets('rounds a fractional progress and clamps it to 0-100', (
      tester,
    ) async {
      await pumpMine(
        tester,
        enrolled: const [
          EnrolledCohortSummary(cohortId: 1, progressPct: 66.6),
          EnrolledCohortSummary(cohortId: 3, progressPct: 140),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text(CohortListStrings.percentComplete(67)), findsOneWidget);
      expect(find.text(CohortListStrings.percentComplete(100)), findsOneWidget);
    });

    testWidgets(
      'an enrolled card with no progress is Figma\'s 148pt card, with no enrolled row',
      (tester) async {
        await pumpMine(
          tester,
          enrolled: const [EnrolledCohortSummary(cohortId: 1)],
        );
        await tester.pumpAndSettle();

        final card = find.byType(CohortCard);
        expect(card, findsOneWidget);
        expect(find.text(_enrolledLabel), findsNothing);
        expect(
          find.descendant(
            of: card,
            matching: find.byIcon(AppIcons.checkCircle),
          ),
          findsNothing,
        );
        // Figma's no-progress card: 361 Fill x 148 Hug.
        expect(tester.getSize(card), const Size(361, 148));
      },
    );

    testWidgets('a card with progress keeps its own, taller height', (
      tester,
    ) async {
      await pumpMine(
        tester,
        enrolled: const [EnrolledCohortSummary(cohortId: 1, progressPct: 40)],
      );
      await tester.pumpAndSettle();

      // Content-sized (badge row, caption, title, progress) — the 148 minimum
      // does not stretch it.
      final height = tester.getSize(find.byType(CohortCard)).height;
      expect(height, greaterThan(148));
      expect(height, closeTo(192, 1));
    });

    testWidgets('lays the card\'s parts out to Figma\'s measurements', (
      tester,
    ) async {
      await pumpMine(
        tester,
        repository: FakeCohortRepository(
          cohorts: [sampleCohort(id: 1, name: 'Cohort 01', status: 'finished')],
        ),
        enrolled: const [EnrolledCohortSummary(cohortId: 1)],
      );
      await tester.pumpAndSettle();

      final card = tester.getRect(find.byType(CohortCard));
      Rect inCard(Finder finder) => tester.getRect(finder).shift(-card.topLeft);
      Finder boxAround(String text) => find
          .ancestor(of: find.text(text), matching: find.byType(Container))
          .first;

      // 361 x 148, its content inset 16 either side: Figma's 329 Fill.
      expect(card.size, const Size(361, 148));

      // Adult badge 88.92 x 32, 24 below the top and 16 in from the edge; its
      // icon 19.92 square.
      final badge = inCard(boxAround('Adult'));
      expect(badge.size.height, 32);
      expect(badge.size.width, closeTo(88.92, 0.5));
      expect(badge.topLeft, const Offset(16, 24));
      final icon = inCard(find.byType(SvgPicture).at(1));
      expect(icon.size.width, closeTo(19.92, 0.01));
      expect(icon.size.height, closeTo(19.92, 0.01));

      // Status pill 83 x 24, right-aligned to the same 16 inset, centred on
      // the badge's row.
      final pill = inCard(boxAround('Finished'));
      expect(pill.size.height, 24);
      expect(pill.size.width, closeTo(83, 0.5));
      expect(pill.right, closeTo(345, 0.01));
      expect(pill.center.dy, badge.center.dy);
      expect(
        tester.widget<Text>(find.text('Finished')).style,
        isA<TextStyle>()
            .having((style) => style.fontSize, 'fontSize', 12)
            .having((style) => style.height, 'height', 16 / 12),
      );

      // Caption 18 high, 24 under the badge row; the title 26 high, flush
      // under it.
      final caption = inCard(find.text('Cohort 01'));
      final title = inCard(find.text('Зуны бүтээлч кэмп'));
      expect(caption.height, 18);
      expect(title.height, 26);
      expect(caption.top - badge.bottom, 24);
      expect(title.top, caption.bottom);
      expect(caption.left, 16);
      expect(title.left, 16);
    });

    testWidgets('a cohort with no progress figure draws no progress row', (
      tester,
    ) async {
      await pumpMine(
        tester,
        enrolled: const [
          EnrolledCohortSummary(cohortId: 1, progressPct: 25),
          EnrolledCohortSummary(cohortId: 3),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(CohortCard), findsNWidgets(2));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('% complete'), findsOneWidget);
    });

    testWidgets('offers no enroll action — every card is already enrolled', (
      tester,
    ) async {
      await pumpMine(tester);
      await tester.pumpAndSettle();

      expect(enrollButton(), findsNothing);
      // ...and no "enrolled" row where the button would have been.
      expect(find.text(_enrolledLabel), findsNothing);
    });

    testWidgets('the card\'s background pattern is faint but not faded out', (
      tester,
    ) async {
      await pumpMine(tester);
      await tester.pumpAndSettle();

      final opacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(CohortCard).first,
              matching: find.byType(Opacity),
            )
            .first,
      );
      // Stronger than Home's 0.5, still nowhere near solid.
      expect(opacity.opacity, greaterThan(0.5));
      expect(opacity.opacity, lessThanOrEqualTo(0.85));
    });

    testWidgets('the public list is unchanged: no progress, every cohort', (
      tester,
    ) async {
      await pumpList(
        tester,
        FakeCohortRepository(
          cohorts: [sampleCohort(id: 1), sampleCohort(id: 2)],
        ),
        enrolledCohortsRepository: FakeEnrolledCohortsRepository(
          enrolledCohorts: const [
            EnrolledCohortSummary(cohortId: 1, progressPct: 40),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CohortCard), findsNWidgets(2));
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('waits for both fetches before drawing anything', (
      tester,
    ) async {
      final enrolled = FakeEnrolledCohortsRepository(
        enrolledCohortIds: {1},
        hold: true,
      );
      await pumpMine(tester, enrolledCohortsRepository: enrolled);
      await tester.pump();

      // The cohorts alone have answered; showing them now would list every
      // cohort, not the student's.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(CohortCard), findsNothing);

      enrolled.release();
      await tester.pumpAndSettle();

      expect(find.byType(CohortCard), findsOneWidget);
    });

    testWidgets('shows the student-specific empty message when enrolled in '
        'nothing', (tester) async {
      await pumpMine(tester, enrolled: const []);
      await tester.pumpAndSettle();

      expect(find.text(CohortListStrings.emptyMine), findsOneWidget);
      expect(find.byType(CohortCard), findsNothing);
    });

    testWidgets('a failed GET /me/cohorts is an error with retry, not a '
        'list of every cohort', (tester) async {
      final enrolled = FakeEnrolledCohortsRepository(
        enrolledCohortIds: {1},
        failure: const EnrollmentFailure(EnrollmentFailureKind.network),
      );
      await pumpMine(tester, enrolledCohortsRepository: enrolled);
      await tester.pumpAndSettle();

      expect(
        find.text(EnrollmentStrings.messageFor(EnrollmentFailureKind.network)),
        findsOneWidget,
      );
      expect(find.byType(CohortCard), findsNothing);

      enrolled.failure = null;
      await tester.tap(find.text(CohortListStrings.retry));
      await tester.pumpAndSettle();

      expect(find.byType(CohortCard), findsOneWidget);
    });

    testWidgets('the courses tab is the current one and does nothing', (
      tester,
    ) async {
      await pumpMine(tester);
      await tester.pumpAndSettle();

      final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      expect(nav.currentIndex, 1);
      expect(nav.items[1].onTap, isNull);
    });
  });

  group('layout', () {
    testWidgets('stays within a phone-width column on a desktop window', (
      tester,
    ) async {
      await pumpList(
        tester,
        FakeCohortRepository(cohorts: [sampleCohort()]),
        size: const Size(1200, 900),
      );
      await tester.pumpAndSettle();

      final card = tester.getRect(find.byType(CohortCard));
      expect(card.width, lessThanOrEqualTo(480 - 32));
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow with several cohorts on a short viewport', (
      tester,
    ) async {
      await pumpList(
        tester,
        FakeCohortRepository(
          cohorts: List.generate(
            6,
            (i) => sampleCohort(id: i, name: 'Cohort $i'),
          ),
        ),
        size: const Size(393, 420),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(CohortCard), findsWidgets);

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
