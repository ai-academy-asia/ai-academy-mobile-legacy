import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/core/api/api_config.dart';
import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/features/cohorts/data/http_cohort_repository.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort_listing.dart';
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

      final cohorts = (await repository.getCohorts()).cohorts;

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

      final course = (await repository.getCohorts()).cohorts.single.course;

      expect(course.id, 6);
      expect(course.slug, 'summer-bootcamp-2027');
      expect(course.title.en, 'Summer Bootcamp');
      expect(course.title.mn, 'Зуны бүтээлч кэмп');
    });

    test('parses the nested classroom object', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(confirmedResponseBody, 200),
      );

      final classroom =
          (await repository.getCohorts()).cohorts.single.classroom!;

      expect(classroom.id, 1);
      expect(classroom.name, 'Room 301');
      expect(classroom.centerName, 'AI Academy Central');
    });

    test('parses the nested teacher object', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(confirmedResponseBody, 200),
      );

      final teacher = (await repository.getCohorts()).cohorts.single.teacher;

      expect(teacher!.id, 2);
      expect(teacher.name, 'Сараа Ганбат');
    });

    test('parses the nullable fields that were null as null', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(confirmedResponseBody, 200),
      );

      final cohort = (await repository.getCohorts()).cohorts.single;

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

      final cohort = (await repository.getCohorts()).cohorts.single;

      expect(cohort.parentCohortId, 7);
      expect(cohort.scheduleNote, 'Moved from Room 202');
    });

    test('an empty list is an empty list, not an error', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(jsonEncode({'cohorts': []}), 200),
      );

      expect((await repository.getCohorts()).cohorts, isEmpty);
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

      final cohorts = (await repository.getCohorts()).cohorts;

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
  });

  // Issue #445: a row the parser rejects is skipped and reported, not a
  // failure of the whole list. Each case below is one bad row on its own, so
  // the listing is empty and its report names the failing field.
  // Issue #489: `Cohort.to_dict` always sends these keys; the backend never
  // requires a graduation date or a capacity, and `seats_available` is null
  // whenever `capacity` is.
  group('null graduation_date, capacity and seats_available (Issue #489)', () {
    Future<CohortListing> listingOf(List<Object?> rows) => repositoryReturning(
      (_) async => jsonResponse(jsonEncode({'cohorts': rows}), 200),
    ).getCohorts();

    test('each null reads as null, and the cohort is listed, not skipped', () async {
      final listing = await listingOf([
        _cohortJson(overrides: {'id': 1}),
        _cohortJson(overrides: {'id': 2, 'graduation_date': null}),
        _cohortJson(overrides: {'id': 3, 'capacity': null, 'seats_available': null}),
        _cohortJson(
          overrides: {
            'id': 4,
            'graduation_date': null,
            'capacity': null,
            'seats_available': null,
          },
        ),
      ]);

      expect(listing.skipped, isEmpty);
      expect(listing.cohorts.map((c) => c.id), [1, 2, 3, 4]);
      expect(listing.cohorts[1].graduationDate, isNull);
      expect(listing.cohorts[1].capacity, 20);
      expect(listing.cohorts[2].capacity, isNull);
      expect(listing.cohorts[2].seatsAvailable, isNull);
      expect(listing.cohorts[2].graduationDate, '2026-10-10');
      expect(listing.cohorts[3].name, 'Corporate Leaders 2026-08');
      expect(listing.cohorts[3].teacher!.id, 2);
    });

    test('a missing key is still skipped, naming the field', () async {
      for (final field in ['graduation_date', 'capacity', 'seats_available']) {
        final listing = await listingOf([_cohortJson()..remove(field)]);
        expect(listing.cohorts, isEmpty, reason: field);
        expect(listing.skipped.single.reason, contains('cohort.$field'), reason: field);
      }
    });

    test('a wrong type is still skipped, naming the field', () async {
      final wrong = <String, Object>{
        'graduation_date': 20261010,
        'capacity': '20',
        'seats_available': true,
      };
      for (final MapEntry(key: field, value: value) in wrong.entries) {
        final listing = await listingOf([
          _cohortJson(overrides: {field: value}),
        ]);
        expect(listing.cohorts, isEmpty, reason: field);
        expect(listing.skipped.single.reason, contains('cohort.$field'), reason: field);
      }
    });

    test('no other field is loosened: a null enrolled count is still skipped', () async {
      for (final field in ['enrolled_count']) {
        final listing = await listingOf([
          _cohortJson(overrides: {field: null, 'graduation_date': null}),
        ]);
        expect(listing.cohorts, isEmpty, reason: field);
        expect(listing.skipped.single.reason, contains('cohort.$field'), reason: field);
      }
    });
  });

  // Issue #491: `Cohort.to_dict` always sends these keys; the backend never
  // requires dates, times or meeting days. `null` reads as the "not set"
  // value every schedule reader already handles: `''`, or `[]`.
  group('null dates, times and meeting days (Issue #491)', () {
    const schedule = ['start_date', 'end_date', 'start_time', 'end_time', 'meeting_days'];

    Future<CohortListing> listingOf(List<Object?> rows) => repositoryReturning(
      (_) async => jsonResponse(jsonEncode({'cohorts': rows}), 200),
    ).getCohorts();

    test('each null reads as not set, and the cohort is listed in order', () async {
      final listing = await listingOf([
        _cohortJson(overrides: {'id': 1}),
        for (final (i, field) in schedule.indexed)
          _cohortJson(overrides: {'id': i + 2, field: null}),
        _cohortJson(overrides: {'id': 9, for (final field in schedule) field: null}),
      ]);

      expect(listing.skipped, isEmpty);
      expect(listing.cohorts.map((c) => c.id), [1, 2, 3, 4, 5, 6, 9]);
      final bare = listing.cohorts.last;
      expect(bare.startDate, '');
      expect(bare.endDate, '');
      expect(bare.startTime, '');
      expect(bare.endTime, '');
      expect(bare.meetingDays, isEmpty);
      expect(bare.teacher!.id, 2);
      expect(listing.cohorts[1].startDate, '');
      expect(listing.cohorts[1].endDate, '2026-10-06');
      expect(listing.cohorts[5].meetingDays, isEmpty);
      expect(listing.cohorts[5].startTime, '18:00');
    });

    test('an empty string or list is kept as sent', () async {
      final listing = await listingOf([
        _cohortJson(
          overrides: {'start_time': '', 'end_time': '', 'meeting_days': <String>[]},
        ),
      ]);

      final cohort = listing.cohorts.single;
      expect(cohort.startTime, '');
      expect(cohort.endTime, '');
      expect(cohort.meetingDays, isEmpty);
    });

    test('a missing key is still skipped, naming the field', () async {
      for (final field in schedule) {
        final listing = await listingOf([_cohortJson()..remove(field)]);
        expect(listing.cohorts, isEmpty, reason: field);
        expect(listing.skipped.single.reason, contains('cohort.$field'), reason: field);
      }
    });

    test('a wrong type is still skipped, naming the field', () async {
      final wrong = <String, Object>{
        'start_date': 20260806,
        'end_date': true,
        'start_time': 1800,
        'end_time': <Object?>[],
        'meeting_days': 'mon,wed',
      };
      for (final MapEntry(key: field, value: value) in wrong.entries) {
        final listing = await listingOf([
          _cohortJson(overrides: {field: value}),
        ]);
        expect(listing.cohorts, isEmpty, reason: field);
        expect(listing.skipped.single.reason, contains('cohort.$field'), reason: field);
      }
      final listing = await listingOf([
        _cohortJson(overrides: {'meeting_days': ['mon', 3]}),
      ]);
      expect(listing.skipped.single.reason, contains('cohort.meeting_days'));
    });
  });

  group('malformed rows', () {
    Future<CohortListing> listingOf(List<Object?> rows) => repositoryReturning(
      (_) async => jsonResponse(jsonEncode({'cohorts': rows}), 200),
    ).getCohorts();

    Future<SkippedCohort> skippedRow(Object? row) async {
      final listing = await listingOf([row]);
      expect(listing.cohorts, isEmpty);
      return listing.skipped.single;
    }

    test(
      'a cohort entry that is not an object is skipped, with no id',
      () async {
        final skipped = await skippedRow('not-an-object');
        expect(skipped.id, isNull);
        expect(skipped.reason, contains('cohort entry'));
      },
    );

    test('a cohort entry missing a required field names that field', () async {
      final skipped = await skippedRow(_cohortJson()..remove('name'));
      expect(skipped.id, 1);
      expect(skipped.reason, contains('cohort.name'));
    });

    test('a required field with the wrong type names that field', () async {
      final skipped = await skippedRow(
        _cohortJson(overrides: {'capacity': 'twenty'}),
      );
      expect(skipped.reason, contains('cohort.capacity'));
    });

    test('a missing nested object names the field', () async {
      // The `teacher` key is still required — its value may be `null` (Issue
      // #493). `classroom` may be absent or null: see the "nullable
      // classroom" group.
      final skipped = await skippedRow(_cohortJson()..remove('teacher'));
      expect(skipped.reason, contains('cohort.teacher'));
    });

    test('a null teacher — none assigned, or a deleted teacher — is a cohort '
        'with no teacher, not a malformed row (Issue #493)', () async {
      final listing = await listingOf([
        _cohortJson(overrides: {'id': 1}),
        _cohortJson(overrides: {'id': 2, 'teacher': null}),
      ]);

      expect(listing.skipped, isEmpty);
      expect(listing.cohorts.map((c) => c.id), [1, 2]);
      expect(listing.cohorts.first.teacher!.id, 2);
      expect(listing.cohorts.last.teacher, isNull);
      expect(listing.cohorts.last.name, 'Corporate Leaders 2026-08');
      expect(listing.cohorts.last.course.slug, 'summer-bootcamp-2027');
    });

    test('a sent teacher must still be an object with a number id and a '
        'string name', () async {
      for (final teacher in <Object?>[
        <String, dynamic>{},
        {'id': 2},
        {'name': 'Сараа'},
        {'id': '2', 'name': 'Сараа'},
        {'id': 2, 'name': null},
        {'id': 2, 'name': 7},
      ]) {
        final skipped = await skippedRow(_cohortJson(overrides: {'teacher': teacher}));
        expect(skipped.id, 1, reason: '$teacher');
        expect(skipped.reason, anyOf(contains('cohort.id'), contains('cohort.name')),
            reason: '$teacher');
      }
    });

    test('a non-object nested field names the field', () async {
      final skipped = await skippedRow(
        _cohortJson(overrides: {'teacher': 'Bat'}),
      );
      expect(skipped.reason, contains('cohort.teacher'));
    });

    test('meeting_days not being a list names the field', () async {
      final skipped = await skippedRow(
        _cohortJson(overrides: {'meeting_days': 'mon'}),
      );
      expect(skipped.reason, contains('cohort.meeting_days'));
    });

    test('a non-string item inside meeting_days names the field', () async {
      final skipped = await skippedRow(
        _cohortJson(
          overrides: {
            'meeting_days': ['mon', 3],
          },
        ),
      );
      expect(skipped.reason, contains('cohort.meeting_days'));
    });

    test('a malformed id is skipped with no id, so it is never mistaken '
        'for another cohort', () async {
      for (final id in <Object?>[null, '7', true]) {
        final skipped = await skippedRow(_cohortJson(overrides: {'id': id}));
        expect(skipped.id, isNull, reason: '$id');
        expect(skipped.reason, contains('cohort.id'), reason: '$id');
      }
    });

    test('a malformed row sharing its id with a valid row is still '
        'reported under that id, so the id stays suspect', () async {
      final listing = await listingOf([
        _cohortJson(overrides: {'id': 5, 'name': 'Valid'}),
        _cohortJson(overrides: {'id': 5, 'teacher': 'Bat'}),
      ]);

      expect(listing.cohorts.single.id, 5);
      expect(listing.skipped.single.id, 5);
      expect(listing.mayHideAny(const [5]), isTrue);
    });

    test('a non-whole-number id on a malformed row is reported with no id '
        '(never truncated to another cohort\'s)', () async {
      final listing = await listingOf([
        _cohortJson(overrides: {'id': 7}),
        _cohortJson(overrides: {'id': 7.5, 'teacher': 'Bat'}),
      ]);

      expect(listing.cohorts.single.id, 7);
      expect(listing.skipped.single.id, isNull);
      expect(listing.skipped.single.reason, contains('cohort.teacher'));
      // Unreadable id: suspect for any id the valid rows do not carry.
      expect(listing.mayHideAny(const [7]), isFalse);
      expect(listing.mayHideAny(const [8]), isTrue);
    });

    test('one malformed row among valid ones: the valid rows are returned, '
        'in order, and the malformed one is reported', () async {
      final listing = await listingOf([
        _cohortJson(overrides: {'id': 1, 'name': 'A'}),
        _cohortJson(overrides: {'id': 2, 'teacher': 'Bat'}),
        _cohortJson(overrides: {'id': 3, 'name': 'C'}),
      ]);

      expect(listing.cohorts.map((c) => c.id), [1, 3]);
      expect(listing.cohorts.map((c) => c.name), ['A', 'C']);
      expect(listing.skipped.single.id, 2);
      expect(listing.skipped.single.reason, contains('cohort.teacher'));
    });

    test('every row malformed: no cohorts, every row reported', () async {
      final listing = await listingOf([
        _cohortJson(overrides: {'id': 1, 'teacher': 'Bat'}),
        _cohortJson(overrides: {'id': 2})..remove('start_date'),
        'not-an-object',
      ]);

      expect(listing.cohorts, isEmpty);
      expect(listing.skipped.map((s) => s.id), [1, 2, null]);
    });

    test('the report names fields and types, never a response value', () async {
      final listing = await listingOf([
        _cohortJson(
          overrides: {
            'id': 9,
            'teacher': 'Сараа Ганбат',
            'capacity': 'secret-value',
          },
        ),
      ]);

      final reason = listing.skipped.single.reason;
      expect(reason, isNot(contains('Сараа')));
      expect(reason, isNot(contains('secret-value')));
      expect(listing.describeSkipped(), isNot(contains('Сараа')));
    });
  });

  group('nullable classroom (production GET /cohorts)', () {
    /// The row is rejected — skipped and reported since Issue #445.
    Future<SkippedCohort> rejection(Map<String, dynamic> cohort) async {
      final body = jsonEncode({
        'cohorts': [cohort],
      });
      final listing = await repositoryReturning(
        (_) async => jsonResponse(body, 200),
      ).getCohorts();
      expect(listing.cohorts, isEmpty);
      return listing.skipped.single;
    }

    test('classroom: null is accepted as no classroom', () async {
      final body = jsonEncode({
        'cohorts': [
          _cohortJson(overrides: {'classroom': null}),
        ],
      });

      final cohort = (await repositoryReturning(
        (_) async => jsonResponse(body, 200),
      ).getCohorts()).cohorts.single;

      expect(cohort.classroom, isNull);
      expect(cohort.id, 1);
      expect(cohort.teacher!.name, 'Сараа Ганбат');
    });

    test(
      'the production online cohort no longer fails the whole list',
      () async {
        // Cohort 4 as the live response sends it, between two that have a
        // classroom — the list used to be rejected all-or-nothing over it.
        final online = _cohortJson(
          overrides: {
            'id': 4,
            'name': 'AI Applied — Online',
            'status': 'closed',
            'classroom': null,
            'course': {
              'id': 10,
              'slug': 'ai-applied-online',
              'title_en': 'AI Applied (Online)',
              'title_mn': 'AI Applied (Онлайн)',
            },
            'course_id': 10,
          },
        );
        final body = jsonEncode({
          'cohorts': [
            _cohortJson(overrides: {'id': 2}),
            online,
            _cohortJson(overrides: {'id': 3}),
          ],
        });

        final cohorts = (await repositoryReturning(
          (_) async => jsonResponse(body, 200),
        ).getCohorts()).cohorts;

        expect(cohorts.map((c) => c.id), [2, 4, 3]);
        expect(cohorts[1].classroom, isNull);
        expect(cohorts[1].course.slug, 'ai-applied-online');
        expect(cohorts[0].classroom!.name, 'Room 301');
        expect(cohorts[2].classroom!.name, 'Room 301');
      },
    );

    test('an absent classroom key reads as no classroom too', () async {
      final body = jsonEncode({
        'cohorts': [_cohortJson()..remove('classroom')],
      });

      final cohort = (await repositoryReturning(
        (_) async => jsonResponse(body, 200),
      ).getCohorts()).cohorts.single;

      expect(cohort.classroom, isNull);
    });

    test('a classroom that is not an object is still rejected', () async {
      for (final malformed in <Object>['Room 301', 301, ['Room 301']]) {
        final failure = await rejection(
          _cohortJson(overrides: {'classroom': malformed}),
        );

        expect(
          failure.reason,
          contains('cohort.classroom'),
          reason: '$malformed',
        );
      }
    });

    test('a classroom object missing a required field is still rejected', () async {
      final failure = await rejection(
        _cohortJson(overrides: {
          'classroom': {'id': 1, 'name': 'Room 301'},
        }),
      );

        expect(failure.reason, contains('center_name'));
      },
    );
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

    test('a TLS handshake failure is a network failure, not unexpected (Issue #339)', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => throw const HandshakeException('Handshake error in client')),
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
    test('the default base URL is the shared ApiConfig — the contract host '
        'when no override is defined (Issue #388)', () {
      expect(ApiConfig.baseUrl, Uri.parse('https://api.ai-academy.asia'));
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
