import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/courses/domain/course.dart';
import 'package:aia_mobile/features/courses/presentation/course_catalog_screen.dart';
import 'package:aia_mobile/features/courses/presentation/course_catalog_strings.dart';
import 'package:aia_mobile/features/courses/presentation/widgets/course_card.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_course_repository.dart';

/// Loads the real Manrope face, the same reason the login and reset-password
/// screen tests do — without it, card text is measured in the fallback font,
/// which is the wrong typeface to be asserting layout against.
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

  Future<void> pumpCatalog(
    WidgetTester tester,
    FakeCourseRepository repository, {
    Size size = const Size(393, 852),
    Map<String, WidgetBuilder> routes = const {},
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = size * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CourseCatalogScreen(repository: repository),
        routes: routes,
      ),
    );
  }

  group('navigation', () {
    testWidgets('tapping a course opens the cohort list route', (tester) async {
      await pumpCatalog(
        tester,
        FakeCourseRepository(courses: [sampleCourse(bannerImageUrl: null)]),
        // A stand-in for `/cohorts`: the real screen would reach for the API.
        routes: {'/cohorts': (_) => const Scaffold(body: Text('cohort list route'))},
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CourseCard));
      await tester.pumpAndSettle();

      expect(find.text('cohort list route'), findsOneWidget);
    });

    testWidgets('tapping a course passes its id as the route arguments', (tester) async {
      Object? capturedArguments;
      await pumpCatalog(
        tester,
        FakeCourseRepository(courses: [sampleCourse(id: 7, bannerImageUrl: null)]),
        routes: {
          '/cohorts': (context) {
            capturedArguments = ModalRoute.of(context)!.settings.arguments;
            return const Scaffold(body: Text('cohort list route'));
          },
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CourseCard));
      await tester.pumpAndSettle();

      expect(capturedArguments, 7);
    });
  });

  group('loading', () {
    testWidgets('shows a spinner while the first fetch is in flight', (
      tester,
    ) async {
      final repository = FakeCourseRepository(hold: true);
      await pumpCatalog(tester, repository);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(CourseCard), findsNothing);
      expect(find.text(CourseCatalogStrings.empty), findsNothing);

      repository.release();
      await tester.pumpAndSettle();
    });

    testWidgets('still shows the heading while loading', (tester) async {
      final repository = FakeCourseRepository(hold: true);
      await pumpCatalog(tester, repository);
      await tester.pump();

      expect(find.text(CourseCatalogStrings.heading), findsOneWidget);

      repository.release();
      await tester.pumpAndSettle();
    });
  });

  group('loaded', () {
    testWidgets('renders one card per course, in the order returned', (
      tester,
    ) async {
      final courses = [
        sampleCourse(id: 1, slug: 'a'),
        sampleCourse(id: 2, slug: 'b'),
        sampleCourse(id: 3, slug: 'c'),
      ];
      await pumpCatalog(tester, FakeCourseRepository(courses: courses));
      await tester.pumpAndSettle();

      expect(find.byType(CourseCard), findsNWidgets(3));
      final rendered = tester
          .widgetList<CourseCard>(find.byType(CourseCard))
          .map((card) => card.course.id)
          .toList();
      expect(rendered, [1, 2, 3]);
    });

    testWidgets('shows the confirmed fields of a course', (tester) async {
      final course = sampleCourse();
      await pumpCatalog(tester, FakeCourseRepository(courses: [course]));
      await tester.pumpAndSettle();

      expect(find.text('Зуны бүтээлч кэмп'), findsOneWidget);
      expect(find.text('3 долоо хоногийн эрчимжүүлсэн'), findsOneWidget);
      expect(find.text('Junior'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Junior · 10-18 ${CourseCatalogStrings.ageUnit}'), findsOneWidget);
      expect(
        find.text(
          '${CourseCatalogStrings.dateRange('2026-06-01', '2026-06-21')} (3 ${CourseCatalogStrings.weeksUnit})',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('960,000'), findsOneWidget);
    });

    testWidgets(
      'falls back to a computed duration when duration_label is null',
      (tester) async {
        final course = sampleCourse(durationWeeks: 6, durationLabel: null);
        await pumpCatalog(tester, FakeCourseRepository(courses: [course]));
        await tester.pumpAndSettle();

        expect(
          find.text(
            '${CourseCatalogStrings.dateRange('2026-06-01', '2026-06-21')} (6 ${CourseCatalogStrings.weeksUnit})',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('prefers duration_label when the API sends one', (
      tester,
    ) async {
      final course = sampleCourse(durationWeeks: 6, durationLabel: null);
      await pumpCatalog(tester, FakeCourseRepository(courses: [course]));
      await tester.pumpAndSettle();

      expect(find.textContaining('6 ${CourseCatalogStrings.weeksUnit}'), findsOneWidget);
    });

    testWidgets('prefers duration_label when the API sends one', (tester) async {
      final course = sampleCourse(durationWeeks: 6, durationLabel: '1.5 сар');
      await pumpCatalog(tester, FakeCourseRepository(courses: [course]));
      await tester.pumpAndSettle();

      expect(find.textContaining('1.5 сар'), findsOneWidget);
      expect(find.textContaining('6 ${CourseCatalogStrings.weeksUnit}'), findsNothing);
    });

    testWidgets(
      'shows the struck-through original price only when discounted',
      (tester) async {
        final discounted = sampleCourse(
          id: 1,
          priceAmount: 1200000,
          finalPriceAmount: 960000,
          discountPercent: 20,
        );
        final fullPrice = sampleCourse(
          id: 2,
          priceAmount: 500000,
          finalPriceAmount: 500000,
          discountPercent: 0,
        );
        await pumpCatalog(
          tester,
          FakeCourseRepository(courses: [discounted, fullPrice]),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('1,200,000'), findsOneWidget);
        expect(find.textContaining('-20%'), findsOneWidget);
        expect(find.textContaining('960,000'), findsOneWidget);
        expect(find.textContaining('500,000'), findsOneWidget);
      },
    );

    testWidgets('shows a target_audience line only when the API sends one', (
      tester,
    ) async {
      final withAudience = sampleCourse(
        id: 1,
        targetAudience: 'Coding beginners',
      );
      final without = sampleCourse(id: 2, targetAudience: null);
      await pumpCatalog(
        tester,
        FakeCourseRepository(courses: [withAudience, without]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Coding beginners'), findsOneWidget);
    });

    testWidgets('renders no image when banner_image_url is null', (
      tester,
    ) async {
      await pumpCatalog(
        tester,
        FakeCourseRepository(courses: [sampleCourse(bannerImageUrl: null)]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
    });

    testWidgets('reaches for the network when banner_image_url is present', (
      tester,
    ) async {
      await pumpCatalog(
        tester,
        FakeCourseRepository(
          courses: [
            sampleCourse(bannerImageUrl: 'https://example.test/banner.png'),
          ],
        ),
      );
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<NetworkImage>());
      expect(
        (image.image as NetworkImage).url,
        'https://example.test/banner.png',
      );
    });
  });

  // Issue #485: a listed course may send `null` for any of these; the card
  // leaves the absent part out — never "null", an empty line, or a guess.
  group('absent optional fields (Issue #485)', () {
    Course bare({int id = 2}) => sampleCourse(
      id: id,
      level: null,
      format: null,
      ageMin: null,
      ageMax: null,
      durationWeeks: null,
      startDate: null,
      endDate: null,
      priceAmount: null,
      finalPriceAmount: null,
      discountPercent: null,
      currency: null,
    );

    Finder emptyText() =>
        find.byWidgetPredicate((w) => w is Text && (w.data ?? '').trim().isEmpty);

    testWidgets('a course with none of them draws its title and status only, '
        'beside full courses', (tester) async {
      await pumpCatalog(
        tester,
        FakeCourseRepository(courses: [sampleCourse(id: 1), bare(), sampleCourse(id: 3)]),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widgetList<CourseCard>(find.byType(CourseCard)).map((c) => c.course.id),
        [1, 2, 3],
      );
      final card = find.byWidgetPredicate((w) => w is CourseCard && w.course.id == 2);
      Finder inCard(Finder f) => find.descendant(of: card, matching: f);

      expect(inCard(find.text('Зуны бүтээлч кэмп')), findsOneWidget);
      expect(inCard(find.text('Open')), findsOneWidget);
      expect(inCard(find.text('Junior')), findsNothing);
      expect(inCard(find.text(CourseCatalogStrings.whoIsItFor)), findsNothing);
      expect(inCard(find.text(CourseCatalogStrings.durationSectionLabel)), findsNothing);
      expect(inCard(find.textContaining('MNT')), findsNothing);
      expect(inCard(find.textContaining(CourseCatalogStrings.ageUnit)), findsNothing);
      expect(inCard(find.textContaining('2026')), findsNothing);
      expect(inCard(find.textContaining(',000')), findsNothing);
      expect(inCard(emptyText()), findsNothing);
      expect(find.textContaining('null'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('each section is composed from the parts that are sent', (
      tester,
    ) async {
      await pumpCatalog(
        tester,
        FakeCourseRepository(
          courses: [
            // No level: the age alone; no dates: the length alone.
            sampleCourse(id: 1, level: null, startDate: null),
            // No age: the level alone; no length: the dates alone.
            sampleCourse(id: 2, ageMin: null, durationWeeks: null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('10-18 ${CourseCatalogStrings.ageUnit}'), findsOneWidget);
      expect(find.text('3 ${CourseCatalogStrings.weeksUnit}'), findsOneWidget);
      expect(find.text('Junior'), findsNWidgets(2));
      expect(
        find.text(CourseCatalogStrings.dateRange('2026-06-01', '2026-06-21')),
        findsOneWidget,
      );
      expect(find.text(CourseCatalogStrings.whoIsItFor), findsNWidgets(2));
      expect(find.text(CourseCatalogStrings.durationSectionLabel), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an upper age alone, or one date alone, is left out rather than '
        'worded', (tester) async {
      await pumpCatalog(
        tester,
        FakeCourseRepository(
          courses: [
            sampleCourse(level: null, ageMin: null, ageMax: 18, endDate: null, durationWeeks: null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('18'), findsNothing);
      expect(find.textContaining('2026'), findsNothing);
      expect(find.text(CourseCatalogStrings.whoIsItFor), findsNothing);
      expect(find.text(CourseCatalogStrings.durationSectionLabel), findsNothing);
    });

    testWidgets('no currency: the amount alone; no discount without a list price', (
      tester,
    ) async {
      await pumpCatalog(
        tester,
        FakeCourseRepository(
          courses: [
            sampleCourse(id: 1, currency: null),
            sampleCourse(id: 2, priceAmount: null),
            sampleCourse(id: 3, discountPercent: null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('960,000'), findsOneWidget);
      expect(find.text('1,200,000'), findsOneWidget);
      expect(find.text('960,000 MNT'), findsNWidgets(2));
      expect(find.text('1,200,000 MNT'), findsNothing);
      expect(find.text('-20%'), findsOneWidget);
    });
  });

  group('age range', () {
    test('formats a bounded range and an open-ended one', () {
      expect(CourseCatalogStrings.ageRange(10, 18), '10-18 ${CourseCatalogStrings.ageUnit}');
      expect(CourseCatalogStrings.ageRange(18, null), '18+ ${CourseCatalogStrings.ageUnit}');
    });

    testWidgets('a course with no age_max shows an open-ended range', (tester) async {
      final course = sampleCourse(level: 'adult', ageMin: 18, ageMax: null);
      await pumpCatalog(tester, FakeCourseRepository(courses: [course]));
      await tester.pumpAndSettle();

      expect(find.text('Adult · 18+ ${CourseCatalogStrings.ageUnit}'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
      expect(find.textContaining('18-'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('empty', () {
    testWidgets('shows the empty message when the catalog has no courses', (
      tester,
    ) async {
      await pumpCatalog(tester, FakeCourseRepository(courses: const []));
      await tester.pumpAndSettle();

      expect(find.text(CourseCatalogStrings.empty), findsOneWidget);
      expect(find.byType(CourseCard), findsNothing);
      expect(
        find.widgetWithText(AppButton, CourseCatalogStrings.retry),
        findsNothing,
      );
    });
  });

  group('error', () {
    testWidgets('shows the matching message for each failure kind', (
      tester,
    ) async {
      final repository = FakeCourseRepository(
        failure: const ApiFailure(ApiFailureKind.network),
      );
      await pumpCatalog(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text(CourseCatalogStrings.networkError), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, CourseCatalogStrings.retry),
        findsOneWidget,
      );
      expect(find.byType(CourseCard), findsNothing);
    });

    testWidgets('retrying re-fetches and, on success, shows the list', (
      tester,
    ) async {
      final repository = FakeCourseRepository(
        failure: const ApiFailure(ApiFailureKind.server),
      );
      await pumpCatalog(tester, repository);
      await tester.pumpAndSettle();
      expect(repository.callCount, 1);

      repository.failure = null;
      repository.courses = [sampleCourse()];

      await tester.tap(
        find.widgetWithText(AppButton, CourseCatalogStrings.retry),
      );
      await tester.pumpAndSettle();

      expect(repository.callCount, 2);
      expect(find.text(CourseCatalogStrings.serverError), findsNothing);
      expect(find.byType(CourseCard), findsOneWidget);
    });
  });

  group('pull to refresh', () {
    testWidgets('a loaded list re-fetches on pull', (tester) async {
      final repository = FakeCourseRepository(courses: [sampleCourse()]);
      await pumpCatalog(tester, repository);
      await tester.pumpAndSettle();
      expect(repository.callCount, 1);

      await tester.fling(
        find.byType(CourseCard).first,
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(repository.callCount, 2);
    });
  });

  group('layout', () {
    testWidgets('stays within a phone-width column on a desktop window', (
      tester,
    ) async {
      await pumpCatalog(
        tester,
        FakeCourseRepository(courses: [sampleCourse()]),
        size: const Size(1200, 900),
      );
      await tester.pumpAndSettle();

      final card = tester.getRect(find.byType(CourseCard));
      expect(card.width, lessThanOrEqualTo(480 - 32));
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow with several courses on a short viewport', (
      tester,
    ) async {
      await pumpCatalog(
        tester,
        FakeCourseRepository(
          courses: List.generate(
            6,
            (i) => sampleCourse(id: i, slug: 'course-$i'),
          ),
        ),
        size: const Size(393, 420),
      );
      await tester.pumpAndSettle();

      // A ListView only builds what fits the viewport (plus its cache
      // extent), so not all 6 are necessarily realised without scrolling —
      // what this test actually guards is that the short viewport does not
      // overflow, which pumpAndSettle already would have thrown on.
      expect(tester.takeException(), isNull);
      expect(find.byType(CourseCard), findsWidgets);

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
