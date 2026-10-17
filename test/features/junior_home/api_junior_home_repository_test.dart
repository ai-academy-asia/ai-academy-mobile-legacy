import 'dart:convert';

import 'package:aia_mobile/features/attendance/domain/attendance_failure.dart';
import 'package:aia_mobile/features/attendance/domain/course_attendance.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/course_learning/data/http_course_learning_repository.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_path.dart';
import 'package:aia_mobile/features/course_learning/domain/lesson.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/domain/home_failure.dart';
import 'package:aia_mobile/features/junior_home/data/api_junior_home_repository.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../attendance/fake_attendance_repository.dart';
import '../course_learning/fake_course_learning_repository.dart';
import '../home/fake_home_dashboard_repository.dart' hide sampleLesson;

/// Junior Home over the repositories it composes.
///
/// The HTTP layers are `HttpCourseLearningRepository`'s and
/// `HttpAttendanceRepository`'s, covered by their own suites. What this file
/// is about is resolving the slug, and turning one [CourseLearningPath] and
/// its modules' lessons into a lesson-by-lesson [JuniorLearningMap] (Issues
/// #100, #410) without deriving anything the server already decided — plus
/// one pass through the real parser over the contract's own bodies. Every
/// attendance read is a fake's: no test here reaches a live backend.
void main() {
  ApiJuniorHomeRepository repositoryFor({
    HomeDashboard? dashboard,
    HomeFailure? dashboardFailure,
    CourseLearningPath? path,
    CourseLearningFailure? learningFailure,
    FakeCourseLearningRepository? learning,
    FakeAttendanceRepository? attendance,
    DateTime Function()? clock,
  }) => ApiJuniorHomeRepository(
    clock: clock,
    dashboardRepository: FakeHomeDashboardRepository(
      dashboard: dashboard ?? HomeDashboard(program: sampleProgram()),
      failure: dashboardFailure,
    ),
    courseLearningRepository:
        learning ??
        FakeCourseLearningRepository(path: path, failure: learningFailure),
    attendanceRepository: attendance ?? FakeAttendanceRepository(),
  );

  Future<CourseLearningFailure> failureFrom(
    ApiJuniorHomeRepository repository,
  ) async {
    try {
      await repository.getLearningMap();
    } on CourseLearningFailure catch (failure) {
      return failure;
    }
    fail('expected a CourseLearningFailure');
  }

  group('resolving the course', () {
    test('asks the learning API for the enrolled course\'s own slug', () async {
      final learning = FakeCourseLearningRepository();
      await repositoryFor(
        dashboard: HomeDashboard(
          program: sampleProgram(courseSlug: 'summer-bootcamp-2027'),
        ),
        learning: learning,
      ).getLearningMap();

      // Not a hardcoded Junior slug: whatever the student is enrolled in.
      expect(learning.calls, ['summer-bootcamp-2027']);
    });

    test('a student enrolled in nothing is empty, not an error', () async {
      final learning = FakeCourseLearningRepository();
      final map = await repositoryFor(
        dashboard: const HomeDashboard(),
        learning: learning,
      ).getLearningMap();

      expect(map, isNull);
      // And the learning endpoint is never called without a slug.
      expect(learning.calls, isEmpty);
    });

    test('a dashboard failure keeps its meaning', () async {
      for (final (dashboard, expected)
          in <(HomeFailureKind, CourseLearningFailureKind)>[
            (
              HomeFailureKind.sessionExpired,
              CourseLearningFailureKind.sessionExpired,
            ),
            (HomeFailureKind.network, CourseLearningFailureKind.network),
            (HomeFailureKind.server, CourseLearningFailureKind.server),
            (HomeFailureKind.unexpected, CourseLearningFailureKind.unexpected),
          ]) {
        final failure = await failureFrom(
          repositoryFor(dashboardFailure: HomeFailure(dashboard)),
        );
        expect(failure.kind, expected, reason: dashboard.name);
      }
    });

    test('a learning-API failure passes straight through', () async {
      final failure = await failureFrom(
        repositoryFor(
          learningFailure: const CourseLearningFailure(
            CourseLearningFailureKind.notEnrolled,
          ),
        ),
      );

      expect(failure.kind, CourseLearningFailureKind.notEnrolled);
    });
  });

  group('mapping the learning path', () {
    JuniorLearningMap mapOf(
      CourseLearningPath path, {
      Map<int, List<Lesson>> lessons = const {},
    }) => mapFrom(path, lessons: lessons);

    test('shows the server\'s percent, and never derives one', () async {
      // One of two lessons complete — a lesson-based figure would be 50.
      final map = mapOf(
        samplePath(
          percentComplete: 30,
          modules: [sampleModule(id: 1, order: 1)],
        ),
        lessons: {
          1: [
            sampleLesson(id: 1, moduleId: 1, order: 1, completed: true),
            sampleLesson(id: 2, moduleId: 1, order: 2),
          ],
        },
      );

      expect(map.progress.percentComplete, 30);
    });

    test('takes the course title for the card', () {
      final map = mapOf(samplePath(courseTitle: 'AI BootCamp'));

      expect(map.progress.title, 'AI BootCamp');
      // The same field fills the certificate panel's course line.
      expect(map.certificate.courseName, 'AI BootCamp');
    });

    test('keeps the course slug, so the card can open the course (#174)', () {
      expect(
        mapOf(samplePath(courseSlug: 'junior-ai')).courseSlug,
        'junior-ai',
      );
    });

    test('one node per lesson, its state straight off the server '
        '(Issue #410)', () {
      final map = mapOf(
        samplePath(modules: [sampleModule(id: 1, order: 1)]),
        lessons: {
          1: [
            sampleLesson(id: 11, moduleId: 1, order: 1, completed: true),
            sampleLesson(id: 12, moduleId: 1, order: 2, locked: true),
            sampleLesson(id: 13, moduleId: 1, order: 3),
          ],
        },
      );

      expect(map.nodes.map((n) => n.id), [11, 12, 13]);
      expect(map.nodes.map((n) => n.state), [
        JuniorNodeState.completed,
        JuniorNodeState.locked,
        // Neither flag set: open and unfinished — not the server's continue
        // lesson (none was named), so it waits its turn.
        JuniorNodeState.open,
      ]);
    });

    group('availability: unlocked, and done or the continue lesson '
        '(Issue #410)', () {
      // Module 1's class date has come: its lessons are open. Module 2's
      // has not: the server locks it, every lesson alike.
      final path = samplePath(
        percentComplete: 54,
        continueModuleId: 1,
        continueLessonId: 12,
        modules: [
          sampleModule(id: 1, order: 1),
          sampleModule(id: 2, order: 2, locked: true),
        ],
      );
      final lessons = {
        1: [
          sampleLesson(id: 11, moduleId: 1, order: 1, completed: true),
          sampleLesson(id: 12, moduleId: 1, order: 2),
          sampleLesson(id: 13, moduleId: 1, order: 3),
        ],
        2: [
          sampleLesson(id: 21, moduleId: 2, order: 1, locked: true),
          sampleLesson(id: 22, moduleId: 2, order: 2, locked: true),
        ],
      };

      test('states and taps: done opens; the continue lesson waits for its '
          'attendance (Issue #443); a lesson whose date has come but whose '
          'turn has not waits; server-locked ones never open', () {
        final map = mapFrom(path, lessons: lessons);

        expect(map.nodes.map((n) => n.state), [
          JuniorNodeState.completed,
          JuniorNodeState.current,
          JuniorNodeState.open,
          JuniorNodeState.locked,
          JuniorNodeState.locked,
        ]);
        expect(map.nodes.map((n) => n.locked), [
          false,
          false,
          false,
          true,
          true,
        ]);
        expect(map.nodes.map((n) => n.opens), [
          true,
          false,
          false,
          false,
          false,
        ]);
        expect(map.continueAttendanceConfirmed, isFalse);
      });

      test('confirmed attendance (present or late) opens the continue lesson, '
          'and only it; unconfirmed or unknown opens nothing new '
          '(Issue #443)', () {
        final attended = mapFrom(
          path,
          lessons: lessons,
          attendanceConfirmed: true,
        );
        expect(attended.nodes.map((n) => n.state), [
          JuniorNodeState.completed,
          JuniorNodeState.attendanceCompleted,
          JuniorNodeState.open,
          JuniorNodeState.locked,
          JuniorNodeState.locked,
        ]);
        expect(attended.nodes.map((n) => n.opens), [
          true,
          true,
          false,
          false,
          false,
        ]);
        // What Junior Course Detail's attendance gate is given.
        expect(attended.continueAttendanceConfirmed, isTrue);

        for (final confirmed in [false, null]) {
          final map = mapFrom(
            path,
            lessons: lessons,
            attendanceConfirmed: confirmed,
          );
          expect(map.nodes.map((n) => n.opens), [
            true,
            false,
            false,
            false,
            false,
          ], reason: '$confirmed');
          expect(map.continueAttendanceConfirmed, isFalse);
        }
      });

      test('the continue lesson is picked out — the one unfinished lesson '
          'that opens, and the check-in node', () {
        final map = mapFrom(path, lessons: lessons);

        expect(map.checkInNode?.id, 12);
        expect(
          map.nodes.where((n) => n.state == JuniorNodeState.current),
          hasLength(1),
        );
      });

      test('without a usable continue target, no unfinished lesson is '
          'guessed: none opens', () {
        for (final continueId in [null, 11, 21, 99]) {
          final map = mapFrom(
            samplePath(
              continueLessonId: continueId,
              modules: [
                sampleModule(id: 1, order: 1),
                sampleModule(id: 2, order: 2, locked: true),
              ],
            ),
            lessons: lessons,
          );
          expect(
            map.nodes.where((n) => n.state == JuniorNodeState.current),
            isEmpty,
            reason: '$continueId',
          );
          // Only the completed one opens.
          expect(map.nodes.where((n) => n.opens).map((n) => n.id), [
            11,
          ], reason: '$continueId');
          expect(map.nodes.where((n) => n.locked).map((n) => n.id), [21, 22]);
        }
      });

      test('the percentage stays the server\'s — never the share of nodes '
          'that open', () {
        expect(mapFrom(path, lessons: lessons).progress.percentComplete, 54);
      });

      test('a lesson the server still counts completed, in a module locked '
          'again, is LOCKED — its note can\'t be read', () {
        final map = mapFrom(
          samplePath(modules: [sampleModule(id: 3, order: 1, locked: true)]),
          lessons: {
            3: [
              sampleLesson(
                id: 31,
                moduleId: 3,
                order: 1,
                completed: true,
                locked: true,
              ),
            ],
          },
        );

        expect(map.nodes.single.state, JuniorNodeState.locked);
        expect(map.nodes.single.locked, isTrue);
      });

      test('nothing open, or everything done: nothing picked out, nothing '
          'invented', () {
        final done = mapFrom(
          samplePath(continueLessonId: 12, modules: [sampleModule(id: 1)]),
          lessons: {
            1: [
              sampleLesson(id: 11, moduleId: 1, order: 1, completed: true),
              sampleLesson(id: 12, moduleId: 1, order: 2, completed: true),
            ],
          },
        );
        expect(
          done.nodes.map((n) => n.state),
          everyElement(JuniorNodeState.completed),
        );
        expect(done.checkInNode, isNull);

        final closed = mapFrom(
          samplePath(modules: [sampleModule(id: 1, locked: true)]),
          lessons: {
            1: [sampleLesson(id: 11, moduleId: 1, order: 1, locked: true)],
          },
        );
        expect(closed.nodes.single.state, JuniorNodeState.locked);
        expect(closed.checkInNode, isNull);
      });
    });

    test('a locked lesson is LOCKED even when the server says completed — '
        'its note can\'t be read, and the server flag alone completes '
        'nothing (Issue #415)', () {
      final map = juniorMapFrom(
        samplePath(modules: [sampleModule(id: 1, order: 1)]),
        lessons: {
          1: [
            sampleLesson(
              id: 1,
              moduleId: 1,
              order: 1,
              completed: true,
              locked: true,
            ),
          ],
        },
      );

      expect(map.nodes.single.state, JuniorNodeState.locked);
      expect(map.nodes.single.opens, isFalse);
    });

    test('every lesson of a locked module is LOCKED — none of their notes is '
        'read (Issue #415)', () {
      final map = mapOf(
        samplePath(modules: [sampleModule(id: 1, order: 1, locked: true)]),
        lessons: {
          1: [
            sampleLesson(id: 1, moduleId: 1, order: 1, completed: true),
            sampleLesson(id: 2, moduleId: 1, order: 2),
          ],
        },
      );

      expect(map.nodes.map((n) => n.state), [
        JuniorNodeState.locked,
        JuniorNodeState.locked,
      ]);
    });

    test('a note given for a lesson that is locked again: the tick shows, '
        'and it still does not open — the server would answer 409', () {
      final map = juniorMapFrom(
        samplePath(modules: [sampleModule(id: 1, order: 1, locked: true)]),
        lessons: {
          1: [sampleLesson(id: 1, moduleId: 1, order: 1, locked: true)],
        },
        completedByNote: {1},
      );

      expect(map.nodes.single.state, JuniorNodeState.completed);
      expect(map.nodes.single.locked, isTrue);
      expect(map.nodes.single.opens, isFalse);
    });

    test('an unlocked lesson is never marked locked, completed or not', () {
      final map = mapOf(
        samplePath(modules: [sampleModule(id: 1, order: 1)]),
        lessons: {
          1: [
            sampleLesson(id: 1, moduleId: 1, order: 1, completed: true),
            sampleLesson(id: 2, moduleId: 1, order: 2),
          ],
        },
      );

      expect(map.nodes.map((n) => n.locked), [false, false]);
    });

    test('orders the whole path by module order, then lesson order — never '
        'by array position', () {
      final map = mapOf(
        samplePath(
          modules: [
            sampleModule(id: 30, order: 3),
            sampleModule(id: 10, order: 1),
            sampleModule(id: 20, order: 2),
          ],
        ),
        lessons: {
          30: [
            sampleLesson(id: 302, moduleId: 30, order: 2),
            sampleLesson(id: 301, moduleId: 30, order: 1),
          ],
          10: [
            sampleLesson(id: 103, moduleId: 10, order: 3),
            sampleLesson(id: 101, moduleId: 10, order: 1),
            sampleLesson(id: 102, moduleId: 10, order: 2),
          ],
          20: [sampleLesson(id: 201, moduleId: 20, order: 1)],
        },
      );

      expect(map.nodes.map((n) => n.id), [101, 102, 103, 201, 301, 302]);
    });

    test('each node carries its lesson\'s id and title — what a tap opens — '
        'and its module\'s id and order', () {
      final map = mapOf(
        samplePath(
          modules: [
            sampleModule(id: 7, order: 1),
            sampleModule(id: 8, order: 2),
          ],
        ),
        lessons: {
          7: [sampleLesson(id: 70, moduleId: 7, order: 1, title: 'Hello')],
          8: [sampleLesson(id: 80, moduleId: 8, order: 1, title: 'World')],
        },
      );

      expect([for (final n in map.nodes) n.id], [70, 80]);
      expect([for (final n in map.nodes) n.title], ['Hello', 'World']);
      expect([for (final n in map.nodes) n.moduleId], [7, 8]);
      expect([for (final n in map.nodes) n.moduleOrder], [1, 2]);
    });

    test('carries the server-selected continue target whole', () {
      final map = mapOf(
        samplePath(continueModuleId: 31, continueLessonId: 204),
      );

      expect(map.continueModuleId, 31);
      expect(map.continueLessonId, 204);
    });

    test('no continue target when the server selected none', () {
      final map = mapOf(samplePath());

      expect(map.continueModuleId, isNull);
      expect(map.continueLessonId, isNull);
    });

    test('maps each certificate status the contract lists', () {
      const cases = {
        'not_eligible': JuniorCertificateStatus.notEligible,
        'eligible': JuniorCertificateStatus.eligible,
        'issued': JuniorCertificateStatus.issued,
      };
      for (final entry in cases.entries) {
        final map = mapOf(samplePath(certificateStatus: entry.key));
        expect(map.certificate.status, entry.value, reason: entry.key);
      }
    });

    test('an absent or unknown status is null, not a guessed state', () {
      expect(mapOf(samplePath()).certificate.status, isNull);
      expect(
        mapOf(samplePath(certificateStatus: 'revoked')).certificate.status,
        isNull,
      );
    });

    test('keeps the design\'s own certificate copy', () {
      final map = mapOf(samplePath());

      expect(map.certificate.track, 'Junior');
      expect(map.certificate.description, 'Earn a Certificate of completion');
    });

    test('a course with no modules, or modules with no lessons, maps to no '
        'nodes', () {
      expect(mapOf(samplePath(modules: [])).nodes, isEmpty);
      final map = mapOf(
        samplePath(modules: [sampleModule(id: 1, order: 1)]),
        lessons: {1: const []},
      );
      expect(map.nodes, isEmpty);
      expect(map.progress.title, isNotEmpty);
    });
  });

  group('loading the lessons', () {
    test('asks for every module\'s lessons, once each', () async {
      final learning = FakeCourseLearningRepository(
        path: samplePath(
          modules: [
            sampleModule(id: 4, order: 2),
            sampleModule(id: 3, order: 1),
          ],
        ),
      );
      await repositoryFor(learning: learning).getLearningMap();

      expect(learning.lessonCalls..sort(), [3, 4]);
    });

    test('a lessons failure fails the map — never a partial path', () async {
      final failure = await failureFrom(
        repositoryFor(
          learning: FakeCourseLearningRepository(
            lessonsFailure: const CourseLearningFailure(
              CourseLearningFailureKind.network,
            ),
          ),
        ),
      );

      expect(failure.kind, CourseLearningFailureKind.network);
    });
  });

  group('the contract\'s own bodies, through the real parser', () {
    // §2.1 and §2.2 response shapes (as `http_course_learning_repository_test`
    // uses them), served by a `MockClient` — no live backend is called.
    Map<String, Object?> lesson(
      int id,
      int order, {
      bool completed = false,
      bool locked = false,
    }) => {
      'id': id,
      'order': order,
      'title': {'mn': 'Хичээл $id', 'en': 'Lesson $id'},
      'type': 'recording',
      'duration_seconds': 1455,
      'completed': completed,
      'locked': locked,
    };
    Map<String, Object?> module(
      int id,
      int order, {
      bool completed = false,
      bool locked = false,
    }) => {
      'id': id,
      'order': order,
      'title': {'mn': 'Бүлэг $order', 'en': 'Module $order'},
      'schedule': {'date': '2026-08-06', 'start_time': '09:00'},
      'lesson_count': 2,
      'completed_lessons': completed ? 2 : 0,
      'completed': completed,
      'locked': locked,
    };
    Map<String, Object?> lessonDetail(int id, String? note) => {
      'id': id,
      'module': {
        'id': id ~/ 10,
        'order': id ~/ 10 - 29,
        'title': {'en': 'Module'},
      },
      'order': id % 10,
      'title': {'en': 'Lesson $id'},
      'type': 'recording',
      'duration_seconds': 1455,
      'video': null,
      'summary': null,
      'sections': <Object?>[],
      'completed': note != null,
      'materials': <Object?>[],
      'note': note == null
          ? null
          : {
              'id': id,
              'content': note,
              'created_at': '2026-08-06T01:00:00+00:00',
              'updated_at': '2026-08-06T01:00:00+00:00',
              'author': {'name': 'Болд Батаа', 'initials': 'ББ'},
            },
      'assignment': null,
      'quiz': null,
    };
    final bodies = <String, Object?>{
      '/me/courses/junior-ai/learning': {
        'course': {
          'id': 6,
          'slug': 'junior-ai',
          'title': {'mn': 'AI хэрхэн ажилладаг вэ', 'en': 'How AI works'},
          'description': {'mn': 'Тайлбар', 'en': 'Description'},
          'banner_image_url': 'https://example.test/banner.png',
        },
        'enrollment_id': 118,
        'cohort_id': 1,
        'progress': {'percent': 30, 'completed_lessons': 3, 'total_lessons': 6},
        'continue': {'module_id': 31, 'lesson_id': 312},
        'certificate': {'status': 'not_eligible'},
        // Out of order on purpose: the path follows `order`.
        'modules': [
          module(32, 3, locked: true),
          module(30, 1, completed: true),
          module(31, 2),
        ],
      },
      '/me/modules/30/lessons': {
        'module': {
          'id': 30,
          'order': 1,
          'title': {'en': 'Module 1'},
        },
        'lessons': [
          lesson(302, 2, completed: true),
          lesson(301, 1, completed: true),
        ],
      },
      '/me/modules/31/lessons': {
        'module': {
          'id': 31,
          'order': 2,
          'title': {'en': 'Module 2'},
        },
        'lessons': [lesson(311, 1, completed: true), lesson(312, 2)],
      },
      '/me/modules/32/lessons': {
        'module': {
          'id': 32,
          'order': 3,
          'title': {'en': 'Module 3'},
        },
        'lessons': [lesson(321, 1, locked: true), lesson(322, 2, locked: true)],
      },
      // §2.3 lesson detail, each with its saved note or none (Issue #415).
      for (final (id, note) in [
        (301, 'Base case first'),
        (302, 'Loops inside loops'),
        (311, 'Vision models'),
        (312, null),
      ])
        '/me/lessons/$id': lessonDetail(id, note),
    };

    test('every lesson, in course order, with its own state — completed by '
        'its saved note', () async {
      final requested = <String>[];
      final map = await ApiJuniorHomeRepository(
        dashboardRepository: FakeHomeDashboardRepository(
          dashboard: HomeDashboard(
            program: sampleProgram(courseSlug: 'junior-ai'),
          ),
        ),
        courseLearningRepository: HttpCourseLearningRepository(
          client: MockClient((request) async {
            requested.add(request.url.path);
            final body = bodies[request.url.path];
            if (body == null) return http.Response('', 404);
            return http.Response.bytes(
              utf8.encode(jsonEncode(body)),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
          sessionStore: AuthSessionStore()
            ..save(const AuthSession(accessToken: 'tok-123')),
        ),
        attendanceRepository: FakeAttendanceRepository(),
      ).getLearningMap();

      expect(map!.nodes.map((n) => n.id), [301, 302, 311, 312, 321, 322]);
      expect(map.nodes.map((n) => n.state), [
        JuniorNodeState.completed,
        JuniorNodeState.completed,
        JuniorNodeState.completed,
        JuniorNodeState.current,
        JuniorNodeState.locked,
        JuniorNodeState.locked,
      ]);
      expect(map.nodes.map((n) => n.moduleId), [30, 30, 31, 31, 32, 32]);
      expect(map.checkInNode?.id, 312);
      // Reads only: the learning path, each module's lessons, then each
      // unlocked lesson's detail for its note — never the locked 321/322.
      expect(requested.first, '/me/courses/junior-ai/learning');
      expect(requested.skip(1).toSet(), {
        '/me/modules/30/lessons',
        '/me/modules/31/lessons',
        '/me/modules/32/lessons',
        '/me/lessons/301',
        '/me/lessons/302',
        '/me/lessons/311',
        '/me/lessons/312',
      });
    });
  });

  group('attendance for the check-in node (Issue #410)', () {
    final lesson = NextLesson(
      startsAt: DateTime(2026, 10, 6, 9),
      endsAt: DateTime(2026, 10, 6, 11),
    );
    CourseAttendance attendance(List<(DateTime, String?)> sessions) =>
        CourseAttendance(
          attended: 0,
          totalPast: 0,
          percent: 0,
          sessions: [
            for (final (date, status) in sessions)
              AttendanceSession(date: date, status: status),
          ],
        );

    test('only attended closes check-in: present and late do; absent — '
        'today\'s default before any record — and excused keep it offered '
        '(Issue #443)', () {
      for (final (status, closes) in [
        ('present', true),
        ('late', true),
        ('absent', false),
        ('excused', false),
      ]) {
        expect(
          attendanceRecordedOn(
            attendance([(DateTime(2026, 10, 6), status)]),
            lesson,
          ),
          closes,
          reason: status,
        );
      }
    });

    test('no record yet — or no session that day — is not recorded', () {
      expect(
        attendanceRecordedOn(
          attendance([
            (DateTime(2026, 9, 29), 'present'),
            (DateTime(2026, 10, 6), null),
          ]),
          lesson,
        ),
        isFalse,
      );
      expect(
        attendanceRecordedOn(
          attendance([(DateTime(2026, 9, 29), 'present')]),
          lesson,
        ),
        isFalse,
      );
    });

    test('unknown without a lesson or without attendance', () {
      expect(attendanceRecordedOn(attendance(const []), null), isNull);
      expect(attendanceRecordedOn(null, lesson), isNull);
    });

    test('reads the course\'s attendance and carries the answer', () async {
      final attendanceRepository = FakeAttendanceRepository(
        attendance: attendance([(DateTime(2026, 10, 6), 'present')]),
      );
      final map = await repositoryFor(
        dashboard: HomeDashboard(
          program: sampleProgram(courseSlug: 'junior-ai', nextLesson: lesson),
        ),
        attendance: attendanceRepository,
      ).getLearningMap();

      expect(attendanceRepository.calls, ['junior-ai']);
      expect(map?.attendanceRecorded, isTrue);
      // A read, never a check-in.
      expect(attendanceRepository.checkInCalls, 0);
    });

    test('an unreadable attendance never fails the map, and never opens '
        'check-in — not even during the lesson', () async {
      final map = await repositoryFor(
        dashboard: HomeDashboard(program: sampleProgram(nextLesson: lesson)),
        learning: FakeCourseLearningRepository(
          path: samplePath(
            continueModuleId: 1,
            continueLessonId: 5,
            modules: [sampleModule(id: 1, order: 1)],
          ),
          lessonsByModule: {
            1: [sampleLesson(id: 5, moduleId: 1, order: 1)],
          },
        ),
        attendance: FakeAttendanceRepository(
          failure: const AttendanceFailure(AttendanceFailureKind.network),
        ),
      ).getLearningMap();

      expect(map, isNotNull);
      expect(map!.attendanceRecorded, isNull);
      expect(map.checkInNode?.id, 5);
      expect(map.checkInOpenAt(DateTime(2026, 10, 6, 10)), isFalse);
    });

    test('no next lesson — the course\'s last class has passed: attendance '
        'is still read, and that last class, attended, opens the lesson to '
        'continue with; check-in stays closed (Issue #443)', () async {
      final attendanceRepository = FakeAttendanceRepository(
        attendance: attendance([
          (DateTime(2026, 9, 29), 'present'),
          (DateTime(2026, 10, 6), 'late'),
        ]),
      );
      final map = await repositoryFor(
        dashboard: HomeDashboard(
          program: sampleProgram(courseSlug: 'junior-ai'),
        ),
        learning: FakeCourseLearningRepository(
          path: samplePath(
            continueModuleId: 1,
            continueLessonId: 5,
            modules: [sampleModule(id: 1, order: 1)],
          ),
          lessonsByModule: {
            1: [sampleLesson(id: 5, moduleId: 1, order: 1)],
          },
        ),
        attendance: attendanceRepository,
        // Weeks after the last class (UTC 04:00 = 12:00 in Ulaanbaatar).
        clock: () => DateTime.utc(2026, 11, 2, 4),
      ).getLearningMap();

      expect(attendanceRepository.calls, ['junior-ai']);
      expect(map?.attendanceRecorded, isNull);
      expect(map!.nodes.single.state, JuniorNodeState.attendanceCompleted);
      expect(map.nodes.single.opens, isTrue);
      expect(map.continueAttendanceConfirmed, isTrue);
    });
  });

  test('carries the dashboard\'s next lesson for the check-in node '
      '(Issue #202)', () async {
    final lesson = NextLesson(
      startsAt: DateTime(2026, 10, 6, 9),
      endsAt: DateTime(2026, 10, 6, 11),
    );
    final map = await repositoryFor(
      dashboard: HomeDashboard(program: sampleProgram(nextLesson: lesson)),
    ).getLearningMap();

    expect(map?.nextLesson, same(lesson));
  });
}

/// The fixtures' `completed: true` stands for a saved, non-empty note
/// (Issue #415): completion is the note, not the server's flag. As in the
/// repository, a locked lesson's note is never read.
JuniorLearningMap mapFrom(
  CourseLearningPath path, {
  Map<int, List<Lesson>> lessons = const {},
  NextLesson? nextLesson,
  bool? attendanceRecorded,
  bool? attendanceConfirmed,
}) => juniorMapFrom(
  path,
  lessons: lessons,
  nextLesson: nextLesson,
  attendanceRecorded: attendanceRecorded,
  attendanceConfirmed: attendanceConfirmed,
  completedByNote: {
    for (final module in path.modules)
      for (final lesson in lessons[module.id] ?? const <Lesson>[])
        if (lesson.completed && !lesson.locked && !module.locked) lesson.id,
  },
);
