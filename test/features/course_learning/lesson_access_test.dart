import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/domain/lesson_access.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/lesson_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/lesson_navigation.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/lesson_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_course_learning_repository.dart';

/// A lesson whose class date has not come — the server's `locked` — never
/// opens from any entry point (Issue #410). Junior Home's nodes are covered
/// in `junior_home/junior_lesson_progression_test.dart`; this file covers
/// the shared opener, Course Detail and the Lesson List. Every one of them
/// opens a lesson only through `openLesson`. No backend is called.
void main() {
  setUpAll(loadAppFonts);

  Future<void> pumpHome(WidgetTester tester, Widget home) async {
    useLogicalViewport(tester, const Size(393, 1400), padding: iPhonePadding);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: home));
    await tester.pumpAndSettle();
  }

  group('lessonOpens — the one rule', () {
    test('unlocked, and completed or the lesson to continue with', () {
      // (locked, completed, isResume) -> opens
      const table = <(bool, bool, bool, bool)>[
        (false, true, false, true), // completed, class date come
        (false, false, true, true), // the lesson to continue with
        (false, false, false, false), // date come, but waits its turn
        (true, false, false, false), // class date not come
        (true, true, false, false), // completed, its class moved later
        (true, false, true, false), // a locked "continue" never opens
      ];
      for (final (locked, completed, isResume, opens) in table) {
        expect(
          lessonOpens(locked: locked, completed: completed, isResume: isResume),
          opens,
          reason: 'locked $locked, completed $completed, resume $isResume',
        );
      }
    });

    test('reached — the server\'s own progress — opens an unlocked lesson '
        'without a note, never a locked one (Issue #439)', () {
      expect(
        lessonOpens(
          locked: false,
          completed: false,
          isResume: false,
          reached: true,
        ),
        isTrue,
      );
      expect(
        lessonOpens(
          locked: true,
          completed: false,
          isResume: false,
          reached: true,
        ),
        isFalse,
        reason: 'the server lock always wins',
      );
      // Not passed — every caller but Course Detail, Junior Home's nodes
      // included — it changes nothing.
      expect(
        lessonOpens(locked: false, completed: false, isResume: false),
        isFalse,
      );
    });
  });

  group('openLesson — the one opener', () {
    Future<BuildContext> pumpContext(WidgetTester tester) async {
      late BuildContext context;
      await pumpHome(
        tester,
        Builder(
          builder: (c) {
            context = c;
            return const Scaffold();
          },
        ),
      );
      return context;
    }

    testWidgets('a locked lesson is refused: nothing pushed, nothing asked', (
      tester,
    ) async {
      final learning = FakeCourseLearningRepository(exercise: sampleExercise());
      final context = await pumpContext(tester);

      // Not awaited: were the lock ever ignored, the pushed lesson would
      // hold the future open — the test must fail, not hang.
      bool? opened;
      openLesson(
        context,
        lessonId: 7,
        locked: true,
        completed: false,
        resumeLessonId: 7,
        repository: learning,
      ).then((value) => opened = value);
      await tester.pumpAndSettle();

      expect(opened, isFalse);
      expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      expect(learning.exerciseCalls, isEmpty);
    });

    testWidgets('an unlocked, unfinished lesson that is not the one to '
        'continue with is refused too', (tester) async {
      final learning = FakeCourseLearningRepository(exercise: sampleExercise());
      final context = await pumpContext(tester);

      bool? opened;
      openLesson(
        context,
        lessonId: 8,
        locked: false,
        completed: false,
        resumeLessonId: 7,
        repository: learning,
      ).then((value) => opened = value);
      await tester.pumpAndSettle();

      expect(opened, isFalse);
      expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      expect(learning.exerciseCalls, isEmpty);
    });

    testWidgets('the lesson to continue with is pushed with its own id, and '
        'the call '
        'completes once it is closed', (tester) async {
      final learning = FakeCourseLearningRepository(exercise: sampleExercise());
      final context = await pumpContext(tester);

      var done = false;
      final opened = openLesson(
        context,
        lessonId: 7,
        locked: false,
        completed: false,
        resumeLessonId: 7,
        repository: learning,
      ).then((value) => done = value);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<CourseExerciseDetailScreen>(
              find.byType(CourseExerciseDetailScreen),
            )
            .lessonId,
        7,
      );
      expect(learning.exerciseCalls, [7]);
      expect(done, isFalse);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await opened;
      expect(done, isTrue);
    });
  });

  group('Lesson List', () {
    Widget list(FakeCourseLearningRepository learning, {int? resume}) =>
        LessonListScreen(
          moduleId: 3,
          moduleOrder: 3,
          moduleTitle: 'Deep network models',
          repository: learning,
          resumeLessonId: resume,
        );

    Finder row(String title) => find.ancestor(
      of: find.text(title),
      matching: find.byType(LessonListItem),
    );
    Finder svg(Finder of, String asset) => find.descendant(
      of: of,
      matching: find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            w.bytesLoader is SvgAssetLoader &&
            (w.bytesLoader as SvgAssetLoader).assetName.endsWith(asset),
      ),
    );

    testWidgets('a module whose class date has not come: no lesson opens, '
        'and no lesson content is asked for', (tester) async {
      final learning = FakeCourseLearningRepository(
        exercise: sampleExercise(),
        lessons: [
          sampleLesson(
            id: 31,
            moduleId: 3,
            order: 1,
            title: 'Neurons',
            locked: true,
          ),
          sampleLesson(
            id: 32,
            moduleId: 3,
            order: 2,
            title: 'Layers',
            locked: true,
          ),
        ],
      );
      await pumpHome(tester, list(learning));

      for (final title in ['Neurons', 'Layers']) {
        expect(tester.widget<LessonListItem>(row(title)).onTap, isNull);
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
      }

      expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      expect(learning.exerciseCalls, isEmpty);
    });

    testWidgets('every row, drawn and tapped: done and the continue lesson '
        'open; a lesson waiting its turn and a locked one do not', (
      tester,
    ) async {
      final learning = FakeCourseLearningRepository(
        exercise: sampleExercise(),
        // 'Done' is completed by its saved note (Issue #415).
        notesByLesson: {41: sampleNote()},
        lessons: [
          sampleLesson(
            id: 41,
            moduleId: 3,
            order: 1,
            title: 'Done',
            completed: true,
          ),
          sampleLesson(id: 42, moduleId: 3, order: 2, title: 'Next'),
          sampleLesson(id: 43, moduleId: 3, order: 3, title: 'Later'),
        ],
      );
      await pumpHome(tester, list(learning, resume: 42));

      // Drawn: the done row its check; no padlock on the open ones.
      expect(
        svg(row('Done'), 'course_detail_completed_check.svg'),
        findsOneWidget,
      );
      expect(svg(row('Later'), 'course_detail_lock.svg'), findsNothing);
      // Tapped: what each one does.
      expect(tester.widget<LessonListItem>(row('Later')).onTap, isNull);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(learning.exerciseCalls, isEmpty);

      for (final (title, id) in [('Done', 41), ('Next', 42)]) {
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
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
      }
      expect(learning.exerciseCalls, [41, 42]);
    });

    testWidgets('the lesson to continue with opens', (tester) async {
      final learning = FakeCourseLearningRepository(
        exercise: sampleExercise(),
        lessons: [sampleLesson(id: 33, moduleId: 3, order: 1, title: 'Open')],
      );
      await pumpHome(tester, list(learning, resume: 33));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<CourseExerciseDetailScreen>(
              find.byType(CourseExerciseDetailScreen),
            )
            .lessonId,
        33,
      );
    });

    testWidgets('a lesson the server counts completed, whose class moved '
        'later, shows the padlock and cannot be opened — its note can\'t be '
        'read (Issue #415)', (tester) async {
      final learning = FakeCourseLearningRepository(
        exercise: sampleExercise(),
        lessons: [
          sampleLesson(
            id: 34,
            moduleId: 3,
            order: 1,
            title: 'Done before',
            completed: true,
            locked: true,
          ),
        ],
      );
      await pumpHome(tester, list(learning));

      final done = row('Done before');
      expect(svg(done, 'course_detail_completed_check.svg'), findsNothing);
      expect(svg(done, 'course_detail_lock.svg'), findsOneWidget);
      expect(learning.noteCalls, isEmpty);
      expect(tester.widget<LessonListItem>(done).onTap, isNull);
      await tester.tap(find.text('Done before'));
      await tester.pumpAndSettle();
      expect(learning.exerciseCalls, isEmpty);
    });
  });

  group('Course Detail', () {
    Widget detail(FakeCourseLearningRepository learning) =>
        CourseModuleListScreen(
          courseSlug: 'how-ai-works',
          repository: learning,
        );

    testWidgets('a lesson whose module\'s class date has not come does not '
        'open, and its note is never read (Issue #437)', (tester) async {
      // The sample: modules 1–2 completed, 3–5 locked. The lesson itself is
      // not flagged; its module's lock is its own.
      final learning = FakeCourseLearningRepository(
        exercise: sampleExercise(),
        lessons: const [],
        lessonsByModule: {
          3: [sampleLesson(id: 31, moduleId: 3, title: 'Deep nets')],
        },
        notesByLesson: {31: sampleNote()},
      );
      await pumpHome(tester, detail(learning));

      await tester.ensureVisible(find.text('Deep nets'));
      await tester.tap(find.text('Deep nets'));
      await tester.pumpAndSettle();

      expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      expect(find.byType(LessonListScreen), findsNothing);
      expect(learning.noteCalls, isNot(contains(31)));
    });

    testWidgets('"Continue learning" never opens a lesson in a locked '
        'module', (tester) async {
      final learning = FakeCourseLearningRepository(
        exercise: sampleExercise(),
        path: samplePath(continueModuleId: 4, continueLessonId: 401),
      );
      await pumpHome(tester, detail(learning));

      for (final button in find.text('Continue learning').evaluate()) {
        await tester.tap(find.byWidget(button.widget), warnIfMissed: false);
        await tester.pumpAndSettle();
      }

      expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      expect(learning.exerciseCalls, isEmpty);
    });

    testWidgets('"Continue learning" opens the server\'s lesson when its '
        'class date has come', (tester) async {
      final learning = FakeCourseLearningRepository(
        exercise: sampleExercise(),
        path: samplePath(continueModuleId: 2, continueLessonId: 204),
      );
      await pumpHome(tester, detail(learning));

      await tester.tap(find.text('Continue learning').first);
      await tester.pumpAndSettle();

      expect(learning.exerciseCalls, [204]);
    });
  });
}
