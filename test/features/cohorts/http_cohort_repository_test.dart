import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/features/cohorts/data/http_cohort_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// `http.Response`'s string constructor falls back to latin1 unless the
/// content-type header says otherwise, and the confirmed payload's Mongolian
/// text is not latin1-representable. Every JSON body in this file goes
/// through this helper rather than the bare constructor, so that is never a
/// surprise. Same fix `http_course_repository_test.dart` needed.
http.Response jsonResponse(String body, int statusCode) => http.Response(
  body,
  statusCode,
  headers: {HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8'},
);

void main() {
  HttpCohortRepository repositoryReturning(
    Future<http.Response> Function(http.Request request) handler,
  ) => HttpCohortRepository(client: MockClient(handler));

  /// The exact response given in the confirmed contract, byte for byte.
  const confirmedResponseBody = '''
  {
    "cohorts": [
      {
        "capacity": 20,
        "classroom": {
          "center_name": "AI Academy Central",
          "id": 1,
          "name": "Room 301"
        },
        "course": {
          "id": 6,
          "slug": "summer-bootcamp-2027",
          "title_en": "Summer Bootcamp",
          "title_mn": "Зуны бүтээлч кэмп"
        },
        "course_id": 6,
        "end_date": "2026-10-06",
        "end_time": "20:00",
        "enrolled_count": 0,
        "graduation_date": "2026-10-10",
        "id": 1,
        "meeting_days": ["mon", "wed"],
        "name": "Corporate Leaders 2026-08",
        "parent_cohort_id": null,
        "schedule_note": null,
        "seats_available": 20,
        "start_date": "2026-08-06",
        "start_time": "18:00",
        "status": "open",
        "teacher": {
          "id": 2,
          "name": "Сараа Ганбат"
        }
      }
    ]
  }
  ''';

  group('the request', () {
    test('GETs the confirmed URL with an Accept header and no body', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return jsonResponse(confirmedResponseBody, 200);
      });

      await repository.getCohorts();

      expect(sent.method, 'GET');
      expect(sent.url.toString(), 'https://api.ai-academy.asia/cohorts');
      expect(sent.headers[HttpHeaders.acceptHeader], 'application/json');
      expect(sent.body, isEmpty);
    });

    test('sends no Authorization header', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return jsonResponse(confirmedResponseBody, 200);
      });

      await repository.getCohorts();

      expect(sent.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('a successful response', () {
    test('parses every field of the confirmed example', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(confirmedResponseBody, 200),
      );

      final cohorts = await repository.getCohorts();

      expect(cohorts, hasLength(1));
      final cohort = cohorts.single;
      expect(cohort.id, 1);
      expect(cohort.name, 'Corporate Leaders 2026-08');
      expect(cohort.courseId, 6);
      expect(cohort.capacity, 20);
      expect(cohort.enrolledCount, 0);
      expect(cohort.seatsAvailable, 20);
      expect(cohort.status, 'open');
      expect(cohort.startDate, '2026-08-06');
      expect(cohort.endDate, '2026-10-06');
      expect(cohort.startTime, '18:00');
      expect(cohort.endTime, '20:00');
      expect(cohort.graduationDate, '2026-10-10');
      expect(cohort.meetingDays, ['mon', 'wed']);
    });

    test('parses the nested course object', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(confirmedResponseBody, 200),
      );

      final course = (await repository.getCohorts()).single.course;

      expect(course.id, 6);
      expect(course.slug, 'summer-bootcamp-2027');
      expect(course.title.en, 'Summer Bootcamp');
      expect(course.title.mn, 'Зуны бүтээлч кэмп');
    });

    test('parses the nested classroom object', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(confirmedResponseBody, 200),
      );

      final classroom = (await repository.getCohorts()).single.classroom;

      expect(classroom.id, 1);
      expect(classroom.name, 'Room 301');
      expect(classroom.centerName, 'AI Academy Central');
    });

    test('parses the nested teacher object', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(confirmedResponseBody, 200),
      );

      final teacher = (await repository.getCohorts()).single.teacher;

      expect(teacher.id, 2);
      expect(teacher.name, 'Сараа Ганбат');
    });

    test('parses the nullable fields that were null as null', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(confirmedResponseBody, 200),
      );

      final cohort = (await repository.getCohorts()).single;

      expect(cohort.parentCohortId, isNull);
      expect(cohort.scheduleNote, isNull);
    });

    test('parses a nullable field that was present, not null', () async {
      final body = jsonEncode({
        'cohorts': [
          _cohortJson(
            overrides: {'parent_cohort_id': 7, 'schedule_note': 'Moved from Room 202'},
          ),
        ],
      });
      final repository = repositoryReturning((_) async => jsonResponse(body, 200));

      final cohort = (await repository.getCohorts()).single;

      expect(cohort.parentCohortId, 7);
      expect(cohort.scheduleNote, 'Moved from Room 202');
    });

    test('an empty list is an empty list, not an error', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(jsonEncode({'cohorts': []}), 200),
      );

      expect(await repository.getCohorts(), isEmpty);
    });

    test('parses every cohort in a multi-cohort response, in order', () async {
      final body = jsonEncode({
        'cohorts': [
          _cohortJson(overrides: {'id': 1, 'name': 'A'}),
          _cohortJson(overrides: {'id': 2, 'name': 'B'}),
          _cohortJson(overrides: {'id': 3, 'name': 'C'}),
        ],
      });
      final repository = repositoryReturning((_) async => jsonResponse(body, 200));

      final cohorts = await repository.getCohorts();

      expect(cohorts.map((c) => c.id), [1, 2, 3]);
      expect(cohorts.map((c) => c.name), ['A', 'B', 'C']);
    });
  });

  group('malformed responses', () {
    Future<ApiFailure> failureFrom(HttpCohortRepository repository) async {
      try {
        await repository.getCohorts();
      } on ApiFailure catch (failure) {
        return failure;
      }
      fail('expected an ApiFailure');
    }

    test('a malformed body is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('<html>nope</html>', 200)),
      );
      expect(failure.kind, ApiFailureKind.server);
      expect(failure.detail, contains('malformed JSON'));
    });

    test('a JSON array instead of an object is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => jsonResponse('[]', 200)),
      );
      expect(failure.kind, ApiFailureKind.server);
    });

    test('a response with no "cohorts" key is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => jsonResponse(jsonEncode({'data': []}), 200)),
      );
      expect(failure.kind, ApiFailureKind.server);
      expect(failure.detail, contains('cohorts'));
    });

    test('a cohort entry that is not an object is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning(
          (_) async => jsonResponse(
            jsonEncode({
              'cohorts': ['not-an-object'],
            }),
            200,
          ),
        ),
      );
      expect(failure.kind, ApiFailureKind.server);
      expect(failure.detail, contains('cohort entry'));
    });

    test('a cohort entry missing a required field names that field', () async {
      final json = _cohortJson()..remove('name');
      final body = jsonEncode({
        'cohorts': [json],
      });

      final failure = await failureFrom(
        repositoryReturning((_) async => jsonResponse(body, 200)),
      );

      expect(failure.kind, ApiFailureKind.server);
      expect(failure.detail, contains('cohort.name'));
    });

    test('a required field with the wrong type names that field', () async {
      final body = jsonEncode({
        'cohorts': [
          _cohortJson(overrides: {'capacity': 'twenty'}),
        ],
      });

      final failure = await failureFrom(
        repositoryReturning((_) async => jsonResponse(body, 200)),
      );

      expect(failure.kind, ApiFailureKind.server);
      expect(failure.detail, contains('cohort.capacity'));
    });

    test('a missing nested object names the field', () async {
      final json = _cohortJson()..remove('classroom');
      final body = jsonEncode({
        'cohorts': [json],
      });

      final failure = await failureFrom(
        repositoryReturning((_) async => jsonResponse(body, 200)),
      );

      expect(failure.kind, ApiFailureKind.server);
      expect(failure.detail, contains('cohort.classroom'));
    });

    test('a non-object nested field names the field', () async {
      final body = jsonEncode({
        'cohorts': [
          _cohortJson(overrides: {'teacher': 'Bat'}),
        ],
      });

      final failure = await failureFrom(
        repositoryReturning((_) async => jsonResponse(body, 200)),
      );

      expect(failure.kind, ApiFailureKind.server);
      expect(failure.detail, contains('cohort.teacher'));
    });

    test('meeting_days not being a list names the field', () async {
      final body = jsonEncode({
        'cohorts': [
          _cohortJson(overrides: {'meeting_days': 'mon'}),
        ],
      });

      final failure = await failureFrom(
        repositoryReturning((_) async => jsonResponse(body, 200)),
      );

      expect(failure.kind, ApiFailureKind.server);
      expect(failure.detail, contains('cohort.meeting_days'));
    });

    test('a non-string item inside meeting_days names the field', () async {
      final body = jsonEncode({
        'cohorts': [
          _cohortJson(
            overrides: {
              'meeting_days': ['mon', 3],
            },
          ),
        ],
      });

      final failure = await failureFrom(
        repositoryReturning((_) async => jsonResponse(body, 200)),
      );

      expect(failure.kind, ApiFailureKind.server);
      expect(failure.detail, contains('cohort.meeting_days'));
    });
  });

  group('HTTP failures', () {
    Future<ApiFailure> failureFrom(HttpCohortRepository repository) async {
      try {
        await repository.getCohorts();
      } on ApiFailure catch (failure) {
        return failure;
      }
      fail('expected an ApiFailure');
    }

    test('5xx is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('boom', 500)),
      );
      expect(failure.kind, ApiFailureKind.server);
    });

    test('other non-2xx are unexpected', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('{"error":"nope"}', 404)),
      );
      expect(failure.kind, ApiFailureKind.unexpected);
    });

    test('an unreachable host is a network failure', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => throw const SocketException('no route')),
      );
      expect(failure.kind, ApiFailureKind.network);
    });

    test('a client exception is a network failure', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => throw http.ClientException('closed')),
      );
      expect(failure.kind, ApiFailureKind.network);
    });

    test('a slow backend times out rather than hanging the caller', () async {
      final repository = HttpCohortRepository(
        client: MockClient(
          (_) => Future.delayed(
            const Duration(milliseconds: 200),
            () => jsonResponse(confirmedResponseBody, 200),
          ),
        ),
        timeout: const Duration(milliseconds: 20),
      );

      final failure = await failureFrom(repository);

      expect(failure.kind, ApiFailureKind.network);
      expect(failure.detail, 'request timed out');
    });
  });

  group('configuration', () {
    test('the default base URL is the contract host', () {
      expect(HttpCohortRepository.defaultBaseUrl, 'https://api.ai-academy.asia');
    });

    test('a base URL can be overridden without touching the path', () async {
      late Uri url;
      final repository = HttpCohortRepository(
        baseUrl: Uri.parse('https://staging.example.test'),
        client: MockClient((request) async {
          url = request.url;
          return jsonResponse(jsonEncode({'cohorts': []}), 200);
        }),
      );

      await repository.getCohorts();

      expect(url.toString(), 'https://staging.example.test/cohorts');
    });
  });
}

/// A cohort JSON object matching the confirmed example, with [overrides]
/// applied — or a key removed by setting it to nothing and calling `.remove`
/// on the result, since a returned `Map` from this helper is mutable.
Map<String, dynamic> _cohortJson({Map<String, dynamic> overrides = const {}}) => {
  'capacity': 20,
  'classroom': {'center_name': 'AI Academy Central', 'id': 1, 'name': 'Room 301'},
  'course': {
    'id': 6,
    'slug': 'summer-bootcamp-2027',
    'title_en': 'Summer Bootcamp',
    'title_mn': 'Зуны бүтээлч кэмп',
  },
  'course_id': 6,
  'end_date': '2026-10-06',
  'end_time': '20:00',
  'enrolled_count': 0,
  'graduation_date': '2026-10-10',
  'id': 1,
  'meeting_days': ['mon', 'wed'],
  'name': 'Corporate Leaders 2026-08',
  'parent_cohort_id': null,
  'schedule_note': null,
  'seats_available': 20,
  'start_date': '2026-08-06',
  'start_time': '18:00',
  'status': 'open',
  'teacher': {'id': 2, 'name': 'Сараа Ганбат'},
  ...overrides,
};
