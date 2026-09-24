import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/courses/presentation/course_detail_screen.dart';
import 'package:aia_mobile/features/courses/presentation/course_detail_strings.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_course_repository.dart';

/// Real font metrics, for the same reason the other screen tests load them.
Future<void> _loadFonts() async {
  const families = <String, List<String>>{
    'Manrope': [
      'assets/fonts/Manrope-Regular.ttf',
      'assets/fonts/Manrope-Medium.ttf',
      'assets/fonts/Manrope-SemiBold.ttf',
      'assets/fonts/Manrope-Bold.ttf',
      'assets/fonts/Manrope-ExtraBold.ttf',
    ],
    'Phosphor': ['assets/fonts/Phosphor.ttf'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);

  Future<void> pumpDetail(
    WidgetTester tester,
    FakeCourseRepository repository, {
    String slug = 'summer-bootcamp',
    Size size = const Size(393, 852),
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = size * 3;
    addTearDown(tester.view.reset);

    // Pushed onto a stack, like the real navigation, so the back button has
    // something real to pop back to and "back navigation must work" is
    // actually exercised rather than assumed.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        CourseDetailScreen(slug: slug, repository: repository),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
  }

  Finder backButton() => find.byIcon(AppIcons.caretLeft);

  group('loading', () {
    testWidgets('shows a spinner while the fetch is in flight', (tester) async {
      final repository = FakeCourseRepository(holdDetail: true);
      await pumpDetail(tester, repository);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repository.releaseDetail();
      await tester.pumpAndSettle();
    });

    testWidgets('still shows the back button while loading', (tester) async {
      final repository = FakeCourseRepository(holdDetail: true);
      await pumpDetail(tester, repository);
      await tester.pump();

      expect(backButton(), findsOneWidget);

      repository.releaseDetail();
      await tester.pumpAndSettle();
    });
  });

  group('loaded', () {
    testWidgets('shows the confirmed base fields', (tester) async {
      await pumpDetail(
        tester,
        FakeCourseRepository(courseDetail: sampleCourse()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Зуны бүтээлч кэмп'), findsOneWidget);
      expect(find.text('3 долоо хоногийн эрчимжүүлсэн'), findsOneWidget);
      expect(find.text('bootcamp'), findsOneWidget);
      expect(find.text('junior'), findsOneWidget);
      expect(find.text('in_person'), findsOneWidget);
      expect(find.text('open'), findsOneWidget);
      expect(find.text('10-18 нас'), findsOneWidget);
      expect(find.textContaining('960,000'), findsOneWidget);
      expect(find.textContaining('1,200,000'), findsOneWidget);
      expect(find.textContaining('-20%'), findsOneWidget);
    });

    testWidgets('renders description from a bilingual {en,mn} object', (
      tester,
    ) async {
      final course = sampleCourse(
        description: {'en': 'A hands-on bootcamp', 'mn': 'Гарын доорх сургалт'},
      );
      await pumpDetail(tester, FakeCourseRepository(courseDetail: course));
      await tester.pumpAndSettle();

      expect(find.text(CourseDetailStrings.descriptionTitle), findsOneWidget);
      expect(find.text('Гарын доорх сургалт'), findsOneWidget);
      expect(find.text('A hands-on bootcamp'), findsNothing);
    });

    testWidgets(
      'renders description as a paragraph when it is a plain string',
      (tester) async {
        final course = sampleCourse(description: 'A hands-on bootcamp');
        await pumpDetail(tester, FakeCourseRepository(courseDetail: course));
        await tester.pumpAndSettle();

        expect(find.text('A hands-on bootcamp'), findsOneWidget);
      },
    );

    testWidgets('renders a list-shaped curriculum as bulleted lines', (
      tester,
    ) async {
      final course = sampleCourse(
        curriculum: ['Week 1: Intro', 'Week 2: Build', 'Week 3: Ship'],
      );
      await pumpDetail(tester, FakeCourseRepository(courseDetail: course));
      await tester.pumpAndSettle();

      expect(find.text(CourseDetailStrings.curriculumTitle), findsOneWidget);
      expect(find.text('•  Week 1: Intro'), findsOneWidget);
      expect(find.text('•  Week 2: Build'), findsOneWidget);
      expect(find.text('•  Week 3: Ship'), findsOneWidget);
    });

    testWidgets('renders a single-item field without a bullet', (tester) async {
      final course = sampleCourse(prerequisites: 'Basic computer literacy');
      await pumpDetail(tester, FakeCourseRepository(courseDetail: course));
      await tester.pumpAndSettle();

      expect(find.text('Basic computer literacy'), findsOneWidget);
      expect(find.text('•  Basic computer literacy'), findsNothing);
    });

    testWidgets('renders a list of objects generically, key by key', (
      tester,
    ) async {
      final course = sampleCourse(
        instructors: [
          {'name': 'Bat', 'title': 'Lead instructor'},
        ],
      );
      await pumpDetail(tester, FakeCourseRepository(courseDetail: course));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bat'), findsOneWidget);
      expect(find.textContaining('Lead instructor'), findsOneWidget);
    });

    testWidgets('a section with nothing to show renders no heading at all', (
      tester,
    ) async {
      // Every ambiguous-shape field left null.
      await pumpDetail(
        tester,
        FakeCourseRepository(courseDetail: sampleCourse()),
      );
      await tester.pumpAndSettle();

      expect(find.text(CourseDetailStrings.descriptionTitle), findsNothing);
      expect(find.text(CourseDetailStrings.curriculumTitle), findsNothing);
      expect(find.text(CourseDetailStrings.instructorsTitle), findsNothing);
      expect(find.text(CourseDetailStrings.prerequisitesTitle), findsNothing);
      expect(find.text(CourseDetailStrings.whatsIncludedTitle), findsNothing);
    });

    testWidgets(
      'a wrongly-shaped composite field degrades to nothing, not a crash',
      (tester) async {
        // Not a List, not a Map, not a String — an int, which no branch of the
        // renderer specifically expects for one of these fields.
        final course = sampleCourse(whatsIncluded: 42);
        await pumpDetail(tester, FakeCourseRepository(courseDetail: course));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('42'), findsOneWidget);
      },
    );
  });

  group('course learning', () {
    testWidgets('the CTA opens CourseModuleListScreen for the course\'s slug', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        FakeCourseRepository(
          courseDetail: sampleCourse(slug: 'summer-bootcamp'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(AppButton, CourseDetailStrings.openCourseLearning),
      );
      await tester.pumpAndSettle();

      final screen = tester.widget<CourseModuleListScreen>(
        find.byType(CourseModuleListScreen),
      );
      expect(screen.courseSlug, 'summer-bootcamp');
      // Pushed, not replaced: the detail screen is still underneath, poppable.
      expect(
        Navigator.of(
          tester.element(find.byType(CourseModuleListScreen)),
        ).canPop(),
        isTrue,
      );
    });
  });

  group('error', () {
    testWidgets(
      'a missing course shows the not-found message, not a generic one',
      (tester) async {
        final repository = FakeCourseRepository(
          detailFailure: const ApiFailure(ApiFailureKind.notFound),
        );
        await pumpDetail(tester, repository);
        await tester.pumpAndSettle();

        expect(find.text(CourseDetailStrings.notFound), findsOneWidget);
        expect(
          find.widgetWithText(AppButton, CourseDetailStrings.retry),
          findsOneWidget,
        );
      },
    );

    testWidgets('a network failure shows its own message', (tester) async {
      final repository = FakeCourseRepository(
        detailFailure: const ApiFailure(ApiFailureKind.network),
      );
      await pumpDetail(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text(CourseDetailStrings.networkError), findsOneWidget);
    });

    testWidgets('retrying re-fetches and, on success, shows the course', (
      tester,
    ) async {
      final repository = FakeCourseRepository(
        detailFailure: const ApiFailure(ApiFailureKind.server),
      );
      await pumpDetail(tester, repository);
      await tester.pumpAndSettle();
      expect(repository.detailCalls, hasLength(1));

      repository.detailFailure = null;
      repository.courseDetail = sampleCourse();

      await tester.tap(
        find.widgetWithText(AppButton, CourseDetailStrings.retry),
      );
      await tester.pumpAndSettle();

      expect(repository.detailCalls, hasLength(2));
      expect(find.text(CourseDetailStrings.serverError), findsNothing);
      expect(find.text('Зуны бүтээлч кэмп'), findsOneWidget);
    });

    testWidgets('the back button still works from the error state', (
      tester,
    ) async {
      final repository = FakeCourseRepository(
        detailFailure: const ApiFailure(ApiFailureKind.network),
      );
      await pumpDetail(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(backButton());
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(find.byType(CourseDetailScreen), findsNothing);
    });
  });

  group('back navigation', () {
    testWidgets('the back button pops the screen', (tester) async {
      await pumpDetail(
        tester,
        FakeCourseRepository(courseDetail: sampleCourse()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CourseDetailScreen), findsOneWidget);

      await tester.tap(backButton());
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(find.byType(CourseDetailScreen), findsNothing);
    });

    testWidgets('the system back gesture also pops the screen', (tester) async {
      await pumpDetail(
        tester,
        FakeCourseRepository(courseDetail: sampleCourse()),
      );
      await tester.pumpAndSettle();

      // Simulates the Android hardware/gesture back button, independent of
      // this screen's own back affordance.
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(CourseDetailScreen), findsNothing);
    });
  });

  group('layout', () {
    testWidgets('stays within a phone-width column on a desktop window', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        FakeCourseRepository(courseDetail: sampleCourse()),
        size: const Size(1200, 900),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('a course with every optional section does not overflow', (
      tester,
    ) async {
      final course = sampleCourse(
        bannerImageUrl: 'https://example.test/banner.png',
        targetAudience: 'Beginners welcome',
        description: 'A hands-on bootcamp for absolute beginners.',
        curriculum: List.generate(10, (i) => 'Week ${i + 1}: Topic $i'),
        prerequisites: ['A laptop', 'Curiosity'],
        whatsIncluded: ['Laptop', 'Course materials', 'Certificate'],
        instructors: [
          {'name': 'Bat', 'title': 'Lead instructor'},
          {'name': 'Sara', 'title': 'Assistant'},
        ],
      );
      await pumpDetail(
        tester,
        FakeCourseRepository(courseDetail: course),
        size: const Size(393, 700),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
