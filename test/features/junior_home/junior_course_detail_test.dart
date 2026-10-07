import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/domain/course_exercise.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/lesson_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/assignment_tab.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_materials_tab.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/exercise_submit_button.dart';
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

/// The Junior course-learning screens: the Adult screens, with the same
/// lesson tabs — Note, Course materials, Assignment (Issue #219, superseding
/// #174's Junior-only "no notes").
///
/// From Junior Home, a node opens **its own module's** lessons (Issue #204)
/// — not the course as a whole. The course screen and a Junior lesson's
/// whole learning flow are tested here directly.
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

  /// The lesson's tab card reads Note | Course materials | Assignment, left
  /// to right — the order Adult has too (Issue #219).
  void expectTabOrder(WidgetTester tester) {
    final note = tester.getCenter(find.text(CourseLearningStrings.noteTab));
    final materials = tester.getCenter(
      find.text(CourseLearningStrings.courseMaterialsTab),
    );
    final assignment = tester.getCenter(
      find.text(CourseLearningStrings.assignmentTab),
    );
    expect(note.dx, lessThan(materials.dx));
    expect(materials.dx, lessThan(assignment.dx));
  }

  group('the Junior Home entry point', () {
    for (final (id, title) in [
      (1, 'Prediction and Probabilities'),
      (2, 'Language Model Training'),
    ]) {
      testWidgets('completed node $id opens module $id\'s lessons '
          '(Issues #204, #207)', (tester) async {
        final learning = course();
        await pumpHome(tester, learning: learning);

        await tapTile(tester, id);

        final lessons = tester.widget<LessonListScreen>(
          find.byType(LessonListScreen),
        );
        expect(lessons.moduleId, id);
        expect(lessons.moduleTitle, title);
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

    testWidgets('the course card opens the existing Course Detail '
        '(Issue #207)', (tester) async {
      final learning = course();
      await pumpHome(tester, learning: learning);

      await tester.tap(find.byType(JuniorCourseProgressCard));
      await tester.pumpAndSettle();

      final detail = tester.widget<CourseModuleListScreen>(
        find.byType(CourseModuleListScreen),
      );
      expect(detail.courseSlug, slug);
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

    testWidgets('a lesson opened from a node offers Note, Course materials '
        'and Assignment, Note first (Issue #219)', (tester) async {
      final learning = course();
      await pumpHome(tester, learning: learning);
      await tapTile(tester, 2);
      await tester.tap(find.text('Nesting loops'));
      await tester.pumpAndSettle();

      expectTabOrder(tester);
      expect(find.byType(NoteTab), findsOneWidget);
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
          home: CourseModuleListScreen(courseSlug: slug, repository: learning),
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

    testWidgets('a module opens its lessons, and a locked module does '
        'nothing', (tester) async {
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
      expect(learning.lessonCalls, [2]);
    });

    /// A backend lesson (real writes) with a note, an assignment and a quiz.
    FakeCourseLearningRepository backendCourse() =>
        FakeCourseLearningRepository(
          path: samplePath(
            courseSlug: slug,
            courseTitle: 'AI BootCamp',
            continueModuleId: 2,
            continueLessonId: 2,
          ),
          lessons: sampleLessons(),
          exercise: sampleExercise(
            simulatesWrites: false,
            assignment: const CourseAssignment(id: 17),
            quiz: sampleQuiz(id: 9),
          ),
        )..savedNote = sampleNote(message: 'Saved on the server.');

    Future<void> openLesson(WidgetTester tester) async {
      await tester.tap(find.text('Language Model Training'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nesting loops'));
      await tester.pumpAndSettle();
    }

    Future<void> openTab(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('a lesson\'s tab card is Note | Course materials | '
        'Assignment, and opens on Note with the lesson\'s note', (
      tester,
    ) async {
      final learning = course();
      await pumpDetail(tester, learning);
      await openLesson(tester);

      expect(
        tester
            .widget<CourseExerciseDetailScreen>(
              find.byType(CourseExerciseDetailScreen),
            )
            .lessonId,
        2,
      );
      expect(learning.exerciseCalls, [2]);
      expectTabOrder(tester);
      // The note that arrived with the lesson, drawn as Adult draws it.
      expect(find.byType(NoteTab), findsOneWidget);
      expect(find.text(sampleNote().message), findsOneWidget);
    });

    testWidgets('a Junior note is saved through the same saveNote', (
      tester,
    ) async {
      final learning = backendCourse();
      await pumpDetail(tester, learning);
      await openLesson(tester);

      await tester.tap(find.text(CourseLearningStrings.editNote));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Миний тэмдэглэл');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ExerciseSubmitButton, CourseLearningStrings.submit),
      );
      await tester.pumpAndSettle();

      // `PUT /me/lessons/{lesson_id}/note`, keyed by the lesson.
      expect(learning.saveCalls, [(2, 'Миний тэмдэглэл')]);
      expect(find.text('Saved on the server.'), findsOneWidget);
    });

    testWidgets('switching tabs shows each tab\'s own content, and a saved '
        'note survives the round trip', (tester) async {
      final learning = backendCourse();
      await pumpDetail(tester, learning);
      await openLesson(tester);

      await tester.tap(find.text(CourseLearningStrings.editNote));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Миний тэмдэглэл');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ExerciseSubmitButton, CourseLearningStrings.submit),
      );
      await tester.pumpAndSettle();

      await openTab(tester, CourseLearningStrings.courseMaterialsTab);
      expect(find.byType(CourseMaterialsTab), findsOneWidget);
      expect(find.byType(NoteTab), findsNothing);

      await openTab(tester, CourseLearningStrings.assignmentTab);
      expect(find.byType(AssignmentTab), findsOneWidget);
      expect(find.byType(CourseMaterialsTab), findsNothing);

      await openTab(tester, CourseLearningStrings.noteTab);
      expect(find.byType(NoteTab), findsOneWidget);
      expect(find.text('Saved on the server.'), findsOneWidget);
    });

    testWidgets('a Junior assignment is submitted through the same '
        'submitAssignment', (tester) async {
      final learning = backendCourse();
      await pumpDetail(tester, learning);
      await openLesson(tester);
      await openTab(tester, CourseLearningStrings.assignmentTab);

      await tester.enterText(
        find.byType(TextField).first,
        'https://github.com/junior/loops',
      );
      await tester.pump();
      await tester.ensureVisible(
        find.widgetWithText(ExerciseSubmitButton, CourseLearningStrings.submit),
      );
      await tester.tap(
        find.widgetWithText(ExerciseSubmitButton, CourseLearningStrings.submit),
      );
      await tester.pumpAndSettle();

      expect(learning.submitCalls, [
        (17, 'https://github.com/junior/loops', null),
      ]);
    });

    testWidgets('a Junior lesson\'s quiz starts as Adult\'s does', (
      tester,
    ) async {
      final learning = backendCourse();
      await pumpDetail(tester, learning);
      await openLesson(tester);

      await tester.ensureVisible(find.text(CourseLearningStrings.startQuiz));
      await tester.tap(find.text(CourseLearningStrings.startQuiz));
      await tester.pumpAndSettle();

      expect(learning.startQuizCalls, [9]);
    });

    testWidgets('"Continue learning" opens the server\'s lesson, Note first', (
      tester,
    ) async {
      final learning = course();
      await pumpDetail(tester, learning);

      await tester.tap(find.text(CourseLearningStrings.continueLearning).first);
      await tester.pumpAndSettle();

      final exercise = tester.widget<CourseExerciseDetailScreen>(
        find.byType(CourseExerciseDetailScreen),
      );
      expect(exercise.lessonId, 2);
      expectTabOrder(tester);
      expect(find.byType(NoteTab), findsOneWidget);
    });
  });

  group('Adult Course Detail', () {
    testWidgets('a lesson offers the same tabs in the same order, and every '
        'tab opens its own content', (tester) async {
      final learning = course();
      useLogicalViewport(tester, const Size(393, 1400), padding: iPhonePadding);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CourseModuleListScreen(courseSlug: slug, repository: learning),
        ),
      );
      await tester.pumpAndSettle();

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
      expectTabOrder(tester);
      // Note first, as Junior.
      expect(find.byType(NoteTab), findsOneWidget);

      for (final (label, content) in [
        (CourseLearningStrings.courseMaterialsTab, CourseMaterialsTab),
        (CourseLearningStrings.assignmentTab, AssignmentTab),
        (CourseLearningStrings.noteTab, NoteTab),
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.byType(content), findsOneWidget, reason: label);
      }
    });
  });
}
