import 'dart:convert';

import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/attendance/domain/course_attendance.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/course_learning/data/http_course_learning_repository.dart';
import 'package:aia_mobile/features/course_learning/domain/lesson.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/lesson_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/lesson_list_item.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/junior_home/data/api_junior_home_repository.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_course_progress_card.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/screenshot.dart';
import '../attendance/fake_attendance_repository.dart';
import '../course_learning/fake_course_learning_repository.dart';
import '../home/fake_home_dashboard_repository.dart' hide sampleLesson;

/// The device report's course, audited (Issue #410): blue ticks, nodes that
/// would not open, and padlocks between ticks.
///
/// The fixture is the backend's own seed for `junior-ai-summer-10-14`
/// (`ai-academy-backend` `app/seeds_programmes`, `summer-kids`), replayed
/// offline — no backend is called. Three modules of 6, 3 and 2 lessons, one
/// class per lesson from 2026-06-16, so by October every module's first
/// class has passed and the server locks nothing. `record_progress` skips
/// lessons at random by each student's "diligence"; seeded student
/// `jr10.s10` (diligence 0.50) completes `·✓✓✓·✓✓·✓··` — 6 of 11, the 54%
/// the device showed. The server's continue lesson is the first gap.
///
/// So the ticks interleaved with unfinished lessons are the seeded progress
/// itself — completed out of order — not the module order, not a server
/// lock, and not the app. The app draws them faithfully and in order.
void main() {
  setUpAll(loadAppFonts);

  const slug = 'junior-ai-summer-10-14';
  const pattern = '·✓✓✓·✓✓·✓··';
  const moduleSizes = [6, 3, 2];

  /// (module id, module order, lesson id, lesson order), course order.
  final lessonsInOrder = [
    for (var m = 0, n = 0; m < moduleSizes.length; m++)
      for (var l = 0; l < moduleSizes[m]; l++, n++)
        (41 + m, m + 1, 4101 + n, l + 1),
  ];
  bool completedAt(int n) => pattern[n] == '✓';
  final continueLessonId = lessonsInOrder[pattern.indexOf('·')].$3; // 4101

  group('through the real parser: the contract\'s bodies', () {
    Map<String, Object?> bodyFor(String path, {bool scrambled = false}) {
      Map<String, Object?> lesson((int, int, int, int) l, int n) => {
        'id': l.$3,
        'order': l.$4,
        'title': {'mn': 'Хичээл ${n + 1}', 'en': 'Lesson ${n + 1}'},
        'type': 'recording',
        'duration_seconds': 10800,
        'completed': completedAt(n),
        'locked': false,
      };
      if (path == '/me/courses/$slug/learning') {
        final modules = [
          for (var m = 0; m < moduleSizes.length; m++)
            {
              'id': 41 + m,
              'order': m + 1,
              'title': {'mn': 'Бүлэг ${m + 1}', 'en': 'Module ${m + 1}'},
              'schedule': {'date': '2026-06-16', 'start_time': '09:00'},
              'lesson_count': moduleSizes[m],
              'completed_lessons': 0,
              'completed': false,
              'locked': false,
            },
        ];
        return {
          'course': {
            'id': 7,
            'slug': slug,
            'title': {'mn': 'Junior AI', 'en': 'Junior AI'},
            'description': {'mn': '', 'en': ''},
            'banner_image_url': null,
          },
          'enrollment_id': 1,
          'cohort_id': 7,
          'progress': {
            'percent': 54,
            'completed_lessons': 6,
            'total_lessons': 11,
          },
          'continue': {'module_id': 41, 'lesson_id': continueLessonId},
          'certificate': {'status': 'not_eligible'},
          'modules': scrambled ? modules.reversed.toList() : modules,
        };
      }
      final moduleId = int.parse(path.split('/')[3]);
      final lessons = [
        for (final (n, l) in lessonsInOrder.indexed)
          if (l.$1 == moduleId) lesson(l, n),
      ];
      return {
        'module': {
          'id': moduleId,
          'order': moduleId - 40,
          'title': {'en': 'M'},
        },
        'lessons': scrambled ? lessons.reversed.toList() : lessons,
      };
    }

    Future<JuniorLearningMap> load({bool scrambled = false}) async =>
        (await ApiJuniorHomeRepository(
          dashboardRepository: FakeHomeDashboardRepository(
            dashboard: HomeDashboard(program: sampleProgram(courseSlug: slug)),
          ),
          courseLearningRepository: HttpCourseLearningRepository(
            client: MockClient(
              (request) async => http.Response.bytes(
                utf8.encode(
                  jsonEncode(bodyFor(request.url.path, scrambled: scrambled)),
                ),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ),
            ),
            sessionStore: AuthSessionStore()
              ..save(const AuthSession(accessToken: 'tok-123')),
          ),
          attendanceRepository: FakeAttendanceRepository(),
        ).getLearningMap())!;

    for (final scrambled in [false, true]) {
      test('every lesson in course order with its own ids — module order, '
          'then lesson order${scrambled ? ', whatever order the arrays '
                    'arrive in' : ''}', () async {
        final map = await load(scrambled: scrambled);

        expect(
          [for (final n in map.nodes) (n.moduleId, n.moduleOrder, n.id)],
          [for (final l in lessonsInOrder) (l.$1, l.$2, l.$3)],
        );
      });
    }

    test('the audit: each lesson\'s server flags, its derived state, and '
        'whether it opens', () async {
      final map = await load();

      // ✓ completed (opens) · ◉ the continue lesson (opens) · 🔒 not yet
      // its turn (does not open). No lesson is server-locked here.
      expect(
        [
          for (final n in map.nodes)
            switch (n.state) {
              JuniorNodeState.completed => '✓',
              JuniorNodeState.current => '◉',
              JuniorNodeState.open => '🔒',
              JuniorNodeState.locked => 'L',
            },
        ].join(),
        '◉✓✓✓🔒✓✓🔒✓🔒🔒',
      );
      expect(map.nodes.map((n) => n.locked), everyElement(isFalse));
      expect(
        map.nodes.where((n) => n.opens).map((n) => n.id),
        [
          continueLessonId,
          for (final (n, l) in lessonsInOrder.indexed)
            if (completedAt(n)) l.$3,
        ]..sort(),
      );
      expect(map.progress.percentComplete, 54);
    });
  });

  group('on Junior Home: drawn, and tapped', () {
    Future<FakeCourseLearningRepository> pumpHome(WidgetTester tester) async {
      useLogicalViewport(tester, const Size(393, 2400), padding: iPhonePadding);
      useReducedMotion(tester);
      final learning = FakeCourseLearningRepository(
        exercise: sampleExercise(),
        path: samplePath(
          courseSlug: slug,
          percentComplete: 54,
          continueModuleId: 41,
          continueLessonId: continueLessonId,
          modules: [
            for (var m = 0; m < moduleSizes.length; m++)
              sampleModule(id: 41 + m, order: m + 1),
          ],
        ),
        lessonsByModule: {
          for (var m = 0; m < moduleSizes.length; m++)
            41 + m: [
              for (final (n, l) in lessonsInOrder.indexed)
                if (l.$1 == 41 + m)
                  sampleLesson(
                    id: l.$3,
                    moduleId: l.$1,
                    order: l.$4,
                    completed: completedAt(n),
                  ),
            ],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: JuniorHomeScreen(
            repository: ApiJuniorHomeRepository(
              dashboardRepository: FakeHomeDashboardRepository(
                dashboard: HomeDashboard(
                  program: sampleProgram(courseSlug: slug),
                ),
              ),
              courseLearningRepository: learning,
              attendanceRepository: FakeAttendanceRepository(
                attendance: const CourseAttendance(
                  attended: 0,
                  totalPast: 0,
                  percent: 0,
                ),
              ),
            ),
            courseLearningRepository: learning,
            clock: () => DateTime(2026, 10, 14, 12),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return learning;
    }

    Finder tile(int id) => find.byWidgetPredicate(
      (w) => w is JuniorMapNodeTile && w.node.id == id,
    );
    String glyphOf(WidgetTester tester, int id) {
      final image = tester.widget<Image>(
        find.descendant(of: tile(id), matching: find.byType(Image)),
      );
      return (image.image as AssetImage).assetName.split('/').last;
    }

    testWidgets('every node: a tick, the active tick, or a padlock — no '
        'blank node; and a tap opens exactly the completed lessons and the '
        'one to continue with', (tester) async {
      final learning = await pumpHome(tester);

      expect(
        find.descendant(
          of: find.byType(JuniorCourseProgressCard),
          matching: find.text('54%'),
        ),
        findsOneWidget,
      );
      final opened = <int>[];
      for (final (n, l) in lessonsInOrder.indexed) {
        final id = l.$3;
        final expectedGlyph = id == continueLessonId || completedAt(n)
            ? 'node_check.png'
            : 'node_lock.png';
        expect(glyphOf(tester, id), expectedGlyph, reason: 'lesson $id');

        await tester.tap(tile(id));
        await tester.pumpAndSettle();
        if (find.byType(CourseExerciseDetailScreen).evaluate().isNotEmpty) {
          opened.add(
            tester
                .widget<CourseExerciseDetailScreen>(
                  find.byType(CourseExerciseDetailScreen),
                )
                .lessonId,
          );
          await tester.tap(find.bySemanticsLabel(CourseLearningStrings.back));
          await tester.pumpAndSettle();
        }
      }

      expect(opened, [
        for (final (n, l) in lessonsInOrder.indexed)
          if (l.$3 == continueLessonId || completedAt(n)) l.$3,
      ]);
      expect(learning.exerciseCalls, opened);
    });

    testWidgets('opening lessons never completes one: no completion request, '
        'and the path reloads unchanged', (tester) async {
      final learning = await pumpHome(tester);
      List<JuniorNodeState> states() => [
        for (final t in tester.widgetList<JuniorMapNodeTile>(
          find.byType(JuniorMapNodeTile),
        ))
          t.node.state,
      ];
      final before = states();

      for (final id in [continueLessonId, 4102, 4106]) {
        await tester.tap(tile(id));
        await tester.pumpAndSettle();
        expect(find.byType(CourseExerciseDetailScreen), findsOneWidget);
        await tester.tap(find.bySemanticsLabel(CourseLearningStrings.back));
        await tester.pumpAndSettle();
      }

      // `POST /me/lessons/{id}/complete` was never asked for; only the
      // lessons' content was read.
      expect(learning.completeCalls, isEmpty);
      expect(learning.exerciseCalls, [continueLessonId, 4102, 4106]);
      expect(states(), before);
      expect(
        find.descendant(
          of: find.byType(JuniorCourseProgressCard),
          matching: find.text('54%'),
        ),
        findsOneWidget,
      );
    });
  });

  test('a module locked between open ones keeps its place: nothing is '
      'reordered by lock or by completion', () {
    // Module 2's first class moved later (its server lock), modules 1 and
    // 3 open; one of module 3's lessons completed.
    final map = juniorMapFrom(
      samplePath(
        continueModuleId: 1,
        continueLessonId: 12,
        modules: [
          sampleModule(id: 1, order: 1),
          sampleModule(id: 2, order: 2, locked: true),
          sampleModule(id: 3, order: 3),
        ],
      ),
      lessons: {
        1: [
          sampleLesson(id: 11, moduleId: 1, order: 1, completed: true),
          sampleLesson(id: 12, moduleId: 1, order: 2),
        ],
        2: [
          sampleLesson(id: 21, moduleId: 2, order: 1, locked: true),
          sampleLesson(
            id: 22,
            moduleId: 2,
            order: 2,
            completed: true,
            locked: true,
          ),
        ],
        3: [
          sampleLesson(id: 31, moduleId: 3, order: 1, completed: true),
          sampleLesson(id: 32, moduleId: 3, order: 2),
        ],
      },
    );

    expect(map.nodes.map((n) => n.id), [11, 12, 21, 22, 31, 32]);
    expect(map.nodes.map((n) => n.state), [
      JuniorNodeState.completed,
      JuniorNodeState.current,
      JuniorNodeState.locked,
      JuniorNodeState.completed, // completed, its module locked again
      JuniorNodeState.completed,
      JuniorNodeState.open,
    ]);
    expect(map.nodes.map((n) => n.opens), [
      true,
      true,
      false,
      false,
      true,
      false,
    ]);
  });

  testWidgets('the Lesson List answers the same for the same lessons', (
    tester,
  ) async {
    // Module 41 of the fixture: lessons 4101–4106, `·✓✓✓·✓`.
    final lessons = <Lesson>[
      for (final (n, l) in lessonsInOrder.indexed)
        if (l.$1 == 41)
          sampleLesson(
            id: l.$3,
            moduleId: 41,
            order: l.$4,
            title: 'Lesson ${n + 1}',
            completed: completedAt(n),
          ),
    ];
    useLogicalViewport(tester, const Size(393, 1600), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LessonListScreen(
          moduleId: 41,
          moduleOrder: 1,
          moduleTitle: 'Module 1',
          repository: FakeCourseLearningRepository(lessons: lessons),
          resumeLessonId: continueLessonId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tappable = [
      for (final item in tester.widgetList<LessonListItem>(
        find.byType(LessonListItem),
      ))
        if (item.onTap != null) item.lesson.id,
    ];
    expect(tappable, [4101, 4102, 4103, 4104, 4106]);
  });
}
