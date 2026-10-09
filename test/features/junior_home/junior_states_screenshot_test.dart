import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/domain/home_failure.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_junior_home_repository.dart';
import 'fake_junior_progress_repository.dart';

/// Junior states no reference-frame golden draws, captured ahead of the
/// Dark Mode Phase 7 colour migration (Issue #272) so it can be proved
/// pixel-identical there too. Each was captured from the code *before* the
/// migration, then held unchanged through it:
///
///  * Junior Home loading — the white spinner on the map's sky field;
///  * Junior Home failure — the message and retry on the sky;
///  * Junior Learning Progress loading — the blue spinner on the page grey;
///  * Junior Learning Progress failure — the message and retry;
///  * an overdue payment — the card's status line in the overdue red, which
///    the reference frame (due in 3 days) does not draw.
///
/// Requests are held with the fakes' own gates; no sleeps or real timers.
const Duration _spinnerFrame = Duration(milliseconds: 300);

void main() {
  setUpAll(loadAppFonts);

  Future<void> shot(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../goldens/junior_state_$name.png'),
  );

  Widget app(Widget home) => MaterialApp(
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    home: home,
  );

  group('Junior Home', () {
    testWidgets('loading', (tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      useReducedMotion(tester);
      final repository = FakeJuniorHomeRepository(hold: true);
      await tester.pumpWidget(app(JuniorHomeScreen(repository: repository)));
      await tester.pump(_spinnerFrame);
      await shot(tester, 'home_loading');
      repository.release();
      await tester.pumpAndSettle();
    });

    testWidgets('failure', (tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      useReducedMotion(tester);
      await tester.pumpWidget(
        app(
          JuniorHomeScreen(
            repository: FakeJuniorHomeRepository(
              failure: const CourseLearningFailure(
                CourseLearningFailureKind.network,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await shot(tester, 'home_failure');
    });
  });

  group('Junior Learning Progress', () {
    testWidgets('loading', (tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      final repository = FakeJuniorProgressRepository(hold: true);
      await tester.pumpWidget(
        app(JuniorProgressScreen(repository: repository)),
      );
      await tester.pump(_spinnerFrame);
      await shot(tester, 'progress_loading');
      repository.release();
      await tester.pumpAndSettle();
    });

    testWidgets('failure', (tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      await tester.pumpWidget(
        app(
          JuniorProgressScreen(
            repository: FakeJuniorProgressRepository(
              failure: const HomeFailure(HomeFailureKind.network),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await shot(tester, 'progress_failure');
    });

    testWidgets('overdue payment', (tester) async {
      useLogicalViewport(tester, const Size(393, 1350), padding: iPhonePadding);
      await tester.pumpWidget(
        app(
          JuniorProgressScreen(
            repository: FakeJuniorProgressRepository(
              progress: figmaReferenceProgress(
                payment: const PaymentStatus.overdue(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await shot(tester, 'progress_payment_overdue');
    });
  });
}
