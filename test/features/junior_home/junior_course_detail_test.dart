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
import 'package:aia_mobile/features/attendance/presentation/attendance_scanner_screen.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_course_progress_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../course_learning/fake_course_learning_repository.dart';
import 'fake_junior_home_repository.dart';

/// The Junior course-learning screens, without the Note tab (Issue #174).
///
/// From Junior Home, a node opens **its own module's** lessons (Issue #204)
/// — not the course as a whole. The course screen keeps its Junior
/// no-notes behaviour, tested here directly.
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
      JuniorMapNode(
        id: 1,
        state: JuniorNodeState.completed,
        title: 'Prediction and Probabilities',
      ),
      JuniorMapNode(
        id: 2,
        state: JuniorNodeState.completed,
        title: 'Language Model Training',
      ),
      JuniorMapNode(
        id: 3,
        state: JuniorNodeState.current,
        title: 'Deep network models',
      ),
      JuniorMapNode(
        id: 4,
        state: JuniorNodeState.locked,
        title: 'Transformers',
      ),
    ],
    continueModuleId: 3,
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
          // No lesson under way: the current node opens its lessons.
          clock: () => DateTime(2026, 10, 6, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The node standing for module [id].
  Finder tile(int id) =>
      find.byWidgetPredicate((w) => w is JuniorMapNodeTile && w.node.id == id);

  Future<void> tapTile(WidgetTester tester, int id) async {
    await tester.tap(tile(id));
    await tester.pumpAndSettle();
  }

  group('the Junior Home entry point', () {
    for (final (id, title) in [
      (1, 'Prediction and Probabilities'),
      (2, 'Language Model Training'),
    ]) {
      testWidgets('completed node $id opens module $id\'s lessons, without '
          'notes (Issues #204, #207)', (tester) async {
        final learning = course();
        await pumpHome(tester, learning: learning);

        await tapTile(tester, id);

        final lessons = tester.widget<LessonListScreen>(
          find.byType(LessonListScreen),
        );
        expect(lessons.moduleId, id);
        expect(lessons.moduleTitle, title);
        expect(lessons.showNotes, isFalse);
        // `GET /me/modules/{module_id}/lessons` for that module — not the
        // course overview.
        expect(learning.lessonCalls, [id]);
        expect(learning.calls, isEmpty);
        expect(find.byType(CourseModuleListScreen), findsNothing);
      });
    }

    testWidgets('different completed nodes open different modules', (
      tester,
    ) async {
      final learning = course();
      await pumpHome(tester, learning: learning);

      await tapTile(tester, 1);
      await tester.tap(find.bySemanticsLabel(CourseLearningStrings.back));
      await tester.pumpAndSettle();
      await tapTile(tester, 2);

      expect(learning.lessonCalls, [1, 2]);
    });

    testWidgets('the QR node with check-in closed does nothing — no lessons, '
        'no scanner (Issue #207)', (tester) async {
      final learning = course();
      await pumpHome(tester, learning: learning);

      expect(tester.widget<JuniorMapNodeTile>(tile(3)).checkInOpen, isFalse);
      expect(tester.widget<JuniorMapNodeTile>(tile(3)).onTap, isNull);
      await tapTile(tester, 3);

      expect(find.byType(LessonListScreen), findsNothing);
      expect(find.byType(AttendanceScannerScreen), findsNothing);
      expect(learning.lessonCalls, isEmpty);
      expect(find.byType(JuniorLearningMapView), findsOneWidget);
    });

    testWidgets('the QR node with check-in open opens the scanner, not the '
        'lessons (Issue #207)', (tester) async {
      final learning = course();
      final open = map();
      await pumpHome(
        tester,
        learning: learning,
        learningMap: JuniorLearningMap(
          courseSlug: open.courseSlug,
          progress: open.progress,
          certificate: open.certificate,
          nodes: open.nodes,
          continueModuleId: open.continueModuleId,
          nextLesson: NextLesson(
            startsAt: DateTime(2026, 10, 6, 11),
            endsAt: DateTime(2026, 10, 6, 13),
          ),
        ),
      );

      await tapTile(tester, 3);

      expect(find.byType(AttendanceScannerScreen), findsOneWidget);
      expect(learning.lessonCalls, isEmpty);
    });

    testWidgets('the course card opens the existing Course Detail, without '
        'notes (Issue #207)', (tester) async {
      final learning = course();
      await pumpHome(tester, learning: learning);

      await tester.tap(find.byType(JuniorCourseProgressCard));
      await tester.pumpAndSettle();

      final detail = tester.widget<CourseModuleListScreen>(
        find.byType(CourseModuleListScreen),
      );
      expect(detail.courseSlug, slug);
      expect(detail.showNotes, isFalse);
      // The same `GET /me/courses/{slug}/learning` contract.
      expect(learning.calls, [slug]);
      expect(learning.lessonCalls, isEmpty);

      await tester.tap(find.bySemanticsLabel(CourseLearningStrings.back));
      await tester.pumpAndSettle();
      expect(find.byType(JuniorLearningMapView), findsOneWidget);
    });

    testWidgets('a locked node stays inert', (tester) async {
      final learning = course();
      await pumpHome(tester, learning: learning);

      expect(tester.widget<JuniorMapNodeTile>(tile(4)).onTap, isNull);
      await tapTile(tester, 4);

      expect(find.byType(LessonListScreen), findsNothing);
      expect(learning.lessonCalls, isEmpty);
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
      await tapTile(tester, 1);
      expect(find.byType(LessonListScreen), findsNothing);
      // …and the course card too.
      await tester.tap(find.byType(JuniorCourseProgressCard));
      await tester.pumpAndSettle();
      expect(find.byType(CourseModuleListScreen), findsNothing);
    });

    testWidgets('a lesson opened from a node has no Note tab', (tester) async {
      final learning = course();
      await pumpHome(tester, learning: learning);
      await tapTile(tester, 2);
      await tester.tap(find.text('Nesting loops'));
      await tester.pumpAndSettle();

      final exercise = tester.widget<CourseExerciseDetailScreen>(
        find.byType(CourseExerciseDetailScreen),
      );
      expect(exercise.showNotes, isFalse);
      expect(find.text(CourseLearningStrings.noteTab), findsNothing);
    });

    testWidgets('back from a module returns to Junior Home', (tester) async {
      await pumpHome(tester, learning: course());
      await tapTile(tester, 1);

      await tester.tap(find.bySemanticsLabel(CourseLearningStrings.back));
      await tester.pumpAndSettle();

      expect(find.byType(LessonListScreen), findsNothing);
      expect(find.byType(JuniorLearningMapView), findsOneWidget);
    });

    testWidgets('unlocked nodes are announced as buttons', (tester) async {
      await pumpHome(tester, learning: course());

      final completed = tester.getSemantics(tile(1));
      expect(completed.flagsCollection.isButton, isTrue);
      // The closed check-in node is inert, so not a button (Issue #207).
      expect(tester.getSemantics(tile(3)).flagsCollection.isButton, isFalse);
      final locked = tester.getSemantics(tile(4));
      expect(locked.flagsCollection.isButton, isFalse);
    });
  });

  group('Junior Course Detail', () {
    Future<void> pumpDetail(
      WidgetTester tester,
      FakeCourseLearningRepository learning,
    ) async {
      useLogicalViewport(tester, const Size(393, 1400), padding: iPhonePadding);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CourseModuleListScreen(
            courseSlug: slug,
            repository: learning,
            showNotes: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('draws the course from the learning path', (tester) async {
      await pumpDetail(tester, course());

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
      await pumpDetail(tester, learning);

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
      await pumpDetail(tester, learning);
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
        await pumpDetail(tester, learning);

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
