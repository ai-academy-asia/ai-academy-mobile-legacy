import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/attendance/domain/course_attendance.dart';
import 'package:aia_mobile/features/attendance/presentation/attendance_scanner_screen.dart';
import 'package:aia_mobile/features/course_learning/domain/course_exercise.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/domain/lesson_note_completion.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/lesson_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/exercise_submit_button.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/lesson_list_item.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/junior_home/data/api_junior_home_repository.dart';
import 'package:aia_mobile/features/junior_home/data/sample_junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_home_repository.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_learning_map_view.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_node.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_path_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../attendance/fake_attendance_repository.dart';
import '../course_learning/fake_course_learning_repository.dart';
import '../home/fake_home_dashboard_repository.dart' hide sampleLesson;

/// The approved four-state lesson model (Issue #415): LOCKED,
/// CHECK_IN_REQUIRED, ATTENDANCE_COMPLETED, LESSON_COMPLETED — completion
/// from a saved, non-empty note read back from the backend, attendance
/// from the backend only. No backend is called; nothing is fabricated.
void main() {
  setUpAll(loadAppFonts);

  group('the four states, derived', () {
    LessonPathState of({
      bool note = false,
      bool? attended,
      bool? date,
      bool? checkIn,
    }) => lessonPathStateFor(
      hasSavedNote: note,
      attendanceConfirmed: attended,
      classDateArrived: date,
      checkInActive: checkIn,
    );

    test('LOCKED until its class date and an open check-in', () {
      expect(of(), LessonPathState.locked);
      expect(of(date: false, checkIn: true), LessonPathState.locked);
      expect(of(date: true, checkIn: false), LessonPathState.locked);
      expect(of(date: true, checkIn: true), LessonPathState.checkInRequired);
    });

    test('LOCKED → CHECK_IN_REQUIRED → ATTENDANCE_COMPLETED → '
        'LESSON_COMPLETED, each on a backend-confirmed fact', () {
      expect(of(date: false), LessonPathState.locked);
      expect(of(date: true, checkIn: true), LessonPathState.checkInRequired);
      expect(
        of(date: true, checkIn: true, attended: true),
        LessonPathState.attendanceCompleted,
      );
      expect(
        of(date: true, checkIn: false, attended: true, note: true),
        LessonPathState.lessonCompleted,
      );
    });

    test('unknown is never success: missing attendance or schedule data is '
        'LOCKED, not attended', () {
      expect(
        of(attended: null, date: null, checkIn: null),
        LessonPathState.locked,
      );
      expect(
        of(attended: false, date: true, checkIn: true),
        LessonPathState.checkInRequired,
      );
    });

    test('a note gone again falls back to ATTENDANCE_COMPLETED while '
        'attendance stays confirmed — or LOCKED without it', () {
      expect(of(note: true, attended: true), LessonPathState.lessonCompleted);
      expect(
        of(note: false, attended: true),
        LessonPathState.attendanceCompleted,
      );
      expect(of(note: false, attended: null), LessonPathState.locked);
    });

    test('taps: nothing while locked, the scanner on check-in, the lesson '
        'once attended or completed — unless the server locks it', () {
      expect(
        lessonPathTap(LessonPathState.locked, serverLocked: false),
        LessonPathTap.nothing,
      );
      expect(
        lessonPathTap(LessonPathState.checkInRequired, serverLocked: false),
        LessonPathTap.scanner,
      );
      for (final state in [
        LessonPathState.attendanceCompleted,
        LessonPathState.lessonCompleted,
      ]) {
        expect(lessonPathTap(state, serverLocked: false), LessonPathTap.lesson);
        expect(lessonPathTap(state, serverLocked: true), LessonPathTap.nothing);
      }
    });

    test('each state\'s node on the map', () {
      expect(
        juniorNodeStateOf(LessonPathState.lessonCompleted),
        JuniorNodeState.completed,
      );
      expect(
        juniorNodeStateOf(LessonPathState.attendanceCompleted),
        JuniorNodeState.attendanceCompleted,
      );
      expect(
        juniorNodeStateOf(LessonPathState.checkInRequired),
        JuniorNodeState.checkInRequired,
      );
      expect(juniorNodeStateOf(LessonPathState.locked), JuniorNodeState.locked);
    });
  });

  group('completion is a saved, non-empty note', () {
    CourseExerciseNote note(String message) => sampleNote(message: message);

    test('a missing, empty or blank note completes nothing', () {
      expect(noteCompletesLesson(null), isFalse);
      expect(noteCompletesLesson(note('')), isFalse);
      expect(noteCompletesLesson(note('  \n ')), isFalse);
      expect(noteCompletesLesson(note('Base case first')), isTrue);
    });

    test('reads only unlocked lessons; a lesson that answers locked is not '
        'completed; any other failure fails the read', () async {
      final repository = FakeCourseLearningRepository(
        notesByLesson: {1: note('done'), 2: note(' ')},
      );
      expect(
        await lessonsCompletedByNote(repository, [
          (id: 1, locked: false),
          (id: 2, locked: false),
          (id: 3, locked: false),
          (id: 4, locked: true),
        ]),
        {1},
      );
      expect(repository.noteCalls..sort(), [1, 2, 3]);

      repository.noteFailure = const CourseLearningFailure(
        CourseLearningFailureKind.locked,
      );
      expect(
        await lessonsCompletedByNote(repository, [(id: 1, locked: false)]),
        isEmpty,
      );

      repository.noteFailure = const CourseLearningFailure(
        CourseLearningFailureKind.network,
      );
      await expectLater(
        lessonsCompletedByNote(repository, [(id: 1, locked: false)]),
        throwsA(isA<CourseLearningFailure>()),
      );
    });
  });

  group('the attendance-completed node', () {
    Future<void> pumpTile(WidgetTester tester, JuniorMapNode node) async {
      useLogicalViewport(tester, const Size(200, 200));
      useReducedMotion(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Center(
            child: SizedBox.square(
              dimension: 84,
              child: JuniorMapNodeTile(
                node: node,
                number: 1,
                scale: 1,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
    }

    BoxDecoration decorationOf(WidgetTester tester) =>
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byType(JuniorMapNodeTile),
                    matching: find.byType(Container),
                  ),
                )
                .decoration!
            as BoxDecoration;
    Image imageOf(WidgetTester tester) => tester.widget<Image>(
      find.descendant(
        of: find.byType(JuniorMapNodeTile),
        matching: find.byType(Image),
      ),
    );

    testWidgets('the completed node\'s geometry and tick, every colour grey: '
        'the padlock\'s face, outline and ink', (tester) async {
      await pumpTile(
        tester,
        const JuniorMapNode(id: 1, state: JuniorNodeState.attendanceCompleted),
      );
      final palette = tester.element(find.byType(JuniorMapNodeTile)).palette;
      final attended = decorationOf(tester);
      final tick = imageOf(tester);
      final size = tester.getSize(find.byType(JuniorMapNodeTile));

      expect(attended.color, palette.juniorMutedFill);
      expect((attended.border! as Border).top.color, palette.outline);
      expect(attended.boxShadow!.single.color, palette.outline);
      expect((tick.image as AssetImage).assetName, endsWith('node_check.png'));
      expect(tick.color, palette.juniorMutedGlyph);
      expect(tick.colorBlendMode, BlendMode.srcIn);
      expect(
        find.bySemanticsLabel('Lesson 1, attendance recorded'),
        findsOneWidget,
      );

      // Same geometry as a completed node — only the colours differ.
      await pumpTile(
        tester,
        const JuniorMapNode(id: 1, state: JuniorNodeState.completed),
      );
      final completed = decorationOf(tester);
      expect(tester.getSize(find.byType(JuniorMapNodeTile)), size);
      expect(completed.borderRadius, attended.borderRadius);
      expect(
        (completed.border! as Border).top.width,
        (attended.border! as Border).top.width,
      );
      expect(
        completed.boxShadow!.single.offset,
        attended.boxShadow!.single.offset,
      );
      expect(imageOf(tester).color, isNull);
      expect(imageOf(tester).width, tick.width);
    });

    test('opens — attended lessons open — unless the server locks it', () {
      expect(
        const JuniorMapNode(
          id: 1,
          state: JuniorNodeState.attendanceCompleted,
        ).opens,
        isTrue,
      );
      expect(
        const JuniorMapNode(
          id: 1,
          state: JuniorNodeState.attendanceCompleted,
          locked: true,
        ).opens,
        isFalse,
      );
    });

    testWidgets('its outgoing stretch is white — blue only leaves a completed '
        'lesson', (tester) async {
      useLogicalViewport(tester, const Size(393, 2400));
      useReducedMotion(tester);
      final sample = sampleJuniorLearningMap();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: JuniorLearningMapView(
              map: JuniorLearningMap(
                progress: sample.progress,
                certificate: sample.certificate,
                nodes: const [
                  JuniorMapNode(id: 1, state: JuniorNodeState.completed),
                  JuniorMapNode(
                    id: 2,
                    state: JuniorNodeState.attendanceCompleted,
                  ),
                  JuniorMapNode(id: 3, state: JuniorNodeState.locked),
                ],
              ),
              now: DateTime(2026, 10, 7),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final route = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is JuniorMapPathPainter,
      );
      final palette = tester.element(route).palette;

      expect(
        tester.renderObject(route),
        paints
          ..path(color: palette.accent)
          ..path(color: palette.surface)
          ..path(color: palette.surface),
      );
    });
  });

  group('on Junior Home, against the backend\'s persisted notes', () {
    const slug = 'junior-ai';

    /// Module 1 open (lessons 101, 102; the server's continue lesson 101),
    /// module 2 locked (201).
    FakeCourseLearningRepository learningFor({
      Map<int, CourseExerciseNote> notes = const {},
      bool serverCompleted101 = false,
    }) => FakeCourseLearningRepository(
      exercise: sampleExercise(note: null, simulatesWrites: false),
      notesByLesson: {...notes},
      path: samplePath(
        courseSlug: slug,
        percentComplete: 40,
        continueModuleId: 1,
        continueLessonId: 101,
        modules: [
          sampleModule(id: 1, order: 1),
          sampleModule(id: 2, order: 2, locked: true),
        ],
      ),
      lessonsByModule: {
        1: [
          sampleLesson(
            id: 101,
            moduleId: 1,
            order: 1,
            completed: serverCompleted101,
          ),
          sampleLesson(id: 102, moduleId: 1, order: 2),
        ],
        2: [sampleLesson(id: 201, moduleId: 2, order: 1, locked: true)],
      },
    );

    final liveLesson = NextLesson(
      startsAt: DateTime(2026, 10, 6, 9),
      endsAt: DateTime(2026, 10, 6, 11),
    );

    /// Junior Home over [repository] — the real API repository, or the
    /// controlled attendance fixture.
    Future<void> pumpHome(
      WidgetTester tester,
      FakeCourseLearningRepository learning, {
      JuniorHomeRepository? repository,
      DateTime? now,
    }) async {
      useLogicalViewport(tester, const Size(393, 1400), padding: iPhonePadding);
      useReducedMotion(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: JuniorHomeScreen(
            key: UniqueKey(),
            repository:
                repository ??
                ApiJuniorHomeRepository(
                  dashboardRepository: FakeHomeDashboardRepository(
                    dashboard: HomeDashboard(
                      program: sampleProgram(
                        courseSlug: slug,
                        nextLesson: liveLesson,
                      ),
                    ),
                  ),
                  courseLearningRepository: learning,
                  attendanceRepository: FakeAttendanceRepository(
                    attendance: CourseAttendance(
                      attended: 0,
                      totalPast: 0,
                      percent: 0,
                      sessions: [
                        AttendanceSession(
                          date: DateTime(2026, 10, 6),
                          status: null,
                        ),
                      ],
                    ),
                  ),
                ),
            courseLearningRepository: learning,
            clock: () => now ?? DateTime(2026, 10, 6, 12),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder tile(int id) => find.byWidgetPredicate(
      (w) => w is JuniorMapNodeTile && w.node.id == id,
    );
    JuniorNodeState stateOf(WidgetTester tester, int id) =>
        tester.widget<JuniorMapNodeTile>(tile(id)).node.state;

    Future<void> saveNote(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField).first, text);
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ExerciseSubmitButton, CourseLearningStrings.submit),
      );
      await tester.pumpAndSettle();
    }

    Future<void> back(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel(CourseLearningStrings.back));
      await tester.pumpAndSettle();
    }

    testWidgets('the server\'s completed flag alone completes nothing; a '
        'saved note does — and the server\'s percentage stays', (tester) async {
      await pumpHome(tester, learningFor(serverCompleted101: true));
      expect(stateOf(tester, 101), JuniorNodeState.locked);
      expect(find.text('40%'), findsOneWidget);

      await pumpHome(tester, learningFor(notes: {102: sampleNote()}));
      expect(stateOf(tester, 102), JuniorNodeState.completed);
      expect(find.text('40%'), findsOneWidget);
    });

    testWidgets('without attendance the lesson to continue with is LOCKED and '
        'opens nothing — no lesson screen, no request (Issue #417)', (
      tester,
    ) async {
      final learning = learningFor();
      await pumpHome(tester, learning);

      expect(stateOf(tester, 101), JuniorNodeState.locked);
      expect(tester.widget<JuniorMapNodeTile>(tile(101)).onTap, isNull);
      await tester.tap(tile(101));
      await tester.pumpAndSettle();
      expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      expect(learning.exerciseCalls, isEmpty);
    });

    group('an attended lesson (controlled fixture: the backend sends no '
        'per-lesson attendance yet, #414)', () {
      _AttendedFixture fixture(FakeCourseLearningRepository learning) =>
          _AttendedFixture(learning, slug: slug, attended: {101});

      testWidgets('shows ATTENDANCE_COMPLETED and opens; a note saved there '
          'makes it LESSON_COMPLETED on return, its stretch blue — no '
          'completion call', (tester) async {
        final learning = learningFor();
        await pumpHome(tester, learning, repository: fixture(learning));
        expect(stateOf(tester, 101), JuniorNodeState.attendanceCompleted);

        await tester.tap(tile(101));
        await tester.pumpAndSettle();
        expect(find.byType(CourseExerciseDetailScreen), findsOneWidget);
        await saveNote(tester, 'Base case first');
        expect(learning.saveCalls, [(101, 'Base case first')]);
        await back(tester);

        expect(stateOf(tester, 101), JuniorNodeState.completed);
        final painter =
            tester
                    .widget<CustomPaint>(
                      find.byWidgetPredicate(
                        (w) =>
                            w is CustomPaint &&
                            w.painter is JuniorMapPathPainter,
                      ),
                    )
                    .painter!
                as JuniorMapPathPainter;
        expect(painter.connectors.first.active, isTrue);
        expect(learning.completeCalls, isEmpty);
      });

      testWidgets('opening it alone completes nothing', (tester) async {
        final learning = learningFor();
        await pumpHome(tester, learning, repository: fixture(learning));

        await tester.tap(tile(101));
        await tester.pumpAndSettle();
        await back(tester);

        expect(stateOf(tester, 101), JuniorNodeState.attendanceCompleted);
        expect(learning.completeCalls, isEmpty);
        expect(learning.saveCalls, isEmpty);
      });

      testWidgets('a failed note save completes nothing', (tester) async {
        final learning = learningFor()
          ..saveFailure = const CourseLearningFailure(
            CourseLearningFailureKind.network,
          );
        await pumpHome(tester, learning, repository: fixture(learning));

        await tester.tap(tile(101));
        await tester.pumpAndSettle();
        await saveNote(tester, 'Lost on the way');
        await back(tester);

        expect(stateOf(tester, 101), JuniorNodeState.attendanceCompleted);
        expect(learning.notesByLesson, isEmpty);
      });

      testWidgets('an empty note is never saved, so completes nothing', (
        tester,
      ) async {
        final learning = learningFor();
        await pumpHome(tester, learning, repository: fixture(learning));

        await tester.tap(tile(101));
        await tester.pumpAndSettle();
        await saveNote(tester, '   ');
        await back(tester);

        expect(learning.notesByLesson, isEmpty);
        expect(stateOf(tester, 101), JuniorNodeState.attendanceCompleted);
      });
    });

    testWidgets('a failed note read fails the map with retry — never a '
        'guessed state', (tester) async {
      final learning = learningFor()
        ..noteFailure = const CourseLearningFailure(
          CourseLearningFailureKind.network,
        );
      await pumpHome(tester, learning);

      expect(find.byType(JuniorMapNodeTile), findsNothing);
      expect(find.text(JuniorHomeStrings.retry), findsOneWidget);
    });

    testWidgets('the locked module\'s lesson is never read and never opens', (
      tester,
    ) async {
      final learning = learningFor(notes: {201: sampleNote()});
      await pumpHome(tester, learning);

      expect(stateOf(tester, 201), JuniorNodeState.locked);
      expect(learning.noteCalls, isNot(contains(201)));
      expect(tester.widget<JuniorMapNodeTile>(tile(201)).onTap, isNull);
    });

    testWidgets('CHECK_IN_REQUIRED during the class; a check-in that fails '
        'records nothing: back from the scanner it is still required', (
      tester,
    ) async {
      final learning = learningFor();
      await pumpHome(tester, learning, now: DateTime(2026, 10, 6, 10));
      expect(tester.widget<JuniorMapNodeTile>(tile(101)).checkIn, isTrue);

      await tester.tap(tile(101));
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceScannerScreen), findsOneWidget);
      // No attendance was recorded (the scan failed): the backend still
      // answers no record for the day.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      expect(tester.widget<JuniorMapNodeTile>(tile(101)).checkIn, isTrue);
      expect(stateOf(tester, 101), JuniorNodeState.locked);
      expect(learning.completeCalls, isEmpty);
    });
  });

  testWidgets('the Lesson List: a note saved in a lesson shows on return', (
    tester,
  ) async {
    final learning = FakeCourseLearningRepository(
      exercise: sampleExercise(note: null, simulatesWrites: false),
      lessons: [
        sampleLesson(id: 51, moduleId: 5, order: 1, title: 'First'),
        sampleLesson(id: 52, moduleId: 5, order: 2, title: 'Second'),
      ],
    );
    useLogicalViewport(tester, const Size(393, 1400), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LessonListScreen(
          moduleId: 5,
          moduleOrder: 1,
          moduleTitle: 'Module',
          repository: learning,
          resumeLessonId: 51,
        ),
      ),
    );
    await tester.pumpAndSettle();
    LessonListItem row(String title) => tester.widget<LessonListItem>(
      find.widgetWithText(LessonListItem, title),
    );
    expect(row('First').lesson.completed, isFalse);

    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Done reading');
    await tester.pump();
    await tester.tap(
      find.widgetWithText(ExerciseSubmitButton, CourseLearningStrings.submit),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(CourseLearningStrings.back));
    await tester.pumpAndSettle();

    expect(row('First').lesson.completed, isTrue);
    expect(row('Second').lesson.completed, isFalse);
    expect(learning.completeCalls, isEmpty);
  });
}

/// A controlled fixture standing in for the backend's per-lesson attendance,
/// which does not exist yet (#414): the same lessons, notes and mapper as
/// [ApiJuniorHomeRepository], with [attended] given as backend-confirmed.
/// Tests only — the app never fabricates attendance.
class _AttendedFixture implements JuniorHomeRepository {
  _AttendedFixture(this.learning, {required this.slug, required this.attended});

  final FakeCourseLearningRepository learning;
  final String slug;
  final Set<int> attended;

  @override
  Future<JuniorLearningMap?> getLearningMap() async {
    final path = await learning.getCourseLearning(slug);
    final lessons = {
      for (final module in path.modules)
        module.id: await learning.getLessons(module.id),
    };
    final completedByNote = await lessonsCompletedByNote(learning, [
      for (final module in path.modules)
        for (final lesson in lessons[module.id]!)
          (id: lesson.id, locked: lesson.locked || module.locked),
    ]);
    return juniorMapFrom(
      path,
      lessons: lessons,
      completedByNote: completedByNote,
      attendedLessonIds: attended,
    );
  }
}
