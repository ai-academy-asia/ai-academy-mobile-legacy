import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/attendance/domain/course_attendance.dart';
import 'package:aia_mobile/features/attendance/presentation/attendance_scanner_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/junior_home/data/api_junior_home_repository.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_course_progress_card.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../attendance/fake_attendance_repository.dart';
import '../course_learning/fake_course_learning_repository.dart';
import '../home/fake_home_dashboard_repository.dart' hide sampleLesson;

/// Lesson availability on Junior Home end to end (Issue #410): the server's
/// lock — a lesson's class date not yet come — is the only rule. The real
/// repository and mapper over in-memory fakes — no backend is called —
/// through Junior Home, into a lesson and back.
void main() {
  setUpAll(loadAppFonts);

  const slug = 'junior-ai';

  /// Module 1's class date has come: its two lessons are open, [done] of
  /// them completed. Module 2's has not ([future]): the server locks it and
  /// its two lessons alike. Module 3's came and was then moved later: the
  /// server locks it again, its one lesson already completed.
  void serve(
    FakeCourseLearningRepository learning, {
    int done = 0,
    bool future = true,
  }) {
    learning
      ..path = samplePath(
        courseSlug: slug,
        percentComplete: 54,
        continueModuleId: done < 2 ? 1 : (future ? null : 2),
        continueLessonId: done < 2 ? 101 + done : (future ? null : 201),
        modules: [
          sampleModule(id: 1, order: 1, completed: done == 2),
          sampleModule(id: 2, order: 2, locked: future),
          sampleModule(id: 3, order: 3, locked: true),
        ],
      )
      ..lessonsByModule = {
        1: [
          for (var i = 0; i < 2; i++)
            sampleLesson(
              id: 101 + i,
              moduleId: 1,
              order: i + 1,
              completed: i < done,
            ),
        ],
        2: [
          for (var i = 0; i < 2; i++)
            sampleLesson(
              id: 201 + i,
              moduleId: 2,
              order: i + 1,
              locked: future,
            ),
        ],
        3: [
          sampleLesson(
            id: 301,
            moduleId: 3,
            order: 1,
            completed: true,
            locked: true,
          ),
        ],
      };
  }

  final lesson = NextLesson(
    startsAt: DateTime(2026, 10, 6, 9),
    endsAt: DateTime(2026, 10, 6, 11),
  );

  Future<FakeCourseLearningRepository> pumpHome(
    WidgetTester tester, {
    int done = 0,
    DateTime? now,
    CourseAttendance? attendance,
  }) async {
    useLogicalViewport(tester, const Size(393, 1400), padding: iPhonePadding);
    useReducedMotion(tester);
    final learning = FakeCourseLearningRepository(exercise: sampleExercise());
    serve(learning, done: done);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: JuniorHomeScreen(
          repository: ApiJuniorHomeRepository(
            dashboardRepository: FakeHomeDashboardRepository(
              dashboard: HomeDashboard(
                program: sampleProgram(courseSlug: slug, nextLesson: lesson),
              ),
            ),
            courseLearningRepository: learning,
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
          clock: () => now ?? DateTime(2026, 10, 6, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return learning;
  }

  Finder tile(int id) =>
      find.byWidgetPredicate((w) => w is JuniorMapNodeTile && w.node.id == id);
  List<JuniorNodeState> states(WidgetTester tester) => [
    for (final t in tester.widgetList<JuniorMapNodeTile>(
      find.byType(JuniorMapNodeTile),
    ))
      t.node.state,
  ];
  const done = JuniorNodeState.completed;
  const current = JuniorNodeState.current;
  const open = JuniorNodeState.open;
  const locked = JuniorNodeState.locked;

  testWidgets('the class date is the only rule: lessons whose date has come '
      'open, those whose date has not are locked', (tester) async {
    await pumpHome(tester);

    expect(states(tester), [current, open, locked, locked, done]);
    for (final id in [101, 102]) {
      expect(tester.widget<JuniorMapNodeTile>(tile(id)).onTap, isNotNull);
    }
    for (final id in [201, 202, 301]) {
      expect(tester.widget<JuniorMapNodeTile>(tile(id)).onTap, isNull);
    }
    // 54%: the server's figure, whatever opens.
    expect(find.text('54%'), findsOneWidget);
    expect(find.byType(JuniorCourseProgressCard), findsOneWidget);
  });

  testWidgets('a lesson whose class date has not come cannot be opened — no '
      'request is sent', (tester) async {
    final learning = await pumpHome(tester);

    for (final id in [201, 202]) {
      await tester.tap(tile(id));
      await tester.pumpAndSettle();
    }

    expect(find.byType(CourseExerciseDetailScreen), findsNothing);
    expect(learning.exerciseCalls, isEmpty);
  });

  testWidgets('a completed lesson whose class moved later keeps its tick and '
      'cannot be opened', (tester) async {
    final learning = await pumpHome(tester);

    final node = tester.widget<JuniorMapNodeTile>(tile(301));
    expect(node.node.state, done);
    expect(node.onTap, isNull);
    await tester.tap(tile(301));
    await tester.pumpAndSettle();
    expect(learning.exerciseCalls, isEmpty);
  });

  testWidgets('every lesson whose date has come opens — not only the one to '
      'continue with', (tester) async {
    final learning = await pumpHome(tester);

    await tester.tap(tile(102));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<CourseExerciseDetailScreen>(
            find.byType(CourseExerciseDetailScreen),
          )
          .lessonId,
      102,
    );
    expect(learning.exerciseCalls, [102]);
  });

  testWidgets('completing a lesson and coming back reloads the server\'s '
      'answer: ticked, and the resume lesson moves on', (tester) async {
    final learning = await pumpHome(tester);

    await tester.tap(tile(101));
    await tester.pumpAndSettle();
    serve(learning, done: 1);
    await tester.tap(find.bySemanticsLabel(CourseLearningStrings.back));
    await tester.pumpAndSettle();

    expect(states(tester), [done, current, locked, locked, done]);
  });

  testWidgets('when the class date comes, the next load opens the module — '
      'the server decides, the map follows', (tester) async {
    final learning = await pumpHome(tester, done: 1);
    expect(tester.widget<JuniorMapNodeTile>(tile(201)).onTap, isNull);

    await tester.tap(tile(102));
    await tester.pumpAndSettle();
    serve(learning, done: 2, future: false);
    await tester.tap(find.bySemanticsLabel(CourseLearningStrings.back));
    await tester.pumpAndSettle();

    expect(states(tester), [done, done, current, open, done]);
    expect(tester.widget<JuniorMapNodeTile>(tile(201)).onTap, isNotNull);
    expect(tester.widget<JuniorMapNodeTile>(tile(301)).onTap, isNull);
  });

  testWidgets('check-in stays its own thing: during the lesson the available '
      'lesson is the check-in node, completion untouched', (tester) async {
    final learning = await pumpHome(tester, now: DateTime(2026, 10, 6, 10));

    final node = tester.widget<JuniorMapNodeTile>(tile(101));
    expect(node.checkIn, isTrue);
    expect(node.node.state, current);
    expect(
      tester
          .widgetList<JuniorMapNodeTile>(find.byType(JuniorMapNodeTile))
          .where((t) => t.checkIn),
      hasLength(1),
    );
    await tester.tap(tile(101));
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceScannerScreen), findsOneWidget);
    expect(learning.exerciseCalls, isEmpty);
  });

  testWidgets('attendance already recorded: no check-in, the available '
      'lesson opens itself', (tester) async {
    final learning = await pumpHome(
      tester,
      now: DateTime(2026, 10, 6, 10),
      attendance: CourseAttendance(
        attended: 1,
        totalPast: 1,
        percent: 100,
        sessions: [
          AttendanceSession(date: DateTime(2026, 10, 6), status: 'present'),
        ],
      ),
    );

    expect(tester.widget<JuniorMapNodeTile>(tile(101)).checkIn, isFalse);
    await tester.tap(tile(101));
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceScannerScreen), findsNothing);
    expect(learning.exerciseCalls, [101]);
  });
}
