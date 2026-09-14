import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_screen.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_strings.dart';
import 'package:aia_mobile/features/cohorts/presentation/widgets/cohort_card.dart';
import 'package:aia_mobile/features/enrollments/domain/enrollment_failure.dart';
import 'package:aia_mobile/features/enrollments/presentation/enrollment_strings.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  setUpAll(_loadFonts);

  Future<void> pumpList(
    WidgetTester tester,
    FakeCohortRepository repository, {
    FakeEnrollmentRepository? enrollmentRepository,
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
          // Always a fake: the default would reach for the app-wide session
          // and the real API.
          enrollmentRepository: enrollmentRepository ?? FakeEnrollmentRepository(),
        ),
      ),
    );
  }

  group('loading', () {
    testWidgets('shows a spinner while the first fetch is in flight', (tester) async {
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
    testWidgets('renders one card per cohort, in the order returned', (tester) async {
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
      expect(find.text('open'), findsOneWidget);
      expect(find.text('Зуны бүтээлч кэмп'), findsOneWidget);
      expect(find.text('AI Academy Central · Room 301'), findsOneWidget);
      expect(find.text('Сараа Ганбат'), findsOneWidget);
      expect(find.textContaining('mon, wed'), findsOneWidget);
      expect(find.textContaining('2026-08-06'), findsOneWidget);
      expect(find.textContaining('18:00'), findsOneWidget);
      expect(
        find.textContaining('20 ${CohortListStrings.seatsAvailableUnit}'),
        findsOneWidget,
      );
    });
  });

  group('empty', () {
    testWidgets('shows the empty message when there are no cohorts', (tester) async {
      await pumpList(tester, FakeCohortRepository(cohorts: const []));
      await tester.pumpAndSettle();

      expect(find.text(CohortListStrings.empty), findsOneWidget);
      expect(find.byType(CohortCard), findsNothing);
      expect(find.widgetWithText(AppButton, CohortListStrings.retry), findsNothing);
    });
  });

  group('error', () {
    testWidgets('shows the matching message for each failure kind', (tester) async {
      final repository = FakeCohortRepository(
        failure: const ApiFailure(ApiFailureKind.network),
      );
      await pumpList(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text(CohortListStrings.networkError), findsOneWidget);
      expect(find.widgetWithText(AppButton, CohortListStrings.retry), findsOneWidget);
      expect(find.byType(CohortCard), findsNothing);
    });

    testWidgets('retrying re-fetches and, on success, shows the list', (tester) async {
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

      await tester.fling(find.byType(CohortCard).first, const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(repository.callCount, 2);
    });
  });

  group('enrollment', () {
    Finder enrollButton() => find.widgetWithText(AppButton, EnrollmentStrings.enroll);

    testWidgets('every card offers the enroll action', (tester) async {
      await pumpList(
        tester,
        FakeCohortRepository(cohorts: [sampleCohort(id: 1), sampleCohort(id: 2)]),
      );
      await tester.pumpAndSettle();

      expect(enrollButton(), findsNWidgets(2));
    });

    testWidgets('tapping enroll shows the button loading, then the enrolled state', (
      tester,
    ) async {
      final enrollments = FakeEnrollmentRepository(hold: true);
      await pumpList(
        tester,
        FakeCohortRepository(cohorts: [sampleCohort(id: 4)]),
        enrollmentRepository: enrollments,
      );
      await tester.pumpAndSettle();

      await tester.tap(enrollButton());
      await tester.pump();

      expect(tester.widget<AppButton>(find.byType(AppButton)).loading, isTrue);
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

      expect(find.text(EnrollmentStrings.enrolled), findsOneWidget);
      expect(find.byType(AppButton), findsNothing);
    });

    testWidgets('a failure shows its message in red and leaves the button to retry', (
      tester,
    ) async {
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
        tester.widget<Text>(find.text(EnrollmentStrings.rejected)).style?.color,
        AppColors.error,
      );
      expect(enrollButton(), findsOneWidget);

      enrollments.failure = null;
      await tester.tap(enrollButton());
      await tester.pumpAndSettle();

      expect(find.text(EnrollmentStrings.rejected), findsNothing);
      expect(find.text(EnrollmentStrings.enrolled), findsOneWidget);
      expect(enrollments.requests, [1, 1]);
    });

    testWidgets('an expired session tells the student to sign in again', (tester) async {
      await pumpList(
        tester,
        FakeCohortRepository(cohorts: [sampleCohort()]),
        enrollmentRepository: FakeEnrollmentRepository(
          failure: const EnrollmentFailure(EnrollmentFailureKind.sessionExpired),
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
        FakeCohortRepository(cohorts: [sampleCohort(id: 1), sampleCohort(id: 2)]),
      );
      await tester.pumpAndSettle();

      await tester.tap(enrollButton().first);
      await tester.pumpAndSettle();

      expect(find.text(EnrollmentStrings.enrolled), findsOneWidget);
      expect(
        find.descendant(of: find.byType(CohortCard).at(1), matching: enrollButton()),
        findsOneWidget,
      );
    });

    testWidgets('the enrolled state survives a pull to refresh', (tester) async {
      final cohorts = FakeCohortRepository(cohorts: [sampleCohort()]);
      await pumpList(tester, cohorts);
      await tester.pumpAndSettle();

      await tester.tap(enrollButton());
      await tester.pumpAndSettle();

      await tester.fling(find.byType(CohortCard).first, const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(cohorts.callCount, 2);
      expect(find.text(EnrollmentStrings.enrolled), findsOneWidget);
      expect(enrollButton(), findsNothing);
    });
  });

  group('layout', () {
    testWidgets('stays within a phone-width column on a desktop window', (tester) async {
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
          cohorts: List.generate(6, (i) => sampleCohort(id: i, name: 'Cohort $i')),
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
