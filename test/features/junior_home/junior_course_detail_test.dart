import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/domain/course_exercise.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/lesson_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_module_card.dart';
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
/// From Junior Home, a node opens **its own lesson** directly (Issue #410,
/// superseding #204's module screen) — never the course as a whole. The course screen and a Junior lesson's
/// whole learning flow are tested here directly.
void main() {
  setUpAll(loadAppFonts);

  const slug = 'junior-ai-summer-10-14';

  /// Four lessons of the course, one node each: two completed, the open
  /// one the server resumes at, one locked. [live] puts a lesson under way
  /// at the pumped clock; [states] overrides a lesson's state.
  JuniorLearningMap map({
    String? courseSlug = slug,
    bool live = false,
    bool? attendanceRecorded = false,
    Map<int, JuniorNodeState> states = const {},
  }) => JuniorLearningMap(
    courseSlug: courseSlug,
    progress: const JuniorCourseProgress(
      title: 'AI BootCamp',
      percentComplete: 30,
    ),
    nodes: [
      for (final (id, state, title) in const [
        (201, JuniorNodeState.completed, 'Introduction to loops'),
        (202, JuniorNodeState.completed, 'Nesting loops'),
        (203, JuniorNodeState.current, 'Practice: matrix traversal'),
        (204, JuniorNodeState.locked, 'Transformers'),
      ])
        JuniorMapNode(
          id: id,
          state: states[id] ?? state,
          title: title,
          moduleId: 2,
          moduleOrder: 2,
        ),
    ],
    continueModuleId: 2,
    continueLessonId: 203,
    nextLesson: live
        ? NextLesson(
            startsAt: DateTime(2026, 10, 6, 11),
            endsAt: DateTime(2026, 10, 6, 13),
          )
        : null,
    attendanceRecorded: attendanceRecorded,
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
    FakeJuniorHomeRepository? home,
  }) async {
    useLogicalViewport(tester, const Size(393, 1400), padding: iPhonePadding);
    useReducedMotion(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: JuniorHomeScreen(
          repository:
              home ?? FakeJuniorHomeRepository(map: learningMap ?? map()),
          courseLearningRepository: learning,
          // Inside `map(live: true)`'s lesson; outside any other.
          clock: () => DateTime(2026, 10, 6, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The node standing for lesson [id].
  Finder tile(int id) =>
      find.byWidgetPredicate((w) => w is JuniorMapNodeTile && w.node.id == id);

  Future<void> tapTile(WidgetTester tester, int id) async {
    await tester.tap(tile(id));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel(CourseLearningStrings.back));
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
    for (final (id, label) in [
      (201, 'completed'),
      (202, 'completed'),
      (203, 'open'),
    ]) {
      testWidgets('$label lesson $id opens that lesson itself — no module '
          'screen between (Issue #410)', (tester) async {
        final learning = course();
        await pumpHome(tester, learning: learning);

        await tapTile(tester, id);

        final lesson = tester.widget<CourseExerciseDetailScreen>(
          find.byType(CourseExerciseDetailScreen),
        );
        expect(lesson.lessonId, id);
        // `GET /me/lessons/{lesson_id}` for that lesson, and nothing else.
        expect(learning.exerciseCalls, [id]);
        expect(learning.lessonCalls, isEmpty);
        expect(learning.calls, isEmpty);
        expect(find.byType(LessonListScreen), findsNothing);
        expect(find.byType(CourseModuleListScreen), findsNothing);
      });
    }

    testWidgets('different lessons open different lessons, and back returns '
        'to Junior Home', (tester) async {
      final learning = course();
      await pumpHome(tester, learning: learning);

      await tapTile(tester, 201);
      await back(tester);
      expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      expect(find.byType(JuniorLearningMapView), findsOneWidget);
      await tapTile(tester, 202);

      expect(learning.exerciseCalls, [201, 202]);
    });

    testWidgets('back from a lesson reloads the map, so a lesson finished '
        'there shows as completed', (tester) async {
      final home = FakeJuniorHomeRepository(map: map());
      await pumpHome(tester, learning: course(), home: home);
      expect(home.calls, 1);

      await tapTile(tester, 203);
      home.map = map(states: {203: JuniorNodeState.completed});
      await back(tester);

      expect(home.calls, 2);
      expect(
        tester.widget<JuniorMapNodeTile>(tile(203)).node.state,
        JuniorNodeState.completed,
      );
    });

    testWidgets('a locked lesson stays inert', (tester) async {
      final learning = course();
      await pumpHome(tester, learning: learning);

      expect(tester.widget<JuniorMapNodeTile>(tile(204)).onTap, isNull);
      await tapTile(tester, 204);

      expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      expect(find.byType(LessonListScreen), findsNothing);
      expect(learning.exerciseCalls, isEmpty);
      expect(find.byType(JuniorLearningMapView), findsOneWidget);
    });

    testWidgets('a completed lesson the server locks again keeps its tick '
        'and stays inert — no request it would refuse', (tester) async {
      final learning = course();
      final base = map();
      await pumpHome(
        tester,
        learning: learning,
        learningMap: JuniorLearningMap(
          courseSlug: base.courseSlug,
          progress: base.progress,
          certificate: base.certificate,
          nodes: [
            for (final node in base.nodes)
              node.id == 201
                  ? JuniorMapNode(
                      id: node.id,
                      state: JuniorNodeState.completed,
                      title: node.title,
                      locked: true,
                    )
                  : node,
          ],
        ),
      );

      final tile201 = tester.widget<JuniorMapNodeTile>(tile(201));
      expect(tile201.node.state, JuniorNodeState.completed);
      expect(tile201.onTap, isNull);
      await tapTile(tester, 201);
      expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      expect(learning.exerciseCalls, isEmpty);
    });

    testWidgets('outside a lesson the check-in node is just its lesson', (
      tester,
    ) async {
      final learning = course();
      await pumpHome(tester, learning: learning);

      expect(tester.widget<JuniorMapNodeTile>(tile(203)).checkIn, isFalse);
      await tapTile(tester, 203);

      expect(find.byType(AttendanceScannerScreen), findsNothing);
      expect(learning.exerciseCalls, [203]);
    });

    testWidgets('with check-in open, the node opens the scanner, not the '
        'lesson (Issues #207, #410)', (tester) async {
      final learning = course();
      await pumpHome(tester, learning: learning, learningMap: map(live: true));

      expect(tester.widget<JuniorMapNodeTile>(tile(203)).checkIn, isTrue);
      await tapTile(tester, 203);

      expect(find.byType(AttendanceScannerScreen), findsOneWidget);
      expect(learning.exerciseCalls, isEmpty);
    });

    testWidgets('with attendance already recorded, the node is no longer '
        'check-in: it opens its lesson', (tester) async {
      final learning = course();
      await pumpHome(
        tester,
        learning: learning,
        learningMap: map(live: true, attendanceRecorded: true),
      );

      expect(tester.widget<JuniorMapNodeTile>(tile(203)).checkIn, isFalse);
      await tapTile(tester, 203);

      expect(find.byType(AttendanceScannerScreen), findsNothing);
      expect(learning.exerciseCalls, [203]);
    });

    testWidgets('back from the scanner reloads the map, so a recorded '
        'check-in stops the node — and it cannot be scanned twice', (
      tester,
    ) async {
      final home = FakeJuniorHomeRepository(map: map(live: true));
      final learning = course();
      await pumpHome(tester, learning: learning, home: home);

      await tapTile(tester, 203);
      expect(find.byType(AttendanceScannerScreen), findsOneWidget);
      home.map = map(live: true, attendanceRecorded: true);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      expect(home.calls, 2);
      expect(tester.widget<JuniorMapNodeTile>(tile(203)).checkIn, isFalse);
      await tapTile(tester, 203);
      expect(find.byType(AttendanceScannerScreen), findsNothing);
      expect(learning.exerciseCalls, [203]);
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
      // The same `GET /me/courses/{slug}/learning` contract, then every
      // module's lessons for the course-wide lesson list (Issue #437).
      expect(learning.calls, [slug]);
      expect(learning.lessonCalls, [
        for (final module in learning.path!.modules) module.id,
      ]);

      await back(tester);
      expect(find.byType(JuniorLearningMapView), findsOneWidget);
    });

    testWidgets('back from Course Detail reloads the map too — lessons can '
        'be completed there', (tester) async {
      final home = FakeJuniorHomeRepository(map: map());
      await pumpHome(tester, learning: course(), home: home);

      await tester.tap(find.byType(JuniorCourseProgressCard));
      await tester.pumpAndSettle();
      home.map = map(states: {203: JuniorNodeState.completed});
      await back(tester);

      expect(home.calls, 2);
      expect(
        tester.widget<JuniorMapNodeTile>(tile(203)).node.state,
        JuniorNodeState.completed,
      );
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
      await tapTile(tester, 201);
      expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      // …and the course card too.
      await tester.tap(find.byType(JuniorCourseProgressCard));
      await tester.pumpAndSettle();
      expect(find.byType(CourseModuleListScreen), findsNothing);
    });

    testWidgets('a lesson opened from a node offers Note, Course materials '
        'and Assignment, Note first (Issue #219)', (tester) async {
      final learning = course();
      await pumpHome(tester, learning: learning);
      await tapTile(tester, 202);

      expectTabOrder(tester);
      expect(find.byType(NoteTab), findsOneWidget);
    });

    testWidgets('completed and open lessons are announced as buttons, locked '
        'ones are not', (tester) async {
      await pumpHome(tester, learning: course());

      expect(tester.getSemantics(tile(201)).flagsCollection.isButton, isTrue);
      expect(tester.getSemantics(tile(203)).flagsCollection.isButton, isTrue);
      expect(tester.getSemantics(tile(204)).flagsCollection.isButton, isFalse);
    });
  });

  group('Junior Course Detail', () {
    /// Course Detail lists every lesson of the course (Issue #437); here only
    /// module 2 has lessons — its three — so each title and id is the
    /// course's only one, as real lesson data's are.
    Future<void> pumpDetail(
      WidgetTester tester,
      FakeCourseLearningRepository learning,
    ) async {
      learning
        ..lessons = const []
        ..lessonsByModule = {2: sampleLessons()};
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
      // The course's lessons, not its modules (Issue #437).
      expect(find.text('Introduction to loops'), findsOneWidget);
      expect(find.text('Nesting loops'), findsOneWidget);
      expect(find.text('Practice: matrix traversal'), findsOneWidget);
      expect(find.byType(CourseModuleCard), findsNothing);
      expect(
        find.text(CourseLearningStrings.certificationLabel),
        findsOneWidget,
      );
    });

    testWidgets('every lesson is on Course Detail itself: the open ones open '
        'their lesson, a locked one does nothing (Issue #437)', (tester) async {
      final learning = course();
      await pumpDetail(tester, learning);

      expect(learning.lessonCalls, [
        for (final module in learning.path!.modules) module.id,
      ]);
      expect(find.byType(CourseLessonCard), findsNWidgets(3));

      await tester.ensureVisible(find.text('Practice: matrix traversal'));
      await tester.tap(find.text('Practice: matrix traversal'));
      await tester.pumpAndSettle();
      expect(find.byType(CourseExerciseDetailScreen), findsNothing);

      await tester.ensureVisible(find.text('Nesting loops'));
      await tester.tap(find.text('Nesting loops'));
      await tester.pumpAndSettle();
      expect(find.byType(CourseExerciseDetailScreen), findsOneWidget);
      expect(find.byType(LessonListScreen), findsNothing);
      expect(learning.exerciseCalls, [2]);
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
      await tester.ensureVisible(find.text('Nesting loops'));
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
      final learning = course()
        ..lessons = const []
        ..lessonsByModule = {2: sampleLessons()};
      useLogicalViewport(tester, const Size(393, 1400), padding: iPhonePadding);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CourseModuleListScreen(courseSlug: slug, repository: learning),
        ),
      );
      await tester.pumpAndSettle();

      // The lesson is on Course Detail itself (Issue #437).
      await tester.ensureVisible(find.text('Nesting loops'));
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
