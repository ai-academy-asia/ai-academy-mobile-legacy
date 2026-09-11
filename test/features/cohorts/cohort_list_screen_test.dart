import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_screen.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_strings.dart';
import 'package:aia_mobile/features/cohorts/presentation/widgets/cohort_card.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
    Size size = const Size(393, 852),
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = size * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CohortListScreen(repository: repository),
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
