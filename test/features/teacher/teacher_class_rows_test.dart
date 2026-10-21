import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/teacher/data/http_teacher_gradebook_repository.dart';
import 'package:aia_mobile/features/teacher/data/http_teacher_home_repository.dart';
import 'package:aia_mobile/features/teacher/data/http_teacher_schedule_repository.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_controller.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../courses/fake_course_repository.dart';
import '../profile/fake_current_user_repository.dart';
import 'fake_teacher_home_repository.dart';

/// Issue #445 on the teacher's own screens. Every class in the teacher's
/// schedule is their own, so a malformed one fails closed: Teacher Schedule
/// (the landing tab) and Teacher Programs show their existing error with
/// retry, never a class list with that class silently missing. Each screen's
/// controller runs on its real repository, fed by the real class reader on
/// a `MockClient`.
void main() {
  http.Response json(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: {HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8'},
  );

  /// One class in `GET /cohorts`'s shape. Test values only.
  Map<String, dynamic> cohort(
    int id, {
    Map<String, dynamic> overrides = const {},
  }) => {
    'id': id,
    'name': 'Cohort $id',
    'course_id': 8,
    'course': {
      'id': 8,
      'slug': 'ai-engineering',
      'title_en': 'AI Engineer',
      'title_mn': null,
    },
    'classroom': null,
    'teacher': {'id': 7, 'name': 'Test Teacher'},
    'capacity': 30,
    'enrolled_count': 24,
    'seats_available': 6,
    'status': 'open',
    'start_date': '2026-09-01',
    'end_date': '2026-12-20',
    'start_time': '14:00',
    'end_time': '17:00',
    'graduation_date': '2026-12-25',
    'meeting_days': ['tue', 'thu'],
    'parent_cohort_id': null,
    'schedule_note': null,
    ...overrides,
  };

  AuthSessionStore signedIn() =>
      AuthSessionStore()..save(const AuthSession(accessToken: 'tok-123'));

  /// The class reader every teacher screen shares, answering the schedule
  /// with [cohorts].
  HttpTeacherHomeRepository classesAnswering(List<Object?> cohorts) {
    final store = signedIn();
    return HttpTeacherHomeRepository(
      client: MockClient(
        (_) async => json({'teacher_id': 7, 'cohorts': cohorts}),
      ),
      sessionStore: store,
      currentUser: FakeCurrentUserRepository(user: teacherUser()),
      courses: FakeCourseRepository(),
    );
  }

  /// Answers a week's sessions with none, for the valid-schedule control:
  /// each cohort's sessions, and — since Issue #455 — the teacher's own
  /// `GET /teacher/sessions` range read, also empty.
  MockClient noSessions() => MockClient(
    (request) async => request.url.path == '/teacher/sessions'
        ? json({
            'from': request.url.queryParameters['from'],
            'to': request.url.queryParameters['to'],
            'items': <Object>[],
          })
        : json({
            'cohort_id': int.parse(request.url.pathSegments[2]),
            'sessions': <Object>[],
          }),
  );

  final serverMessage = TeacherHomeStrings.messageFor(
    TeacherFailureKind.server,
  );
  final aMonday = DateTime(2026, 10, 19, 9);

  group('Teacher Schedule', () {
    TeacherScheduleController controllerFor(List<Object?> cohorts) =>
        TeacherScheduleController(
          repository: HttpTeacherScheduleRepository(
            client: noSessions(),
            sessionStore: signedIn(),
            classes: classesAnswering(cohorts),
          ),
          clock: () => aMonday,
        );

    test('a malformed class is the server error, not a week with that class '
        'missing', () async {
      final controller = controllerFor([
        cohort(2),
        cohort(3, overrides: {'teacher': null}),
      ]);

      await controller.load();

      expect(controller.errorMessage, serverMessage);
    });

    test(
      'a class with no graduation date or capacity loads (Issue #489)',
      () async {
        final controller = controllerFor([
          cohort(2),
          cohort(
            3,
            overrides: {
              'graduation_date': null,
              'capacity': null,
              'seats_available': null,
            },
          ),
        ]);

        await controller.load();

        expect(controller.errorMessage, isNull);
      },
    );

    test(
      'a class with no dates, times or meeting days loads (Issue #491)',
      () async {
        final controller = controllerFor([
          cohort(2),
          cohort(
            3,
            overrides: {
              'start_date': null,
              'end_date': null,
              'start_time': null,
              'end_time': null,
              'meeting_days': null,
            },
          ),
        ]);

        await controller.load();

        expect(controller.errorMessage, isNull);
      },
    );

    test(
      'control: the same schedule without the malformed class loads',
      () async {
        final controller = controllerFor([cohort(2)]);

        await controller.load();

        expect(controller.errorMessage, isNull);
      },
    );
  });

  group('Teacher Programs', () {
    TeacherHomeController controllerFor(List<Object?> cohorts) =>
        TeacherHomeController(
          repository: HttpTeacherGradebookRepository(
            client: MockClient((_) async => fail('no other request expected')),
            sessionStore: signedIn(),
            classes: classesAnswering(cohorts),
          ),
          clock: () => aMonday,
        );

    test('a malformed class is the server error, not the programme '
        'list with that class missing', () async {
      final controller = controllerFor([
        cohort(2),
        cohort(3, overrides: {'capacity': 'thirty'}),
      ]);

      await controller.load();

      expect(controller.errorMessage, serverMessage);
      expect(controller.classes, isNull);
    });

    test(
      'a class with no dates, times or meeting days is listed (Issue #491)',
      () async {
        final controller = controllerFor([
          cohort(2),
          cohort(
            5,
            overrides: {
              'start_date': null,
              'end_date': null,
              'start_time': null,
              'end_time': null,
              'meeting_days': null,
            },
          ),
        ]);

        await controller.load();

        expect(controller.errorMessage, isNull);
        expect([for (final c in controller.classes!) c.cohort.id], [2, 5]);
      },
    );

    test('control: the same classes without the malformed one load', () async {
      final controller = controllerFor([cohort(2), cohort(5)]);

      await controller.load();

      expect(controller.errorMessage, isNull);
      expect([for (final c in controller.classes!) c.cohort.id], [2, 5]);
    });
  });
}
