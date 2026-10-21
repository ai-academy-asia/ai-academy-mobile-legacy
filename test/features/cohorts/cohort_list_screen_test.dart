import 'dart:convert';

import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:aia_mobile/core/theme/app_dimens.dart';
import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_typography.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/cohorts/data/http_cohort_repository.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_screen.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_strings.dart';
import 'package:aia_mobile/features/cohorts/presentation/widgets/cohort_card.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort_listing.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/enrollments/domain/enrolled_cohorts_repository.dart';
import 'package:aia_mobile/features/enrollments/domain/enrollment_failure.dart';
import 'package:aia_mobile/features/enrollments/presentation/enrollment_strings.dart';
import 'package:aia_mobile/shared/widgets/app_back_button.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:aia_mobile/shared/widgets/track_badge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  group('Course Catalog reference', () {
    /// The reference's own three cards, in its own order.
    Future<void> pumpCatalog(WidgetTester tester) async {
      await pumpList(
        tester,
        FakeCohortRepository(
          cohorts: [
            sampleCohort(id: 1, name: 'Cohort 01', status: 'finished'),
            sampleCohort(id: 2, name: 'Cohort 02', status: 'active'),
            sampleCohort(id: 3, name: 'Cohort 03', status: 'open'),
          ],
        ),
        enrolledCohortsRepository: FakeEnrolledCohortsRepository(
          enrolledCohortIds: const {1, 2, 3},
          enrolledCohorts: const [
            EnrolledCohortSummary(cohortId: 1),
            EnrolledCohortSummary(cohortId: 2, progressPct: 30),
            EnrolledCohortSummary(cohortId: 3),
          ],
        ),
        enrolledOnly: true,
        size: const Size(393, 854),
      );
      await tester.pumpAndSettle();
    }

    BoxDecoration pillDecoration(WidgetTester tester, String label) {
      final box = tester.widget<Container>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      return box.decoration! as BoxDecoration;
    }

    /// The pill's outline colour, which is also its text colour.
    Color pillColour(WidgetTester tester, String label) =>
        (pillDecoration(tester, label).border! as Border).top.color;

    /// The pill's fill, a flat colour sampled off the reference rather than the
    /// outline colour at an alpha.
    Color pillFill(WidgetTester tester, String label) =>
        pillDecoration(tester, label).color!;

    testWidgets('titles the screen "Courses" over three cards', (tester) async {
      await pumpCatalog(tester);

      expect(find.text('Courses'), findsOneWidget);
      expect(find.byType(CohortCard), findsNWidgets(3));
    });

    testWidgets('the page is a tab\'s grey and the cards carry the '
        'decoration', (tester) async {
      await pumpCatalog(tester);

      // A primary tab like Profile (Issue #368): the white title band over
      // the `surfaceSubtle` page.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.surfaceSubtle);

      // One abstract background per card: the family's [CardPattern]
      // (Issue #404), from the bundled asset.
      expect(find.byType(CardPattern), findsNWidgets(3));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              w.bytesLoader.toString().contains(CardPattern.asset),
        ),
        findsNWidgets(3),
      );
    });

    testWidgets('finished reads blue; active and open read green', (
      tester,
    ) async {
      await pumpCatalog(tester);

      // Not the obvious semantic mapping — this is what the frame draws. The
      // hues are the reference's own, sampled at 1:1: they are neither
      // [AppColors.blue] nor [AppColors.success], and the fills are flat
      // colours rather than the outline at a low alpha.
      expect(pillColour(tester, 'Finished'), const Color(0xFF0D99FF));
      expect(pillFill(tester, 'Finished'), const Color(0xFFE5F4FF));

      expect(pillColour(tester, 'Active'), const Color(0xFF14AE5C));
      expect(pillFill(tester, 'Active'), const Color(0xFFEBFFEE));

      expect(pillColour(tester, 'Open'), const Color(0xFF14AE5C));
      expect(pillFill(tester, 'Open'), const Color(0xFFEBFFEE));
    });

    testWidgets('only the card with reported progress shows the bar', (
      tester,
    ) async {
      await pumpCatalog(tester);

      expect(find.text(CohortListStrings.percentComplete(30)), findsOneWidget);
      // A cohort with no reported figure draws no progress row at all.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(0.30, 0.001),
      );
    });

    testWidgets('cards are 16 apart and span the 361pt content width', (
      tester,
    ) async {
      await pumpCatalog(tester);

      final rects = [
        for (var i = 0; i < 3; i++)
          tester.getRect(find.byType(CohortCard).at(i)),
      ];
      for (final rect in rects) {
        expect(rect.left, AppDimens.screenPadding);
        expect(rect.width, AppDimens.contentWidth);
      }
      expect(rects[1].top - rects[0].bottom, AppDimens.screenPadding);
      expect(rects[2].top - rects[1].bottom, AppDimens.screenPadding);
    });

    testWidgets('the Courses tab is the selected one', (tester) async {
      await pumpCatalog(tester);

      expect(
        tester.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex,
        1,
      );
    });

    testWidgets('the selected Courses tab draws its book filled blue', (
      tester,
    ) async {
      await pumpCatalog(tester);

      // The outline book's own glyph with its pages filled (Issue #237),
      // scaled with the bar's icon size and tinted with its selected colour.
      final nav = find.byType(AppBottomNav);
      final svg = tester.widget<SvgPicture>(
        find.descendant(of: nav, matching: find.byType(SvgPicture)),
      );
      expect(svg.bytesLoader.toString(), contains('nav_courses_active'));
      expect(
        svg.colorFilter,
        const ColorFilter.mode(Color(0xFF2970FF), BlendMode.srcIn),
      );
      expect(find.byIcon(AppIcons.bookOpenText), findsNothing);

      // The inactive tabs keep their outline glyphs.
      expect(find.byIcon(AppIcons.house), findsOneWidget);
      expect(find.byIcon(AppIcons.user), findsOneWidget);
    });

    testWidgets('the card outline and surface are the reference\'s own', (
      tester,
    ) async {
      await pumpCatalog(tester);

      // An outline warmer than the global [AppColors.border] (#E4E6EF), and
      // a white surface: the Course Catalog export's card is 37% pure white —
      // the blocks cut out of the pattern — and #F8FAFF only where the
      // pattern's own tint shades it (Issue #404; it was read as the
      // surface before).
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(CohortCard).first,
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect((decoration.border! as Border).top.color, const Color(0xFFD6DBE1));

      expect(
        tester
            .widget<Material>(
              find
                  .descendant(
                    of: find.byType(CohortCard).first,
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color,
        AppColors.surface,
      );
    });

    testWidgets('the progress bar is the reference\'s 8 tall, in its colours', (
      tester,
    ) async {
      await pumpCatalog(tester);

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      // 8, not the global [AppDimens.progressBarHeight] of 6 that other
      // screens rely on.
      expect(bar.minHeight, 8);
      expect(bar.backgroundColor, const Color(0xFFD6DBE1));
      expect(bar.valueColor!.value, const Color(0xFF2970FF));

      // Spans the card's full 329 inner width, so 30% inks 98.7 of it.
      expect(
        tester.getSize(find.byType(LinearProgressIndicator)).width,
        AppDimens.contentWidth - 2 * AppDimens.cardPadding,
      );
    });

    testWidgets('sits where the reference draws it, at a real device inset', (
      tester,
    ) async {
      // The reference frame is 393x854 with an iPhone's own insets, so this is
      // the only setup in which its absolute positions mean anything: at a
      // zero inset the whole column reads 59 high and the nav rule 34 low.
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(393, 854) * 3;
      tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CohortListScreen(
            enrolledOnly: true,
            repository: FakeCohortRepository(
              cohorts: [
                sampleCohort(id: 1, name: 'Cohort 01', status: 'finished'),
                sampleCohort(id: 2, name: 'Cohort 02', status: 'active'),
              ],
            ),
            enrollmentRepository: FakeEnrollmentRepository(),
            enrolledCohortsRepository: FakeEnrolledCohortsRepository(
              enrolledCohortIds: const {1, 2},
              enrolledCohorts: const [
                EnrolledCohortSummary(cohortId: 1),
                EnrolledCohortSummary(cohortId: 2, progressPct: 30),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The shared tab header (Issue #368): the title's 34 line centred in
      // the 63 band under the 59 inset, the rule under the band, and the
      // first card a tab's 16 below it.
      expect(tester.getTopLeft(find.text('Courses')).dy, 59 + (63 - 34) / 2);
      expect(
        tester.getTopLeft(find.byType(CohortCard).first).dy,
        59 + 63 + 1 + 16,
      );

      // The bar's own rule lands on the reference's y748: 854 less the 34
      // home-indicator inset and the bar's 72.
      expect(tester.getTopLeft(find.byType(AppBottomNav)).dy, 748);
    });

    testWidgets('the heading is the shared screen title, 26 over a 34 line', (
      tester,
    ) async {
      await pumpCatalog(tester);

      // Every top-level screen's heading is [AppTypography.screenTitle]
      // (Issue #366); its 34 line keeps the heading's top edge where it was.
      final style = tester.widget<Text>(find.text('Courses')).style!;
      expect(style.fontSize, AppTypography.screenTitle.fontSize);
      expect(style.fontSize, 26);
      expect(style.fontSize! * style.height!, 34);
    });
  });

  group('header', () {
    testWidgets('is the title alone — no back arrow on a top-level screen', (
      tester,
    ) async {
      await pumpList(tester, FakeCohortRepository(cohorts: [sampleCohort()]));
      await tester.pumpAndSettle();

      expect(find.text(CohortListStrings.heading), findsOneWidget);
      expect(find.byType(AppBackButton), findsNothing);
    });

    testWidgets('leaves 16 between the header rule and the first card', (
      tester,
    ) async {
      await pumpList(tester, FakeCohortRepository(cohorts: [sampleCohort()]));
      await tester.pumpAndSettle();

      // The rule is a lighter grey than the global [AppColors.border], sampled
      // off the reference at 1:1.
      final rule = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.color == const Color(0xFFEAEDF0) &&
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

  group('course module list navigation', () {
    testWidgets('tapping a card opens Module List directly, with the resolved '
        'catalog slug, not the cohort\'s own stale one', (tester) async {
      // The Figma flow has no Course Detail step between a cohort card
      // and Module List. Also reproduces the real, confirmed drift
      // `resolveCohortCourse`'s own doc comment describes: `sampleCohort()`
      // 's embedded course (id 6, slug "summer-bootcamp-2027") shares its
      // title with `sampleCourse()`'s catalog entry (id 4, slug
      // "summer-bootcamp").
      await pumpList(
        tester,
        FakeCohortRepository(cohorts: [sampleCohort()]),
        courseRepository: FakeCourseRepository(courses: [sampleCourse()]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(sampleCohort().name));
      await tester.pumpAndSettle();

      final moduleList = tester.widget<CourseModuleListScreen>(
        find.byType(CourseModuleListScreen),
      );
      expect(moduleList.courseSlug, 'summer-bootcamp');
    });

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

        final moduleList = tester.widget<CourseModuleListScreen>(
          find.byType(CourseModuleListScreen),
        );
        expect(moduleList.courseSlug, 'summer-bootcamp-2027');
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

    // Issue #445: a malformed row is left out; the valid ones still draw.
    testWidgets('a malformed cohort is left out, and the valid rows render', (
      tester,
    ) async {
      await pumpList(
        tester,
        FakeCohortRepository(
          cohorts: [
            sampleCohort(id: 1, name: 'A'),
            sampleCohort(id: 3, name: 'C'),
          ],
          skipped: const [
            SkippedCohort(
              id: 2,
              reason: 'cohort.teacher: expected an object, got String',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final rendered = tester
          .widgetList<CohortCard>(find.byType(CohortCard))
          .map((card) => card.cohort.id)
          .toList();
      expect(rendered, [1, 3]);
      expect(find.text(CohortListStrings.serverError), findsNothing);
    });

    testWidgets('every row malformed shows the server error, never the empty '
        'message', (tester) async {
      await pumpList(
        tester,
        FakeCohortRepository(
          skipped: const [SkippedCohort(id: 2, reason: 'cohort.teacher')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CohortCard), findsNothing);
      expect(find.text(CohortListStrings.serverError), findsOneWidget);
      expect(find.text(CohortListStrings.empty), findsNothing);
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

    // Issue #445: `GET /cohorts` reads row by row. A malformed row that may
    // be one of the student's own cohorts fails closed; an unrelated one is
    // simply not listed.
    group('a malformed cohort row', () {
      const unreadableTeacher =
          'cohort.teacher: expected an object, got String';

      testWidgets('the student\'s own cohort malformed shows the server error '
          'with retry, never "not enrolled"', (tester) async {
        await pumpMine(
          tester,
          enrolled: const [EnrolledCohortSummary(cohortId: 3)],
          repository: FakeCohortRepository(
            cohorts: [sampleCohort(id: 1, name: 'Cohort 01')],
            skipped: const [SkippedCohort(id: 3, reason: unreadableTeacher)],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(CohortListStrings.serverError), findsOneWidget);
        expect(find.text(CohortListStrings.retry), findsOneWidget);
        expect(find.text(CohortListStrings.emptyMine), findsNothing);
        expect(find.byType(CohortCard), findsNothing);
      });

      testWidgets('an unrelated malformed cohort does not hide the student\'s '
          'cards', (tester) async {
        await pumpMine(
          tester,
          repository: FakeCohortRepository(
            cohorts: [
              sampleCohort(id: 1, name: 'Cohort 01', status: 'active'),
              sampleCohort(id: 3, name: 'Cohort 03', status: 'finished'),
            ],
            skipped: const [SkippedCohort(id: 2, reason: unreadableTeacher)],
          ),
        );
        await tester.pumpAndSettle();

        final rendered = tester
            .widgetList<CohortCard>(find.byType(CohortCard))
            .map((card) => card.cohort.id)
            .toList();
        expect(rendered, [1, 3]);
        expect(find.text(CohortListStrings.serverError), findsNothing);
      });

      testWidgets('one of two enrolled cohorts malformed fails closed rather '
          'than showing the other alone', (tester) async {
        await pumpMine(
          tester,
          repository: FakeCohortRepository(
            cohorts: [sampleCohort(id: 1, name: 'Cohort 01', status: 'active')],
            skipped: const [SkippedCohort(id: 3, reason: unreadableTeacher)],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(CohortListStrings.serverError), findsOneWidget);
        expect(find.byType(CohortCard), findsNothing);
        expect(find.text('Cohort 01'), findsNothing);
      });

      testWidgets('a row with an unreadable id fails closed while one of the '
          'student\'s cohorts is not among the valid rows', (tester) async {
        await pumpMine(
          tester,
          repository: FakeCohortRepository(
            cohorts: [sampleCohort(id: 1, name: 'Cohort 01', status: 'active')],
            skipped: const [SkippedCohort(id: null, reason: 'cohort.id')],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(CohortListStrings.serverError), findsOneWidget);
        expect(find.byType(CohortCard), findsNothing);
      });

      testWidgets('retry after the row is fixed shows the student\'s cards', (
        tester,
      ) async {
        final repository = FakeCohortRepository(
          cohorts: [sampleCohort(id: 1, name: 'Cohort 01', status: 'active')],
          skipped: const [SkippedCohort(id: 3, reason: unreadableTeacher)],
        );
        await pumpMine(tester, repository: repository);
        await tester.pumpAndSettle();
        expect(find.text(CohortListStrings.serverError), findsOneWidget);

        repository
          ..cohorts = [
            sampleCohort(id: 1, name: 'Cohort 01', status: 'active'),
            sampleCohort(id: 3, name: 'Cohort 03', status: 'finished'),
          ]
          ..skipped = const [];
        await tester.tap(find.text(CohortListStrings.retry));
        await tester.pumpAndSettle();

        expect(find.text(CohortListStrings.serverError), findsNothing);
        expect(find.byType(CohortCard), findsNWidgets(2));
      });
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
        // Figma's no-progress card, 361 Fill x 148 Hug — 150 since the
        // course name's line is [AppTypography.cardTitle]'s 28 (Issue #366).
        expect(tester.getSize(card), const Size(361, 150));
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
      //
      // The reference's progress card is 208. The 14 difference is the
      // "Modules 2 of 5 complete" line it draws above the percentage, which
      // needs a module count no endpoint reports — `EnrolledCohortSummary`
      // carries only `{cohortId, progressPct}`. The line is left out rather
      // than filled with a guess, so the card is correspondingly shorter.
      final height = tester.getSize(find.byType(CohortCard)).height;
      // 198 since Issue #366: the title's 28 line and the 20 of
      // [AppTypography.supporting] under the bar each add 2.
      expect(height, greaterThan(150));
      expect(height, closeTo(198, 1));
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

      // 361 x 150 (148 before Issue #366's 28 title line), its content inset
      // 16 either side: Figma's 329 Fill.
      expect(card.size, const Size(361, 150));

      // The Adult badge, 32 tall, 24 below the top and 16 in from the edge.
      // Since Issue #404 it is the shared [TrackBadge] every card in the
      // family draws — 86.85 wide with a 20 icon, the Home reference's
      // measure — not this frame's own 88.92 with a 19.92 icon: the two
      // exports disagree by 2pt, and one badge now draws everywhere.
      final badge = inCard(find.byType(TrackBadge));
      expect(badge, inCard(boxAround('Adult')));
      expect(badge.size.height, 32);
      expect(badge.size.width, closeTo(86.85, 0.5));
      expect(badge.topLeft, const Offset(16, 24));
      final icon = inCard(find.byType(SvgPicture).at(1));
      expect(icon.size, const Size(20, 20));

      // Status pill 87.2 x 24, right-aligned to the same 16 inset, hung from
      // the badge's top — the export draws both from y 148 (Issue #404).
      final pill = inCard(boxAround('Finished'));
      expect(pill.size.height, 24);
      // 87.2, Figma's 83 with the label at [AppTypography.badge]'s 13
      // rather than 12 (Issue #366).
      expect(pill.size.width, closeTo(87.2, 0.5));
      expect(pill.right, closeTo(345, 0.01));
      expect(pill.top, badge.top);
      expect(
        tester.widget<Text>(find.text('Finished')).style,
        isA<TextStyle>()
            .having((style) => style.fontSize, 'fontSize', 13)
            .having((style) => style.height, 'height', 16 / 13),
      );

      // Caption 18 high, 24 under the badge row; the title 28 high
      // ([AppTypography.cardTitle]), flush under it.
      final caption = inCard(find.text('Cohort 01'));
      final title = inCard(find.text('Зуны бүтээлч кэмп'));
      expect(caption.height, 18);
      expect(title.height, 28);
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

    testWidgets('the card\'s background pattern is the family\'s, at full '
        'strength', (tester) async {
      await pumpMine(tester);
      await tester.pumpAndSettle();

      // The Course Catalog export is pixel-identical to Home's and the
      // E-Contract's there: the one artwork at 1:1 from the top-left, at
      // full strength — the asset is already a 12% tint (Issue #404).
      final card = find.byType(CohortCard).first;
      expect(
        find.descendant(of: card, matching: find.byType(CardPattern)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.byType(Opacity)),
        findsNothing,
      );
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

      // The shared adult bar, unmodified — the geometry is the same on every
      // adult tab screen (Issue #188).
      const shared = AppBottomNav(items: [], currentIndex: 0);
      expect(nav.iconSize, shared.iconSize);
      expect(nav.labelSize, shared.labelSize);
      expect(nav.horizontalPadding, shared.horizontalPadding);
      expect(nav.selectedColor, shared.selectedColor);
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

  // Issue #493: a cohort with no teacher (`teacher: null` — none assigned,
  // or the teacher was deleted) is a normal cohort, read by the real parser.
  group('a cohort with no teacher (Issue #493)', () {
    Map<String, dynamic> row(
      int id, {
      Object? teacher = const {'id': 2, 'name': 'T'},
    }) => {
      'id': id,
      'name': 'Cohort 0$id',
      'course_id': 6,
      'course': {
        'id': 6,
        'slug': 'ai-basics',
        'title_en': 'AI Basics',
        'title_mn': 'AI Үндэс',
      },
      'classroom': null,
      'teacher': teacher,
      'capacity': 20,
      'enrolled_count': 1,
      'seats_available': 19,
      'status': 'open',
      'start_date': '2026-08-06',
      'end_date': '2026-10-06',
      'start_time': '18:00',
      'end_time': '20:00',
      'graduation_date': null,
      'meeting_days': ['mon', 'wed'],
      'parent_cohort_id': null,
      'schedule_note': null,
    };

    Future<void> pumpReal(
      WidgetTester tester,
      List<Object?> rows, {
      bool enrolledOnly = false,
      List<int> enrolled = const [],
    }) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(393, 852) * 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CohortListScreen(
            repository: HttpCohortRepository(
              client: MockClient(
                (_) async => http.Response(
                  jsonEncode({'cohorts': rows}),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                ),
              ),
            ),
            courseRepository: FakeCourseRepository(),
            enrollmentRepository: FakeEnrollmentRepository(),
            enrolledCohortsRepository: FakeEnrolledCohortsRepository(
              enrolledCohorts: [
                for (final id in enrolled) EnrolledCohortSummary(cohortId: id),
              ],
            ),
            enrolledOnly: enrolledOnly,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    List<int> rendered(WidgetTester tester) => tester
        .widgetList<CohortCard>(find.byType(CohortCard))
        .map((card) => card.cohort.id)
        .toList();

    testWidgets('Progress tab: the student\'s own teacherless cohort is drawn, '
        'not the server error', (tester) async {
      await pumpReal(
        tester,
        [row(1), row(2, teacher: null)],
        enrolledOnly: true,
        enrolled: const [2],
      );

      expect(rendered(tester), [2]);
      expect(find.text('Cohort 02'), findsOneWidget);
      expect(find.text(CohortListStrings.serverError), findsNothing);
      expect(find.text(CohortListStrings.emptyMine), findsNothing);
    });

    testWidgets('browse list: a teacherless cohort is listed with the others', (
      tester,
    ) async {
      await pumpReal(tester, [row(1), row(2, teacher: null), row(3)]);

      expect(rendered(tester), [1, 2, 3]);
      expect(find.text(CohortListStrings.serverError), findsNothing);
    });

    testWidgets('a malformed teacher still fails the student\'s own cohort '
        'closed', (tester) async {
      await pumpReal(
        tester,
        [row(1), row(2, teacher: 'Bat')],
        enrolledOnly: true,
        enrolled: const [2],
      );

      expect(find.text(CohortListStrings.serverError), findsOneWidget);
      expect(find.byType(CohortCard), findsNothing);
    });
  });
}
