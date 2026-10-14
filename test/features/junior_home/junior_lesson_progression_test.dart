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

/// The Junior path's progression end to end (Issue #410): the real
/// repository and mapper over in-memory fakes — no backend is called —
/// through Junior Home, into a lesson and back.
void main() {
  setUpAll(loadAppFonts);

  const slug = 'junior-ai';

  /// One module of four lessons, all unlocked by the server (it gates by
  /// class date alone); [done] of them completed, the server resuming at
  /// the first one not done.
  void serve(FakeCourseLearningRepository learning, {required int done}) {
    learning
      ..path = samplePath(
        courseSlug: slug,
        percentComplete: done * 25,
        continueModuleId: 1,
        continueLessonId: done < 4 ? 101 + done : 104,
        modules: [sampleModule(id: 1, order: 1)],
      )
      ..lessonsByModule = {
        1: [
          for (var i = 0; i < 4; i++)
            sampleLesson(
              id: 101 + i,
              moduleId: 1,
              order: i + 1,
              title: 'Lesson ${i + 1}',
              completed: i < done,
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
    int done = 1,
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
  const available = JuniorNodeState.current;
  const locked = JuniorNodeState.locked;

  testWidgets('one lesson available; the lessons not yet reached are locked, '
      'whatever the progress says', (tester) async {
    await pumpHome(tester, done: 2);

    expect(states(tester), [done, done, available, locked]);
    // 50%: the server's figure, unchanged by how many nodes are open.
    expect(find.text('50%'), findsOneWidget);
    expect(find.byType(JuniorCourseProgressCard), findsOneWidget);
  });

  testWidgets('a lesson not yet reached cannot be opened', (tester) async {
    final learning = await pumpHome(tester);

    expect(tester.widget<JuniorMapNodeTile>(tile(103)).onTap, isNull);
    await tester.tap(tile(103));
    await tester.pumpAndSettle();
    await tester.tap(tile(104));
    await tester.pumpAndSettle();

    expect(find.byType(CourseExerciseDetailScreen), findsNothing);
    expect(learning.exerciseCalls, isEmpty);
  });

  testWidgets('completing the available lesson and coming back: it is ticked '
      'and the next one opens up', (tester) async {
    final learning = await pumpHome(tester);
    expect(states(tester), [done, available, locked, locked]);

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
    // Completed in the lesson — the server's answer changes.
    serve(learning, done: 2);
    await tester.tap(find.bySemanticsLabel(CourseLearningStrings.back));
    await tester.pumpAndSettle();

    expect(states(tester), [done, done, available, locked]);
    expect(tester.widget<JuniorMapNodeTile>(tile(103)).onTap, isNotNull);
    expect(tester.widget<JuniorMapNodeTile>(tile(104)).onTap, isNull);
    // A completed lesson still opens.
    expect(tester.widget<JuniorMapNodeTile>(tile(101)).onTap, isNotNull);
  });

  testWidgets('check-in stays its own thing: during the lesson the available '
      'lesson is the check-in node, completion untouched', (tester) async {
    final learning = await pumpHome(tester, now: DateTime(2026, 10, 6, 10));

    final node = tester.widget<JuniorMapNodeTile>(tile(102));
    expect(node.checkIn, isTrue);
    expect(node.node.state, available);
    expect(
      tester
          .widgetList<JuniorMapNodeTile>(find.byType(JuniorMapNodeTile))
          .where((t) => t.checkIn),
      hasLength(1),
    );
    await tester.tap(tile(102));
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

    expect(tester.widget<JuniorMapNodeTile>(tile(102)).checkIn, isFalse);
    await tester.tap(tile(102));
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceScannerScreen), findsNothing);
    expect(learning.exerciseCalls, [102]);
  });
}
