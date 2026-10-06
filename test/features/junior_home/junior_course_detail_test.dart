import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/lesson_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/assignment_tab.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_materials_tab.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/note_tab.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_learning_map_view.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../course_learning/fake_course_learning_repository.dart';
import 'fake_junior_home_repository.dart';

/// Junior Course Detail (Issue #174): an unlocked Junior Home map node opens
/// the course-learning screens on the same data, without the Note tab.
void main() {
  setUpAll(loadAppFonts);

  const slug = 'junior-ai-summer-10-14';

  JuniorLearningMap map({String? courseSlug = slug}) => JuniorLearningMap(
    courseSlug: courseSlug,
    progress: const JuniorCourseProgress(
      title: 'AI BootCamp',
      percentComplete: 30,
    ),
    nodes: const [
      JuniorMapNode(id: 1, state: JuniorNodeState.completed),
      JuniorMapNode(id: 2, state: JuniorNodeState.current),
      JuniorMapNode(id: 3, state: JuniorNodeState.locked),
    ],
    certificate: const JuniorCertificate(
      track: 'Junior',
      courseName: 'AI BootCamp',
      description: 'Earn a Certificate of completion',
    ),
  );

  /// The course behind the map: two finished modules and three locked, the
  /// server's resume point on module 2's lesson 2.
  FakeCourseLearningRepository course() => FakeCourseLearningRepository(
    path: samplePath(
      courseSlug: slug,
      courseTitle: 'AI BootCamp',
      continueModuleId: 2,
      continueLessonId: 2,
    ),
    lessons: sampleLessons(),
    exercise: sampleExercise(),
  );

  Future<void> pumpHome(
    WidgetTester tester, {
    required FakeCourseLearningRepository learning,
    JuniorLearningMap? learningMap,
  }) async {
    useLogicalViewport(tester, const Size(393, 1400), padding: iPhonePadding);
    useReducedMotion(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: JuniorHomeScreen(
          repository: FakeJuniorHomeRepository(map: learningMap ?? map()),
          courseLearningRepository: learning,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tile(JuniorNodeState state) => find.byWidgetPredicate(
    (w) => w is JuniorMapNodeTile && w.node.state == state,
  );

  Future<void> tapTile(WidgetTester tester, JuniorNodeState state) async {
    await tester.tap(tile(state));
    await tester.pumpAndSettle();
  }

  group('the Junior Home entry point', () {
    for (final state in [JuniorNodeState.completed, JuniorNodeState.current]) {
      testWidgets('a ${state.name} node opens the course, without notes', (
        tester,
      ) async {
        final learning = course();
        await pumpHome(tester, learning: learning);

        await tapTile(tester, state);

        final screen = tester.widget<CourseModuleListScreen>(
          find.byType(CourseModuleListScreen),
        );
        expect(screen.courseSlug, slug);
        expect(screen.showNotes, isFalse);
        // The same `GET /me/courses/{slug}/learning` contract.
        expect(learning.calls, [slug]);
      });
    }

    testWidgets('a locked node stays inert', (tester) async {
      final learning = course();
      await pumpHome(tester, learning: learning);

      expect(
        tester.widget<JuniorMapNodeTile>(tile(JuniorNodeState.locked)).onTap,
        isNull,
      );
      await tapTile(tester, JuniorNodeState.locked);

      expect(find.byType(CourseModuleListScreen), findsNothing);
      expect(learning.calls, isEmpty);
    });

    testWidgets('a map with no course behind it leaves every node inert', (
      tester,
    ) async {
      final learning = course();
      await pumpHome(
        tester,
        learning: learning,
        learningMap: map(courseSlug: null),
      );

      expect(
        tester
            .widgetList<JuniorMapNodeTile>(find.byType(JuniorMapNodeTile))
            .map((t) => t.onTap),
        everyElement(isNull),
      );
      await tapTile(tester, JuniorNodeState.completed);
      expect(find.byType(CourseModuleListScreen), findsNothing);
    });

    testWidgets('unlocked nodes are announced as buttons', (tester) async {
      await pumpHome(tester, learning: course());

      final completed = tester.getSemantics(tile(JuniorNodeState.completed));
      expect(completed.flagsCollection.isButton, isTrue);
      final locked = tester.getSemantics(tile(JuniorNodeState.locked));
      expect(locked.flagsCollection.isButton, isFalse);
    });
  });

  group('Junior Course Detail', () {
    testWidgets('draws the course from the learning path', (tester) async {
      await pumpHome(tester, learning: course());
      await tapTile(tester, JuniorNodeState.completed);

      expect(find.text('AI BootCamp'), findsWidgets);
      expect(
        find.text(CourseLearningStrings.percentComplete(30)),
        findsWidgets,
      );
      expect(find.text('Prediction and Probabilities'), findsOneWidget);
      expect(find.text('Deep network models'), findsOneWidget);
      expect(
        find.text(CourseLearningStrings.certificationLabel),
        findsOneWidget,
      );
    });

    testWidgets('a module opens its lessons, still without notes, and a '
        'locked module does nothing', (tester) async {
      final learning = course();
      await pumpHome(tester, learning: learning);
      await tapTile(tester, JuniorNodeState.completed);

      await tester.tap(find.text('Deep network models'));
      await tester.pumpAndSettle();
      expect(find.byType(LessonListScreen), findsNothing);

      await tester.tap(find.text('Language Model Training'));
      await tester.pumpAndSettle();
      final lessons = tester.widget<LessonListScreen>(
        find.byType(LessonListScreen),
      );
      expect(lessons.moduleId, 2);
      expect(lessons.showNotes, isFalse);
      expect(learning.lessonCalls, [2]);
    });

    testWidgets('a lesson\'s tab card has Assignment and Course materials, and '
        'no Note', (tester) async {
      final learning = course();
      await pumpHome(tester, learning: learning);
      await tapTile(tester, JuniorNodeState.completed);
      await tester.tap(find.text('Language Model Training'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nesting loops'));
      await tester.pumpAndSettle();

      final exercise = tester.widget<CourseExerciseDetailScreen>(
        find.byType(CourseExerciseDetailScreen),
      );
      expect(exercise.lessonId, 2);
      expect(exercise.showNotes, isFalse);
      expect(learning.exerciseCalls, [2]);

      expect(find.text(CourseLearningStrings.assignmentTab), findsOneWidget);
      expect(
        find.text(CourseLearningStrings.courseMaterialsTab),
        findsOneWidget,
      );
      expect(find.text(CourseLearningStrings.noteTab), findsNothing);
      expect(find.byType(NoteTab), findsNothing);

      // The assignment, as Adult draws it.
      expect(find.byType(AssignmentTab), findsOneWidget);

      // The materials, as Adult draws them.
      await tester.ensureVisible(
        find.text(CourseLearningStrings.courseMaterialsTab),
      );
      await tester.tap(find.text(CourseLearningStrings.courseMaterialsTab));
      await tester.pumpAndSettle();
      expect(find.byType(CourseMaterialsTab), findsOneWidget);
      expect(find.byType(NoteTab), findsNothing);
      // No note can be saved from the Junior flow.
      expect(learning.saveCalls, isEmpty);
    });

    testWidgets(
      '"Continue learning" opens the server\'s lesson without notes',
      (tester) async {
        final learning = course();
        await pumpHome(tester, learning: learning);
        await tapTile(tester, JuniorNodeState.completed);

        await tester.tap(
          find.text(CourseLearningStrings.continueLearning).first,
        );
        await tester.pumpAndSettle();

        final exercise = tester.widget<CourseExerciseDetailScreen>(
          find.byType(CourseExerciseDetailScreen),
        );
        expect(exercise.lessonId, 2);
        expect(exercise.showNotes, isFalse);
        expect(find.text(CourseLearningStrings.noteTab), findsNothing);
      },
    );

    testWidgets('back returns to Junior Home', (tester) async {
      await pumpHome(tester, learning: course());
      await tapTile(tester, JuniorNodeState.completed);

      await tester.tap(find.bySemanticsLabel(CourseLearningStrings.back));
      await tester.pumpAndSettle();

      expect(find.byType(CourseModuleListScreen), findsNothing);
      expect(find.byType(JuniorLearningMapView), findsOneWidget);
    });
  });

  group('Adult Course Detail is unchanged', () {
    testWidgets('a lesson still offers the Note tab', (tester) async {
      final learning = course();
      useLogicalViewport(tester, const Size(393, 1400), padding: iPhonePadding);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CourseModuleListScreen(courseSlug: slug, repository: learning),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CourseModuleListScreen>(find.byType(CourseModuleListScreen))
            .showNotes,
        isTrue,
      );

      await tester.tap(find.text('Language Model Training'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nesting loops'));
      await tester.pumpAndSettle();

      expect(find.text(CourseLearningStrings.assignmentTab), findsOneWidget);
      expect(
        find.text(CourseLearningStrings.courseMaterialsTab),
        findsOneWidget,
      );
      expect(find.text(CourseLearningStrings.noteTab), findsOneWidget);

      await tester.ensureVisible(find.text(CourseLearningStrings.noteTab));
      await tester.tap(find.text(CourseLearningStrings.noteTab));
      await tester.pumpAndSettle();
      expect(find.byType(NoteTab), findsOneWidget);
    });
  });
}
