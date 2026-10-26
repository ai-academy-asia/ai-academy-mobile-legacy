import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/attendance/domain/course_attendance.dart';
import 'package:aia_mobile/features/attendance/presentation/attendance_scanner_screen.dart';
import 'package:aia_mobile/features/course_learning/domain/course_exercise.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/domain/lesson_note_completion.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/lesson_list_controller.dart';
import 'package:aia_mobile/features/course_learning/presentation/lesson_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/exercise_submit_button.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/lesson_list_item.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/junior_home/data/api_junior_home_repository.dart';
import 'package:aia_mobile/features/junior_home/data/sample_junior_learning_map.dart';
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
        JuniorNodeState.current,
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
        'completed', () async {
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
    });

    // Issue #535 (MOB-08): one lesson's failed read is that lesson's alone.
    for (final kind in [
      CourseLearningFailureKind.network,
      CourseLearningFailureKind.server,
      CourseLearningFailureKind.notFound,
      CourseLearningFailureKind.notEnrolled,
      CourseLearningFailureKind.unexpected,
    ]) {
      test('one lesson\'s ${kind.name} read: that lesson is not completed; '
          'the others keep what their own notes say; a locked one is still '
          'not asked for', () async {
        final repository = FakeCourseLearningRepository(
          notesByLesson: {1: note('done'), 2: note('done'), 3: note('done')},
          noteFailuresByLesson: {2: CourseLearningFailure(kind)},
        );
        expect(
          await lessonsCompletedByNote(repository, [
            (id: 1, locked: false),
            (id: 2, locked: false),
            (id: 3, locked: false),
            (id: 4, locked: true),
          ]),
          {1, 3},
        );
        expect(repository.noteCalls..sort(), [1, 2, 3]);
      });
    }

    test('every read failing completes nothing — and still answers', () async {
      final repository = FakeCourseLearningRepository(
        notesByLesson: {1: note('done')},
        noteFailure: const CourseLearningFailure(
          CourseLearningFailureKind.network,
        ),
      );
      expect(
        await lessonsCompletedByNote(repository, [
          (id: 1, locked: false),
          (id: 2, locked: false),
        ]),
        isEmpty,
      );
    });

    test('a refused session still fails the read as a whole — it is the '
        'student\'s session, not one lesson', () async {
      final repository = FakeCourseLearningRepository(
        notesByLesson: {1: note('done'), 3: note('done')},
        noteFailuresByLesson: {
          2: const CourseLearningFailure(
            CourseLearningFailureKind.sessionExpired,
          ),
        },
      );
      await expectLater(
        lessonsCompletedByNote(repository, [
          (id: 1, locked: false),
          (id: 2, locked: false),
          (id: 3, locked: false),
        ]),
        throwsA(
          isA<CourseLearningFailure>().having(
            (f) => f.kind,
            'kind',
            CourseLearningFailureKind.sessionExpired,
          ),
        ),
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

    testWidgets('attendance confirmed, not completed (Issue #441): the '
        'active frame with the attendance glyph in the accent — never the '
        'tick — on the completed node\'s geometry', (tester) async {
      await pumpTile(
        tester,
        const JuniorMapNode(id: 1, state: JuniorNodeState.attendanceCompleted),
      );
      final palette = tester.element(find.byType(JuniorMapNodeTile)).palette;
      final attended = decorationOf(tester);
      final size = tester.getSize(find.byType(JuniorMapNodeTile));

      expect(attended.color, palette.surface);
      expect((attended.border! as Border).top.color, palette.accent);
      expect(attended.boxShadow!.single.color, palette.accent);
      // The app's attendance glyph, Phosphor "CalendarCheck", in the accent.
      final glyph = tester.widget<Icon>(
        find.descendant(
          of: find.byType(JuniorMapNodeTile),
          matching: find.byType(Icon),
        ),
      );
      expect(glyph.icon, AppIcons.calendarCheck);
      expect(glyph.color, palette.accent);
      // No sprite at all — so no tick.
      expect(
        find.descendant(
          of: find.byType(JuniorMapNodeTile),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
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
      expect(
        (imageOf(tester).image as AssetImage).assetName,
        endsWith('node_check.png'),
      );
      // The glyph weighs as the sprites' ink does: 0.7 of their 48 box.
      expect(glyph.size, closeTo(imageOf(tester).width! * 0.7, 0.01));
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

    Future<void> pumpHome(
      WidgetTester tester,
      FakeCourseLearningRepository learning, {
      DateTime? now,
      CourseAttendance? attendance,
    }) async {
      // One clock for the screen and the repository, and the next lesson
      // production would derive from it (Issue #443).
      final at = now ?? DateTime(2026, 10, 6, 12);
      useLogicalViewport(tester, const Size(393, 1400), padding: iPhonePadding);
      useReducedMotion(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: JuniorHomeScreen(
            key: UniqueKey(),
            repository: ApiJuniorHomeRepository(
              dashboardRepository: FakeHomeDashboardRepository(
                dashboard: HomeDashboard(
                  program: sampleProgram(
                    courseSlug: slug,
                    nextLesson: realisticNextLesson(at),
                  ),
                ),
              ),
              courseLearningRepository: learning,
              clock: () => at,
              attendanceRepository: FakeAttendanceRepository(
                attendance:
                    attendance ??
                    CourseAttendance(
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
            clock: () => at,
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

    /// The continue lesson's class day (6 Oct) with [status] recorded — what
    /// `continueAttendanceConfirmedBy` reads. `present` is what opens the continue
    /// lesson on Junior (Issue #443).
    CourseAttendance attendanceOn6Oct(String? status) => CourseAttendance(
      attended: 0,
      totalPast: 0,
      percent: 0,
      sessions: [
        AttendanceSession(date: DateTime(2026, 10, 6), status: status),
      ],
    );

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
      expect(stateOf(tester, 101), JuniorNodeState.current);
      expect(find.text('40%'), findsOneWidget);

      await pumpHome(tester, learningFor(notes: {102: sampleNote()}));
      expect(stateOf(tester, 102), JuniorNodeState.completed);
      expect(find.text('40%'), findsOneWidget);
    });

    testWidgets('saving a note in the lesson and coming back: ticked, its '
        'stretch blue — by the persisted note, no completion call', (
      tester,
    ) async {
      final learning = learningFor();
      // Attended, so the continue lesson opens (Issue #443).
      await pumpHome(tester, learning, attendance: attendanceOn6Oct('present'));
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
                          w is CustomPaint && w.painter is JuniorMapPathPainter,
                    ),
                  )
                  .painter!
              as JuniorMapPathPainter;
      expect(painter.connectors.first.active, isTrue);
      expect(learning.completeCalls, isEmpty);
    });

    // --- The four Junior states (Issue #441) --------------------------------

    Finder within(int id, Finder matching) =>
        find.descendant(of: tile(id), matching: matching);

    testWidgets('State 3: attendance registered, no completing note — the '
        'attendance glyph, no tick; the node still opens its Lesson Detail '
        'directly', (tester) async {
      final learning = learningFor();
      await pumpHome(tester, learning, attendance: attendanceOn6Oct('present'));

      expect(stateOf(tester, 101), JuniorNodeState.attendanceCompleted);
      expect(within(101, find.byIcon(AppIcons.calendarCheck)), findsOneWidget);
      expect(within(101, find.byType(Image)), findsNothing);

      await tester.tap(tile(101));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CourseExerciseDetailScreen>(
              find.byType(CourseExerciseDetailScreen),
            )
            .lessonId,
        101,
      );
      expect(find.byType(LessonListScreen), findsNothing);
      expect(learning.completeCalls, isEmpty);
    });

    testWidgets('only an attended record counts: late does, absent, excused '
        'and none leave the lesson as it was', (tester) async {
      await pumpHome(
        tester,
        learningFor(),
        attendance: attendanceOn6Oct('late'),
      );
      expect(stateOf(tester, 101), JuniorNodeState.attendanceCompleted);

      for (final status in ['absent', 'excused', null]) {
        await pumpHome(
          tester,
          learningFor(),
          attendance: attendanceOn6Oct(status),
        );
        expect(stateOf(tester, 101), JuniorNodeState.current, reason: status);
      }
    });

    testWidgets('State 4: the lesson list\'s completion rule holds — the tick, '
        'attendance or not', (tester) async {
      await pumpHome(
        tester,
        learningFor(notes: {101: sampleNote()}),
        attendance: attendanceOn6Oct('present'),
      );
      expect(stateOf(tester, 101), JuniorNodeState.completed);
      expect(within(101, find.byIcon(AppIcons.calendarCheck)), findsNothing);
      final tick = tester.widget<Image>(within(101, find.byType(Image)));
      expect((tick.image as AssetImage).assetName, endsWith('node_check.png'));
    });

    testWidgets('completion is exactly the lesson list\'s: the same lessons '
        'are completed on both, note-only lessons included', (tester) async {
      // A saved note; a blank one; the server's own flag without a note; a
      // note on a locked lesson — every case the lesson list's rule decides.
      final learning = learningFor(
        serverCompleted101: true,
        notes: {
          102: sampleNote(),
          101: sampleNote(message: '   '),
          201: sampleNote(),
        },
      );

      final list = LessonListController(repository: learning, moduleId: 1);
      await list.load();
      final listCompleted = {
        for (final lesson in list.lessons)
          if (lesson.completed) lesson.id,
      };
      list.dispose();

      await pumpHome(tester, learning, attendance: attendanceOn6Oct(null));
      final homeCompleted = {
        for (final node in tester.widgetList<JuniorMapNodeTile>(
          find.byType(JuniorMapNodeTile),
        ))
          if (node.node.state == JuniorNodeState.completed) node.node.id,
      };

      expect(listCompleted, {102});
      expect(homeCompleted, listCompleted);
    });

    testWidgets('States 1 and 2 are unchanged: the locked lesson keeps its '
        'padlock, and the live check-in its QR, which opens the scanner', (
      tester,
    ) async {
      await pumpHome(
        tester,
        learningFor(),
        attendance: attendanceOn6Oct(null),
        now: DateTime(2026, 10, 6, 10),
      );

      expect(stateOf(tester, 201), JuniorNodeState.locked);
      final padlock = tester.widget<Image>(within(201, find.byType(Image)));
      expect(
        (padlock.image as AssetImage).assetName,
        endsWith('node_lock.png'),
      );

      final checkIn = tester.widget<JuniorMapNodeTile>(tile(101));
      expect(checkIn.checkIn, isTrue);
      final qr = tester.widget<Image>(within(101, find.byType(Image)));
      expect((qr.image as AssetImage).assetName, endsWith('node_current.png'));
      await tester.tap(tile(101));
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceScannerScreen), findsOneWidget);
    });

    // --- The attendance gate against the backend's own statuses (#443) ---

    /// 6 Oct's class and 13 Oct's, as `GET /me/attendance` lists them.
    CourseAttendance twoClasses(String? sixth, String? thirteenth) =>
        CourseAttendance(
          attended: 0,
          totalPast: 0,
          percent: 0,
          sessions: [
            AttendanceSession(
              date: DateTime(2026, 10, 6),
              status: sixth,
              startTime: '09:00',
            ),
            AttendanceSession(
              date: DateTime(2026, 10, 13),
              status: thirteenth,
              startTime: '09:00',
            ),
          ],
        );

    // During the 6 Oct class (09:00–11:00).
    final duringClass = DateTime(2026, 10, 6, 10);

    for (final status in ['absent', null, 'excused']) {
      testWidgets('during the live window, today\'s $status — the backend '
          'reports an unrecorded session absent from midnight — offers the '
          'scanner, and the lesson stays locked', (tester) async {
        final learning = learningFor();
        await pumpHome(
          tester,
          learning,
          now: duringClass,
          attendance: twoClasses(status, null),
        );

        expect(tester.widget<JuniorMapNodeTile>(tile(101)).checkIn, isTrue);
        expect(stateOf(tester, 101), JuniorNodeState.current);
        await tester.tap(tile(101));
        await tester.pumpAndSettle();
        expect(find.byType(AttendanceScannerScreen), findsOneWidget);
        // The scanner being offered opens no lesson.
        expect(find.byType(CourseExerciseDetailScreen), findsNothing);
        expect(learning.exerciseCalls, isEmpty);
      });
    }

    for (final status in ['present', 'late']) {
      testWidgets('during the live window, today\'s $status: no scanner '
          'again, and the lesson opens', (tester) async {
        final learning = learningFor();
        await pumpHome(
          tester,
          learning,
          now: duringClass,
          attendance: twoClasses(status, null),
        );

        expect(tester.widget<JuniorMapNodeTile>(tile(101)).checkIn, isFalse);
        expect(stateOf(tester, 101), JuniorNodeState.attendanceCompleted);
        await tester.tap(tile(101));
        await tester.pumpAndSettle();
        expect(find.byType(AttendanceScannerScreen), findsNothing);
        expect(learning.exerciseCalls, [101]);
      });

      testWidgets('after the class has ended, $status still opens the lesson '
          '— the next lesson has moved on to 13 Oct', (tester) async {
        final learning = learningFor();
        await pumpHome(
          tester,
          learning,
          now: DateTime(2026, 10, 6, 14),
          attendance: twoClasses(status, null),
        );

        expect(stateOf(tester, 101), JuniorNodeState.attendanceCompleted);
        await tester.tap(tile(101));
        await tester.pumpAndSettle();
        expect(learning.exerciseCalls, [101]);
      });
    }

    testWidgets('a new class day before check-in is locked again: last '
        'week\'s present no longer opens it', (tester) async {
      final learning = learningFor();
      await pumpHome(
        tester,
        learning,
        // 08:00 on 13 Oct, before the class.
        now: DateTime(2026, 10, 13, 8),
        attendance: twoClasses('present', 'absent'),
      );

      expect(stateOf(tester, 101), JuniorNodeState.current);
      final node = tester.widget<JuniorMapNodeTile>(tile(101));
      expect(node.checkIn, isFalse);
      expect(node.onTap, isNull);
      await tester.tap(tile(101));
      await tester.pumpAndSettle();
      expect(learning.exerciseCalls, isEmpty);
    });

    testWidgets('attendance never completes a lesson: attended, it opens but '
        'is not ticked; a saved note ticks it', (tester) async {
      final learning = learningFor();
      await pumpHome(
        tester,
        learning,
        now: DateTime(2026, 10, 6, 14),
        attendance: twoClasses('present', null),
      );
      expect(stateOf(tester, 101), JuniorNodeState.attendanceCompleted);
      expect(learning.completeCalls, isEmpty);

      await pumpHome(
        tester,
        learningFor(notes: {101: sampleNote()}),
        now: DateTime(2026, 10, 6, 14),
        attendance: twoClasses('present', null),
      );
      expect(stateOf(tester, 101), JuniorNodeState.completed);
    });

    testWidgets('opening a lesson alone completes nothing', (tester) async {
      final learning = learningFor();
      await pumpHome(tester, learning, attendance: attendanceOn6Oct('present'));

      await tester.tap(tile(101));
      await tester.pumpAndSettle();
      expect(find.byType(CourseExerciseDetailScreen), findsOneWidget);
      await back(tester);

      // Attended, not completed: attendance never completes a lesson.
      expect(stateOf(tester, 101), JuniorNodeState.attendanceCompleted);
      expect(learning.completeCalls, isEmpty);
      expect(learning.saveCalls, isEmpty);
    });

    testWidgets('a failed note save completes nothing', (tester) async {
      final learning = learningFor()
        ..saveFailure = const CourseLearningFailure(
          CourseLearningFailureKind.network,
        );
      await pumpHome(tester, learning, attendance: attendanceOn6Oct('present'));

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
      await pumpHome(tester, learning, attendance: attendanceOn6Oct('present'));

      await tester.tap(tile(101));
      await tester.pumpAndSettle();
      await saveNote(tester, '   ');
      await back(tester);

      expect(learning.notesByLesson, isEmpty);
      expect(stateOf(tester, 101), JuniorNodeState.attendanceCompleted);
    });

    testWidgets('one lesson\'s failed note read: the map still draws, that '
        'lesson is not completed, the others go by their notes (Issue #535)', (
      tester,
    ) async {
      final learning =
          learningFor(notes: {101: sampleNote(), 102: sampleNote()})
            ..noteFailuresByLesson[101] = const CourseLearningFailure(
              CourseLearningFailureKind.network,
            );
      await pumpHome(tester, learning);

      expect(find.byType(JuniorMapNodeTile), findsNWidgets(3));
      expect(find.text(JuniorHomeStrings.retry), findsNothing);
      // 101's note exists but could not be read: not completed.
      expect(stateOf(tester, 101), isNot(JuniorNodeState.completed));
      expect(stateOf(tester, 102), JuniorNodeState.completed);
      expect(stateOf(tester, 201), JuniorNodeState.locked);
      expect(learning.noteCalls, isNot(contains(201)));
    });

    testWidgets('a refused session while reading notes still fails the map, '
        'with retry', (tester) async {
      final learning = learningFor(notes: {102: sampleNote()})
        ..noteFailuresByLesson[101] = const CourseLearningFailure(
          CourseLearningFailureKind.sessionExpired,
        );
      await pumpHome(tester, learning);

      expect(find.byType(JuniorMapNodeTile), findsNothing);
      expect(find.text(JuniorHomeStrings.sessionExpired), findsOneWidget);
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

    testWidgets('a check-in that fails records nothing: back from the '
        'scanner, the node is still the live check-in', (tester) async {
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
      expect(stateOf(tester, 101), JuniorNodeState.current);
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

/// The dashboard's next lesson as production derives it at [now]
/// (`nextLessonFor`, Issue #443): the 6 Oct class (09:00–11:00) until it has
/// ended, then the next one, 13 Oct.
NextLesson realisticNextLesson(DateTime now) =>
    now.isBefore(DateTime(2026, 10, 6, 11))
    ? NextLesson(
        startsAt: DateTime(2026, 10, 6, 9),
        endsAt: DateTime(2026, 10, 6, 11),
      )
    : NextLesson(
        startsAt: DateTime(2026, 10, 13, 9),
        endsAt: DateTime(2026, 10, 13, 11),
      );
