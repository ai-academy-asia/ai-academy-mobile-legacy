import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/features/courses/data/http_course_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Exercises the wire format against the confirmed contract:
///
///     GET https://api.ai-academy.asia/courses
///     -> { "courses": [ { ...19 fields... } ] }
///
/// No authentication, so unlike the auth repository tests there is no session
/// to set up and no Authorization header to expect.
/// `http.Response`'s string constructor falls back to latin1 unless the
/// content-type header says otherwise, and the confirmed payload's Mongolian
/// text is not latin1-representable. Every JSON body in this file goes through
/// this helper rather than the bare constructor, so that is never a surprise.
http.Response jsonResponse(String body, int statusCode) => http.Response(
  body,
  statusCode,
  headers: {HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8'},
);

void main() {
  HttpCourseRepository repositoryReturning(
    Future<http.Response> Function(http.Request request) handler,
  ) => HttpCourseRepository(client: MockClient(handler));

  /// The exact response given in the confirmed contract, byte for byte.
  const confirmedResponseBody = '''
  {
    "courses": [
      {
        "age_max": 18,
        "age_min": 10,
        "banner_image_url": null,
        "category": "bootcamp",
        "currency": "MNT",
        "discount_percent": 20,
        "duration_label": null,
        "duration_weeks": 3,
        "end_date": "2026-06-21",
        "final_price_amount": 960000.0,
        "format": "in_person",
        "icon": null,
        "id": 4,
        "level": "junior",
        "price_amount": 1200000.0,
        "slug": "summer-bootcamp",
        "sort_order": null,
        "start_date": "2026-06-01",
        "status": "open",
        "tagline": {"en": null, "mn": "3 долоо хоногийн эрчимжүүлсэн"},
        "target_audience": null,
        "title": {"en": "Summer Bootcamp", "mn": "Зуны бүтээлч кэмп"}
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

      await repository.getCourses();

      expect(sent.method, 'GET');
      expect(sent.url.toString(), 'https://api.ai-academy.asia/courses');
      expect(sent.headers[HttpHeaders.acceptHeader], 'application/json');
      expect(sent.body, isEmpty);
    });

    test('sends no Authorization header — the endpoint is public', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return jsonResponse(confirmedResponseBody, 200);
      });

      await repository.getCourses();

      expect(sent.headers.containsKey('Authorization'), isFalse);
      expect(sent.headers.containsKey(HttpHeaders.contentTypeHeader), isFalse);
    });
  });

  group('a successful response', () {
    test('parses every field of the confirmed example', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(confirmedResponseBody, 200),
      );

      final courses = await repository.getCourses();

      expect(courses, hasLength(1));
      final course = courses.single;
      expect(course.id, 4);
      expect(course.slug, 'summer-bootcamp');
      expect(course.title.en, 'Summer Bootcamp');
      expect(course.title.mn, 'Зуны бүтээлч кэмп');
      expect(course.category, 'bootcamp');
      expect(course.level, 'junior');
      expect(course.format, 'in_person');
      expect(course.status, 'open');
      expect(course.ageMin, 10);
      expect(course.ageMax, 18);
      expect(course.durationWeeks, 3);
      expect(course.startDate, '2026-06-01');
      expect(course.endDate, '2026-06-21');
      expect(course.priceAmount, 1200000.0);
      expect(course.finalPriceAmount, 960000.0);
      expect(course.discountPercent, 20);
      expect(course.currency, 'MNT');
    });

    test('parses every nullable field that was null as null', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(confirmedResponseBody, 200),
      );

      final course = (await repository.getCourses()).single;

      expect(course.bannerImageUrl, isNull);
      expect(course.durationLabel, isNull);
      expect(course.icon, isNull);
      expect(course.sortOrder, isNull);
      expect(course.targetAudience, isNull);
      // Nested inside the localized-text object: en is null, mn is not.
      expect(course.tagline.en, isNull);
      expect(course.tagline.mn, '3 долоо хоногийн эрчимжүүлсэн');
    });

    test('parses a nullable field that was present, not null', () async {
      final body = jsonEncode({
        'courses': [
          _courseJson(overrides: {'banner_image_url': 'https://x/banner.png'}),
        ],
      });
      final repository = repositoryReturning((_) async => jsonResponse(body, 200));

      final course = (await repository.getCourses()).single;

      expect(course.bannerImageUrl, 'https://x/banner.png');
    });

    test('treats an omitted nullable key the same as an explicit null', () async {
      final json = _courseJson()..remove('sort_order');
      final body = jsonEncode({
        'courses': [json],
      });
      final repository = repositoryReturning((_) async => jsonResponse(body, 200));

      final course = (await repository.getCourses()).single;

      expect(course.sortOrder, isNull);
    });

    test('accepts an integer-valued price sent without a decimal point', () async {
      // JSON does not distinguish 1200000 from 1200000.0 — both are valid
      // encodings of the same number, and the client must accept either.
      final body = jsonEncode({
        'courses': [
          _courseJson(overrides: {'price_amount': 1200000}),
        ],
      });
      final repository = repositoryReturning((_) async => jsonResponse(body, 200));

      final course = (await repository.getCourses()).single;

      expect(course.priceAmount, 1200000.0);
    });

    test('an empty catalog is an empty list, not an error', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(jsonEncode({'courses': []}), 200),
      );

      expect(await repository.getCourses(), isEmpty);
    });

    test('parses every course in a multi-course catalog, in order', () async {
      final body = jsonEncode({
        'courses': [
          _courseJson(overrides: {'id': 1, 'slug': 'a'}),
          _courseJson(overrides: {'id': 2, 'slug': 'b'}),
          _courseJson(overrides: {'id': 3, 'slug': 'c'}),
        ],
      });
      final repository = repositoryReturning((_) async => jsonResponse(body, 200));

      final courses = await repository.getCourses();

      expect(courses.map((c) => c.id), [1, 2, 3]);
      expect(courses.map((c) => c.slug), ['a', 'b', 'c']);
    });
  });

  group('malformed responses', () {
    Future<ApiFailure> failureFrom(HttpCourseRepository repository) async {
      try {
        await repository.getCourses();
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

    test('a response with no "courses" key is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => jsonResponse(jsonEncode({'data': []}), 200)),
      );
      expect(failure.kind, ApiFailureKind.server);
      expect(failure.detail, contains('courses'));
    });

    test('"courses" being an object instead of a list is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => jsonResponse(jsonEncode({'courses': {}}), 200)),
      );
      expect(failure.kind, ApiFailureKind.server);
    });

    test('a course entry that is not an object is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning(
          (_) async => jsonResponse(
            jsonEncode({
              'courses': ['not-an-object'],
            }),
            200,
          ),
        ),
      );
      expect(failure.kind, ApiFailureKind.server);
      expect(failure.detail, contains('course entry'));
    });

    test('a course entry missing a required field names that field', () async {
      final json = _courseJson()..remove('id');
      final body = jsonEncode({
        'courses': [json],
      });

      final failure = await failureFrom(
        repositoryReturning((_) async => jsonResponse(body, 200)),
      );

      expect(failure.kind, ApiFailureKind.server);
      expect(failure.detail, contains('course.id'));
    });

    test('a required field with the wrong type names that field', () async {
      final body = jsonEncode({
        'courses': [
          _courseJson(overrides: {'price_amount': 'free'}),
        ],
      });

      final failure = await failureFrom(
        repositoryReturning((_) async => jsonResponse(body, 200)),
      );

      expect(failure.kind, ApiFailureKind.server);
      expect(failure.detail, contains('course.price_amount'));
    });

    test('a nullable field with the wrong (non-null) type names that field', () async {
      final body = jsonEncode({
        'courses': [
          _courseJson(overrides: {'sort_order': 'first'}),
        ],
      });

      final failure = await failureFrom(
        repositoryReturning((_) async => jsonResponse(body, 200)),
      );

      expect(failure.kind, ApiFailureKind.server);
      expect(failure.detail, contains('course.sort_order'));
    });

    test('a title/tagline that is not a {"en","mn"} object names the field', () async {
      final body = jsonEncode({
        'courses': [
          _courseJson(overrides: {'title': 'Summer Bootcamp'}),
        ],
      });

      final failure = await failureFrom(
        repositoryReturning((_) async => jsonResponse(body, 200)),
      );

      expect(failure.kind, ApiFailureKind.server);
      expect(failure.detail, contains('course.title'));
    });
  });

  group('HTTP failures', () {
    Future<ApiFailure> failureFrom(HttpCourseRepository repository) async {
      try {
        await repository.getCourses();
      } on ApiFailure catch (failure) {
        return failure;
      }
      fail('expected an ApiFailure');
    }

    test('5xx is a server fault', () async {
      for (final status in [500, 503]) {
        final failure = await failureFrom(
          repositoryReturning((_) async => http.Response('boom', status)),
        );
        expect(failure.kind, ApiFailureKind.server, reason: 'HTTP $status');
      }
    });

    test(
      'other non-2xx are unexpected, including a 401 the endpoint should never send',
      () async {
        for (final status in [401, 403, 404]) {
          final failure = await failureFrom(
            repositoryReturning((_) async => http.Response('{"error":"nope"}', status)),
          );
          expect(failure.kind, ApiFailureKind.unexpected, reason: 'HTTP $status');
        }
      },
    );

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
      final repository = HttpCourseRepository(
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
      expect(HttpCourseRepository.defaultBaseUrl, 'https://api.ai-academy.asia');
    });

    test('a base URL can be overridden without touching the path', () async {
      late Uri url;
      final repository = HttpCourseRepository(
        baseUrl: Uri.parse('https://staging.example.test'),
        client: MockClient((request) async {
          url = request.url;
          return jsonResponse(jsonEncode({'courses': []}), 200);
        }),
      );

      await repository.getCourses();

      expect(url.toString(), 'https://staging.example.test/courses');
    });
  });
}

/// A course JSON object matching the confirmed example, with [overrides]
/// applied — or a key removed by setting it to nothing and calling `.remove`
/// on the result, since a returned `Map` from this helper is mutable.
Map<String, dynamic> _courseJson({Map<String, dynamic> overrides = const {}}) => {
  'age_max': 18,
  'age_min': 10,
  'banner_image_url': null,
  'category': 'bootcamp',
  'currency': 'MNT',
  'discount_percent': 20,
  'duration_label': null,
  'duration_weeks': 3,
  'end_date': '2026-06-21',
  'final_price_amount': 960000.0,
  'format': 'in_person',
  'icon': null,
  'id': 4,
  'level': 'junior',
  'price_amount': 1200000.0,
  'slug': 'summer-bootcamp',
  'sort_order': null,
  'start_date': '2026-06-01',
  'status': 'open',
  'tagline': {'en': null, 'mn': '3 долоо хоногийн эрчимжүүлсэн'},
  'target_audience': null,
  'title': {'en': 'Summer Bootcamp', 'mn': 'Зуны бүтээлч кэмп'},
  ...overrides,
};
