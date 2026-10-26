import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/lesson_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_module_card.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_progress_cta_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_course_learning_repository.dart';

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

  Future<void> pumpScreen(
    WidgetTester tester,
    FakeCourseLearningRepository repository, {
    String courseSlug = 'how-ai-works',
    Size size = const Size(393, 852),
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = size * 3;
    addTearDown(tester.view.reset);

    // Pushed onto a stack, like the real navigation, so the back button has
    // something real to pop back to — same harness shape as
    // course_detail_screen_test.dart's `pumpDetail`.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CourseModuleListScreen(
                      courseSlug: courseSlug,
                      repository: repository,
                    ),
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

  /// Finds an [SvgPicture] by a fragment of its asset path.
  Finder svgAsset(String fragment) => find.byWidgetPredicate(
    (w) => w is SvgPicture && w.bytesLoader.toString().contains(fragment),
  );

  Finder backButton() => find.byIcon(AppIcons.arrowLeft);

  group('hero', () {
    testWidgets('renders the course title and description', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      expect(find.text('How AI works'), findsOneWidget);
      expect(
        find.text(
          'Take a peek under the hood of generative AI and LLMs to understand how they work',
        ),
        findsOneWidget,
      );
    });
  });

  group('progress', () {
    testWidgets('renders the overall percent complete, twice', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      // Once in the hero row, once at the foot of the certification section.
      expect(find.text('30% complete'), findsNWidgets(2));
    });

    testWidgets('renders the Continue learning CTA, twice', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      expect(find.text('Continue learning'), findsNWidgets(2));
    });
  });

  /// A course whose modules list their own lessons, with ids unique across
  /// the course as the server's are: module 1's two (completed by their
  /// notes, Issue #415), module 2's two — the first the server's continue
  /// lesson — and module 3's one, locked with its module. Modules 4 and 5
  /// list none.
  FakeCourseLearningRepository course({bool withContinue = true}) =>
      FakeCourseLearningRepository(
        path: samplePath(
          continueModuleId: withContinue ? 2 : null,
          continueLessonId: withContinue ? 21 : null,
        ),
        lessons: const [],
        lessonsByModule: {
          1: [
            sampleLesson(id: 11, moduleId: 1, order: 1, title: 'Patterns'),
            sampleLesson(id: 12, moduleId: 1, order: 2, title: 'Logic'),
          ],
          2: [
            sampleLesson(id: 21, moduleId: 2, order: 1, title: 'Nesting'),
            sampleLesson(id: 22, moduleId: 2, order: 2, title: 'Combining'),
          ],
          3: [
            sampleLesson(
              id: 31,
              moduleId: 3,
              order: 1,
              title: 'Deep nets',
              locked: true,
            ),
          ],
        },
        notesByLesson: {11: sampleNote(), 12: sampleNote()},
      );

  CourseLessonCard cardFor(WidgetTester tester, String title) => tester
      .widget<CourseLessonCard>(find.widgetWithText(CourseLessonCard, title));

  group('lessons (Issue #437)', () {
    testWidgets('every lesson of the course, in course order, numbered '
        '01–N — and no module cards', (tester) async {
      final repository = course();
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();

      expect(find.byType(CourseModuleCard), findsNothing);
      final cards = tester
          .widgetList<CourseLessonCard>(find.byType(CourseLessonCard))
          .toList();
      expect([for (final c in cards) c.entry.lesson.id], [11, 12, 21, 22, 31]);
      expect([for (final c in cards) c.entry.number], [1, 2, 3, 4, 5]);
      for (final label in ['01', '02', '03', '04', '05']) {
        expect(find.text(label), findsOneWidget);
      }
      // Each lesson keeps its module: its tile, and its lock.
      expect([for (final c in cards) c.entry.module.id], [1, 1, 2, 2, 3]);
      // Every module's lessons, all at once.
      expect(repository.lessonCalls, [1, 2, 3, 4, 5]);
    });

    testWidgets('completed lessons carry the check, a locked one the padlock', (
      tester,
    ) async {
      await pumpScreen(tester, course());
      await tester.pumpAndSettle();

      expect(svgAsset('course_detail_completed_check'), findsNWidgets(2));
      // The locked lesson and the unreached one (Issue #439).
      expect(svgAsset('course_detail_lock'), findsNWidgets(2));
      expect(cardFor(tester, 'Patterns').entry.lesson.completed, isTrue);
      expect(cardFor(tester, 'Deep nets').entry.locked, isTrue);
      expect(cardFor(tester, 'Combining').entry.lesson.completed, isFalse);
    });

    testWidgets('only what lessonOpens allows opens: a completed lesson and '
        'the one to continue with; any other card is inert', (tester) async {
      final repository = course();
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();

      expect(cardFor(tester, 'Patterns').onTap, isNotNull);
      expect(cardFor(tester, 'Nesting').onTap, isNotNull);
      expect(cardFor(tester, 'Combining').onTap, isNull);
      expect(cardFor(tester, 'Deep nets').onTap, isNull);

      for (final inert in ['Combining', 'Deep nets']) {
        await tester.ensureVisible(find.text(inert));
        await tester.tap(find.text(inert));
        await tester.pumpAndSettle();
        expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      }

      await tester.ensureVisible(find.text('Patterns'));
      await tester.tap(find.text('Patterns'));
      await tester.pumpAndSettle();
      final detail = tester.widget<CourseExerciseDetailScreen>(
        find.byType(CourseExerciseDetailScreen),
      );
      expect(detail.lessonId, 11);
      expect(detail.repository, same(repository));
      expect(find.byType(LessonListScreen), findsNothing);
    });

    testWidgets('a course whose modules list no lessons shows the empty '
        'message, and the rest of the page', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository(lessons: const []));
      await tester.pumpAndSettle();

      expect(find.byType(CourseLessonCard), findsNothing);
      expect(find.text(CourseLearningStrings.lessonsEmpty), findsOneWidget);
      expect(
        find.text(CourseLearningStrings.certificationLabel),
        findsOneWidget,
      );
    });

    testWidgets('a lessons read that fails fails the page, with retry', (
      tester,
    ) async {
      final repository = course()
        ..lessonsFailure = const CourseLearningFailure(
          CourseLearningFailureKind.network,
        );
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text(CourseLearningStrings.networkError), findsOneWidget);
      expect(find.byType(CourseLessonCard), findsNothing);

      repository.lessonsFailure = null;
      await tester.tap(find.text(CourseLearningStrings.retry));
      await tester.pumpAndSettle();
      expect(find.byType(CourseLessonCard), findsNWidgets(5));
    });

    testWidgets('one lesson\'s failed note read: the page loads, that lesson '
        'is not completed, its neighbour still is (Issue #535)', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        course()
          ..noteFailuresByLesson[11] = const CourseLearningFailure(
            CourseLearningFailureKind.network,
          ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CourseLearningStrings.networkError), findsNothing);
      expect(find.byType(CourseLessonCard), findsNWidgets(5));
      expect(cardFor(tester, 'Patterns').entry.lesson.completed, isFalse);
      expect(cardFor(tester, 'Logic').entry.lesson.completed, isTrue);
      expect(cardFor(tester, 'Deep nets').entry.locked, isTrue);
    });

    testWidgets('a refused session while reading notes still fails the page', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        course()
          ..noteFailuresByLesson[12] = const CourseLearningFailure(
            CourseLearningFailureKind.sessionExpired,
          ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CourseLearningStrings.sessionExpired), findsOneWidget);
      expect(find.byType(CourseLessonCard), findsNothing);
    });
  });

  group('lessons the student has reached open (Issue #439)', () {
    /// The server's own progress, as `agentic.s01` has it on the local
    /// backend: module 1's lessons reached (`completed: true`) — one with a
    /// note, one without; module 2's first the continue lesson, its second
    /// unlocked but not reached; module 3's locked, and one there the server
    /// counts reached although its class moved later.
    FakeCourseLearningRepository progressed() => FakeCourseLearningRepository(
      path: samplePath(continueModuleId: 2, continueLessonId: 21),
      lessons: const [],
      lessonsByModule: {
        1: [
          sampleLesson(
            id: 11,
            moduleId: 1,
            order: 1,
            title: 'Reached, no note',
            completed: true,
          ),
          sampleLesson(
            id: 12,
            moduleId: 1,
            order: 2,
            title: 'Reached, with note',
            completed: true,
          ),
        ],
        2: [
          sampleLesson(id: 21, moduleId: 2, order: 1, title: 'Current'),
          sampleLesson(id: 22, moduleId: 2, order: 2, title: 'Not reached'),
        ],
        3: [
          sampleLesson(
            id: 31,
            moduleId: 3,
            order: 1,
            title: 'Locked future',
            locked: true,
          ),
          sampleLesson(
            id: 32,
            moduleId: 3,
            order: 2,
            title: 'Reached, now locked',
            completed: true,
            locked: true,
          ),
        ],
      },
      notesByLesson: {12: sampleNote()},
    );

    Finder lockIn(String title) => find.descendant(
      of: find.widgetWithText(CourseLessonCard, title),
      matching: svgAsset('course_detail_lock'),
    );
    Finder checkIn(String title) => find.descendant(
      of: find.widgetWithText(CourseLessonCard, title),
      matching: svgAsset('course_detail_completed_check'),
    );

    Future<void> opens(
      WidgetTester tester,
      FakeCourseLearningRepository repository,
      String title,
      int id,
    ) async {
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CourseExerciseDetailScreen>(
              find.byType(CourseExerciseDetailScreen),
            )
            .lessonId,
        id,
      );
      await tester.tap(find.byIcon(AppIcons.arrowLeft));
      await tester.pumpAndSettle();
    }

    testWidgets('a previous lesson without a note opens — enabled, no tick', (
      tester,
    ) async {
      final repository = progressed();
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();

      final card = cardFor(tester, 'Reached, no note');
      expect(card.entry.reached, isTrue);
      expect(card.entry.lesson.completed, isFalse); // the note rule: no tick
      expect(card.available, isTrue);
      expect(checkIn('Reached, no note'), findsNothing);
      expect(lockIn('Reached, no note'), findsNothing);
      await opens(tester, repository, 'Reached, no note', 11);
    });

    testWidgets('a completed lesson opens, with its tick', (tester) async {
      final repository = progressed();
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();

      expect(cardFor(tester, 'Reached, with note').available, isTrue);
      expect(checkIn('Reached, with note'), findsOneWidget);
      await opens(tester, repository, 'Reached, with note', 12);
    });

    testWidgets('the lesson to continue with opens and stays highlighted', (
      tester,
    ) async {
      final repository = progressed();
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();

      final card = cardFor(tester, 'Current');
      expect(card.current, isTrue);
      expect(card.available, isTrue);
      expect(find.text(CourseLearningStrings.continueHere), findsOneWidget);
      await opens(tester, repository, 'Current', 21);
      expect(cardFor(tester, 'Current').current, isTrue);
    });

    testWidgets('a locked future lesson is inert and drawn disabled', (
      tester,
    ) async {
      final repository = progressed();
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();

      for (final title in [
        'Locked future',
        'Not reached',
        'Reached, now locked',
      ]) {
        final card = cardFor(tester, title);
        expect(card.available, isFalse, reason: title);
        expect(card.onTap, isNull, reason: title);
        expect(lockIn(title), findsOneWidget, reason: title);
        expect(
          tester
              .widget<Text>(
                find.descendant(
                  of: find.widgetWithText(CourseLessonCard, title),
                  matching: find.text(title),
                ),
              )
              .style!
              .color,
          const Color(0xFFB5B5B5),
          reason: title,
        );
        await tester.ensureVisible(find.text(title));
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      }
      expect(repository.exerciseCalls, isEmpty);
      // A locked lesson's note is never asked for.
      expect(repository.noteCalls, isNot(contains(31)));
      expect(repository.noteCalls, isNot(contains(32)));
    });
  });

  group('the lesson to continue with (Issue #437)', () {
    testWidgets('only the server\'s continue lesson is highlighted, with '
        '"Эндээс үргэлжлүүлнэ"', (tester) async {
      await pumpScreen(tester, course());
      await tester.pumpAndSettle();

      final current = tester
          .widgetList<CourseLessonCard>(find.byType(CourseLessonCard))
          .where((c) => c.current);
      expect([for (final c in current) c.entry.lesson.id], [21]);
      expect(find.text('Эндээс үргэлжлүүлнэ'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(CourseLessonCard, 'Nesting'),
          matching: find.text(CourseLearningStrings.continueHere),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no continue lesson: nothing is highlighted', (tester) async {
      await pumpScreen(tester, course(withContinue: false));
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<CourseLessonCard>(find.byType(CourseLessonCard))
            .where((c) => c.current),
        isEmpty,
      );
      expect(find.text(CourseLearningStrings.continueHere), findsNothing);
    });

    testWidgets('a continue lesson in a locked module is not highlighted, '
        'and stays shut', (tester) async {
      final repository = course()
        ..path = samplePath(continueModuleId: 3, continueLessonId: 31);
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text(CourseLearningStrings.continueHere), findsNothing);
      expect(cardFor(tester, 'Deep nets').onTap, isNull);
    });

    /// 95 lessons in module 2, the 80th the one to continue with; the 79
    /// before it completed by their notes.
    FakeCourseLearningRepository longCourse() => FakeCourseLearningRepository(
      path: samplePath(continueModuleId: 2, continueLessonId: 1079),
      lessons: const [],
      lessonsByModule: {
        2: [
          for (var i = 0; i < 95; i++)
            sampleLesson(
              id: 1000 + i,
              moduleId: 2,
              order: i + 1,
              title: 'Lesson ${i + 1}',
            ),
        ],
      },
      notesByLesson: {for (var i = 0; i < 79; i++) 1000 + i: sampleNote()},
    );

    /// Where `Scrollable.ensureVisible` puts [card] at an alignment of a
    /// fifth: that share of the viewport's free height above it.
    double fifthDown(WidgetTester tester, Rect card) {
      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      return viewport.top + 0.2 * (viewport.height - card.height);
    }

    testWidgets('a 95-lesson course opens with the lesson to continue with a '
        'fifth of the way down', (tester) async {
      await pumpScreen(tester, longCourse());
      await tester.pumpAndSettle();

      final card = tester.getRect(
        find.widgetWithText(CourseLessonCard, 'Lesson 80'),
      );
      expect(card.top, closeTo(fifthDown(tester, card), 1));
      expect(find.text('Lesson 1'), findsOneWidget); // built, scrolled past
      expect(
        find.text('Lesson 1').hitTestable(),
        findsNothing,
        reason: 'the top of the list is scrolled out of view',
      );
    });

    testWidgets('with reduced motion it jumps there, without animating', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpScreen(tester, longCourse());
      // The route's own transition, then the load and the one frame after.
      await tester.pumpAndSettle();

      final card = tester.getRect(
        find.widgetWithText(CourseLessonCard, 'Lesson 80'),
      );
      expect(card.top, closeTo(fifthDown(tester, card), 1));
    });

    testWidgets('without reduced motion the move is animated', (tester) async {
      await pumpScreen(tester, longCourse());
      // Past the route's transition and the load, but only one frame into
      // the scroll: still on the way.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final midway = tester.getRect(
        find.widgetWithText(CourseLessonCard, 'Lesson 80'),
      );
      await tester.pumpAndSettle();
      final settled = tester.getRect(
        find.widgetWithText(CourseLessonCard, 'Lesson 80'),
      );
      expect(settled.top, closeTo(fifthDown(tester, settled), 1));
      expect(midway.top, isNot(closeTo(settled.top, 1)));
    });

    testWidgets('back from a lesson reloads and stays where the student left '
        'it — no second scroll', (tester) async {
      final repository = longCourse();
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();

      // Away from where the screen put it.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();
      final opened = find.widgetWithText(CourseLessonCard, 'Lesson 75');
      final before = tester.getRect(opened);

      await tester.tap(opened);
      await tester.pumpAndSettle();
      expect(find.byType(CourseExerciseDetailScreen), findsOneWidget);
      await tester.tap(find.byIcon(AppIcons.arrowLeft));
      await tester.pumpAndSettle();

      expect(repository.calls, ['how-ai-works', 'how-ai-works']);
      expect(tester.getRect(opened), before);
    });

    testWidgets('back from "Continue learning" reloads too', (tester) async {
      final repository = course();
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();

      // The page scrolled to the current lesson, so the button may be
      // above the fold.
      await tester.ensureVisible(find.text('Continue learning').first);
      await tester.tap(find.text('Continue learning').first);
      await tester.pumpAndSettle();
      expect(find.byType(CourseExerciseDetailScreen), findsOneWidget);
      await tester.tap(find.byIcon(AppIcons.arrowLeft));
      await tester.pumpAndSettle();

      expect(repository.calls, ['how-ai-works', 'how-ai-works']);
    });
  });

  group('exercise navigation', () {
    testWidgets('tapping Continue learning opens Exercise Detail directly', (
      tester,
    ) async {
      final repository = FakeCourseLearningRepository(
        path: samplePath(continueModuleId: 2, continueLessonId: 204),
      );
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue learning').first);
      await tester.pumpAndSettle();

      // The server's `continue.lesson_id`, loaded through the screen's own
      // repository — the real lesson-detail flow.
      final detail = tester.widget<CourseExerciseDetailScreen>(
        find.byType(CourseExerciseDetailScreen),
      );
      expect(detail.lessonId, 204);
      expect(detail.repository, same(repository));
      expect(repository.exerciseCalls, [204]);
    });

    testWidgets('both Continue learning buttons open the same lesson', (
      tester,
    ) async {
      final repository = FakeCourseLearningRepository(
        path: samplePath(continueModuleId: 2, continueLessonId: 204),
      );
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();

      // The second button sits below the fold at this viewport.
      await tester.ensureVisible(find.text('Continue learning').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue learning').last);
      await tester.pumpAndSettle();

      final detail = tester.widget<CourseExerciseDetailScreen>(
        find.byType(CourseExerciseDetailScreen),
      );
      expect(detail.lessonId, 204);
    });

    testWidgets('a continue target in a locked module stays shut — its '
        'class date has not come (Issue #410)', (tester) async {
      // Module 5 is locked. The server never names a locked lesson as its
      // continue target, but should one arrive, the lock wins: a lesson
      // whose class date has not come never opens from any screen.
      final learning = FakeCourseLearningRepository(
        path: samplePath(continueModuleId: 5, continueLessonId: 501),
      );
      await pumpScreen(tester, learning);
      await tester.pumpAndSettle();

      for (final button in find.text('Continue learning').evaluate()) {
        await tester.tap(find.byWidget(button.widget), warnIfMissed: false);
        await tester.pumpAndSettle();
      }

      expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      expect(learning.exerciseCalls, isEmpty);
    });

    // The contract makes the continue target server-selected, so the screen
    // never substitutes one: with no usable server answer both buttons stay
    // drawn — the layout is unchanged — but open nothing.
    // A lesson id alone is not enough either: it is used only while its
    // module half names a listed module, and never guessed at without one.
    for (final (label, continueModuleId, continueLessonId) in [
      ('continue: null', null, null),
      ('a continue target with no lesson id', 2, null),
      ('a continue target no module matches', 999, 204),
    ]) {
      testWidgets('$label leaves both buttons drawn but inert', (tester) async {
        await pumpScreen(
          tester,
          FakeCourseLearningRepository(
            path: samplePath(
              continueModuleId: continueModuleId,
              continueLessonId: continueLessonId,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Continue learning'), findsNWidgets(2));
        for (var i = 0; i < 2; i++) {
          await tester.tap(find.text('Continue learning').at(i));
          await tester.pumpAndSettle();
        }

        expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      });
    }
  });

  group('failure', () {
    testWidgets('shows the failure\'s own copy and a retry, not a crash', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(
          failure: const CourseLearningFailure(
            CourseLearningFailureKind.notEnrolled,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CourseLearningStrings.notEnrolled), findsOneWidget);
      expect(find.text(CourseLearningStrings.retry), findsOneWidget);
      // The page's own content is gone, not half-drawn over an error.
      expect(find.byType(CourseLessonCard), findsNothing);
      expect(find.text('Continue learning'), findsNothing);
    });

    testWidgets('retry re-requests and renders the path on success', (
      tester,
    ) async {
      final repository = FakeCourseLearningRepository(
        failure: const CourseLearningFailure(CourseLearningFailureKind.network),
      );
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();
      expect(find.text(CourseLearningStrings.networkError), findsOneWidget);

      repository.failure = null;
      await tester.tap(find.text(CourseLearningStrings.retry));
      await tester.pumpAndSettle();

      expect(repository.calls, ['how-ai-works', 'how-ai-works']);
      expect(find.text(CourseLearningStrings.networkError), findsNothing);
      // The sample course's lessons: three per module, by default.
      expect(find.byType(CourseLessonCard), findsWidgets);
    });
  });

  group('certification', () {
    testWidgets('renders the certification label and title', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      expect(find.text('CERTIFICATION'), findsOneWidget);
      expect(find.text('Earn a Certificate of completion'), findsOneWidget);
    });

    testWidgets('renders the certificate preview image', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      final images = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => (image.image as AssetImage).assetName)
          .toList();
      expect(images, contains('assets/images/certificate.png'));
      expect(images, contains('assets/images/certificate_backround.png'));
    });
  });

  group('back navigation', () {
    testWidgets('the back button pops the screen', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();
      expect(find.byType(CourseModuleListScreen), findsOneWidget);

      await tester.tap(backButton());
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(find.byType(CourseModuleListScreen), findsNothing);
    });

    testWidgets('the full chain: Exercise Detail back returns to Course '
        'Detail, Course Detail back returns to the previous screen '
        '(Issue #437: no Lesson List in between)', (tester) async {
      await pumpScreen(tester, course());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Patterns'));
      await tester.tap(find.text('Patterns'));
      await tester.pumpAndSettle();
      expect(find.byType(CourseExerciseDetailScreen), findsOneWidget);
      expect(find.byType(LessonListScreen), findsNothing);

      // Exercise Detail's own back control is the video header's arrow.
      await tester.tap(find.byIcon(AppIcons.arrowLeft));
      await tester.pumpAndSettle();
      expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      expect(find.byType(CourseModuleListScreen), findsOneWidget);

      await tester.tap(backButton());
      await tester.pumpAndSettle();
      expect(find.byType(CourseModuleListScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('loading', () {
    testWidgets('shows a spinner while the fetch is in flight', (tester) async {
      final repository = FakeCourseLearningRepository(hold: true);
      await pumpScreen(tester, repository);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repository.release();
      await tester.pumpAndSettle();
    });
  });

  group('Figma reference geometry', () {
    // Measured off the 393 x 1391 reference frame at 1:1. The screenshot test
    // beside this one captures the whole page at that frame; these pin the
    // handful of values most likely to drift silently.

    testWidgets('lesson cards keep the module card\'s geometry: 94 tall, '
        '361 wide, 110 apart', (tester) async {
      // No current lesson, whose pill would make its card taller.
      await pumpScreen(
        tester,
        course(withContinue: false),
        size: const Size(393, 1400),
      );
      await tester.pumpAndSettle();

      final cards = [
        for (var i = 0; i < 5; i++)
          tester.getRect(find.byType(CourseLessonCard).at(i)),
      ];
      // 94 since Issue #366's type scale (the reference's 86 is the card's
      // minimum): number 18, title 22, 8, duration 20, inside 12 + 1 each
      // side.
      for (final card in cards) {
        expect(card.width, 361);
        expect(card.height, 94);
      }
      // 94 of card and 16 of gap — 4 of which the card's own band fills.
      for (var i = 1; i < cards.length; i++) {
        expect(cards[i].top - cards[i - 1].top, 110);
      }
    });

    testWidgets('the connector runs down the centre of the content', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        course(withContinue: false),
        size: const Size(393, 1400),
      );
      await tester.pumpAndSettle();

      // Four rules, one between each pair of cards — and on the content
      // column's midpoint, not under the icon tile.
      final rules = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 2 && w.height == 12,
      );
      expect(rules, findsNWidgets(4));

      final card = tester.getRect(find.byType(CourseLessonCard).first);
      for (var i = 0; i < 4; i++) {
        expect(tester.getRect(rules.at(i)).center.dx, card.center.dx);
      }
    });

    testWidgets('the progress bar is 8 tall in the reference colours', (
      tester,
    ) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      // Two of them: the hero's and the certification panel's.
      final bars = find.byType(LinearProgressIndicator);
      expect(bars, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        final bar = tester.widget<LinearProgressIndicator>(bars.at(i));
        expect(bar.minHeight, 8);
        expect(bar.backgroundColor, const Color(0xFFD6DBE1));
        expect(bar.valueColor!.value, const Color(0xFF2970FF));
        expect(bar.value, closeTo(0.30, 0.001));
      }
    });

    testWidgets('both CTAs are 40 tall and land on the frame\'s x213', (
      tester,
    ) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      final buttons = find.text('Continue learning');
      expect(buttons, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        final rect = tester.getRect(
          find.ancestor(
            of: buttons.at(i),
            matching: find.byType(ContinueLearningButton),
          ),
        );
        expect(rect.height, 40);
        // The reference keeps the button's left edge on x213 in both places
        // and lets its width change instead.
        expect(rect.left, closeTo(213, 1));
      }
    });

    testWidgets('a locked lesson keeps the full 56 tile and dims its title', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        course(withContinue: false),
        size: const Size(393, 1400),
      );
      await tester.pumpAndSettle();

      // The locked lesson, and — with no lesson to continue with — module 2's
      // two unreached ones, all drawn disabled (Issue #439).
      expect(svgAsset('course_detail_lock'), findsNWidgets(3));
      final tile = tester.getSize(
        find
            .ancestor(
              of: svgAsset('course_detail_lock').first,
              matching: find.byType(Container),
            )
            .first,
      );
      expect(tile, const Size(56, 56));

      expect(
        tester.widget<Text>(find.text('Deep nets')).style!.color,
        const Color(0xFFB5B5B5),
      );
      expect(
        tester.widget<Text>(find.text('Patterns')).style!.color,
        const Color(0xFF191919),
      );
    });
  });
}
