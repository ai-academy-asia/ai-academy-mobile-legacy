import 'package:aia_mobile/core/theme/app_theme.dart';
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
        repository: learning,
      ).then((value) => opened = value);
      await tester.pumpAndSettle();

      expect(opened, isFalse);
      expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      expect(learning.exerciseCalls, isEmpty);
    });

    testWidgets('an open lesson is pushed with its own id, and the call '
        'completes once it is closed', (tester) async {
      final learning = FakeCourseLearningRepository(exercise: sampleExercise());
      final context = await pumpContext(tester);

      var done = false;
      final opened = openLesson(
        context,
        lessonId: 7,
        locked: false,
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
    Widget list(FakeCourseLearningRepository learning) => LessonListScreen(
      moduleId: 3,
      moduleOrder: 3,
      moduleTitle: 'Deep network models',
      repository: learning,
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

    testWidgets('a lesson whose class date has come opens', (tester) async {
      final learning = FakeCourseLearningRepository(
        exercise: sampleExercise(),
        lessons: [sampleLesson(id: 33, moduleId: 3, order: 1, title: 'Open')],
      );
      await pumpHome(tester, list(learning));

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

    testWidgets('a completed lesson whose class moved later keeps its '
        'completed check and cannot be opened', (tester) async {
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
      expect(svg(done, 'course_detail_completed_check.svg'), findsOneWidget);
      expect(svg(done, 'course_detail_lock.svg'), findsNothing);
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

    testWidgets('a module whose class date has not come does not open its '
        'lessons', (tester) async {
      // The sample: modules 1–2 completed, 3–5 locked.
      final learning = FakeCourseLearningRepository(exercise: sampleExercise());
      await pumpHome(tester, detail(learning));

      await tester.tap(find.text('Deep network models'));
      await tester.pumpAndSettle();

      expect(find.byType(LessonListScreen), findsNothing);
      expect(learning.lessonCalls, isEmpty);
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
