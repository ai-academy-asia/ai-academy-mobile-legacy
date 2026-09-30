import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/course_learning/data/http_course_learning_repository.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Exercises the wire format against `course_learning_api_contract_v1.md`
/// §2.1:
///
///     GET https://api.ai-academy.asia/me/courses/{course_slug}/learning
///     Authorization: Bearer <access_token>
///
/// Every body below is the contract's own §2.1 example, trimmed or bent one
/// field at a time — no live backend is called, per this repository's existing
/// `MockClient` pattern.
void main() {
  /// Never the app-wide store: a test must not read a token another test left.
  AuthSessionStore signedIn([String token = 'tok-123']) =>
      AuthSessionStore()..save(AuthSession(accessToken: token));

  HttpCourseLearningRepository repositoryReturning(
    Future<http.Response> Function(http.Request request) handler, {
    AuthSessionStore? sessionStore,
  }) => HttpCourseLearningRepository(
    client: MockClient(handler),
    sessionStore: sessionStore ?? signedIn(),
  );

  Future<CourseLearningFailure> failureFrom(
    HttpCourseLearningRepository repository, {
    String slug = 'summer-bootcamp-2027',
  }) async {
    try {
      await repository.getCourseLearning(slug);
    } on CourseLearningFailure catch (failure) {
      return failure;
    }
    fail('expected a CourseLearningFailure');
  }

  /// `http.Response`'s string constructor encodes as latin1 unless the
  /// content type names a charset, which throws on the Mongolian copy every
  /// body below carries. Encoding the bytes explicitly is what the real API
  /// does anyway.
  http.Response jsonResponse(Object? body, [int status = 200]) =>
      http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        },
      );

  /// The contract's §2.1 response, with the verified course's own slug.
  Map<String, Object?> contractBody({
    Object? schedule = const {'date': '2026-08-06', 'start_time': '09:00'},
    Object? continueTarget = const {'module_id': 31, 'lesson_id': 204},
    int percent = 30,
    List<Map<String, Object?>>? modules,
  }) => {
    'course': {
      'id': 6,
      'slug': 'summer-bootcamp-2027',
      'title': {'mn': 'AI хэрхэн ажилладаг вэ', 'en': 'How AI works'},
      'description': {'mn': 'Тайлбар', 'en': 'Description'},
      'banner_image_url': 'https://example.test/banner.png',
    },
    'enrollment_id': 118,
    'cohort_id': 1,
    'progress': {
      'percent': percent,
      'completed_lessons': 6,
      'total_lessons': 20,
    },
    'continue': continueTarget,
    'certificate': {'status': 'not_eligible'},
    'modules':
        modules ??
        [
          {
            'id': 30,
            'order': 1,
            'title': {'mn': 'AI хэрхэн ажилладаг вэ', 'en': 'How AI works'},
            'schedule': schedule,
            'lesson_count': 4,
            'completed_lessons': 4,
            'completed': true,
            'locked': false,
          },
          {
            'id': 31,
            'order': 2,
            'title': {'mn': 'Хоёрдугаар', 'en': 'Second'},
            'schedule': schedule,
            'lesson_count': 4,
            'completed_lessons': 0,
            'completed': false,
            'locked': true,
          },
        ],
  };

  HttpCourseLearningRepository repositoryAnswering(
    Map<String, Object?> body, {
    AuthSessionStore? sessionStore,
  }) => repositoryReturning(
    (_) async => jsonResponse(body),
    sessionStore: sessionStore,
  );

  Future<CourseLearningPath> pathFrom(Map<String, Object?> body) =>
      repositoryAnswering(body).getCourseLearning('summer-bootcamp-2027');

  group('the request', () {
    test('GETs the contract URL for the slug it was asked for', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return jsonResponse(contractBody());
      });

      await repository.getCourseLearning('summer-bootcamp-2027');

      expect(sent.method, 'GET');
      expect(
        sent.url.toString(),
        'https://api.ai-academy.asia/me/courses/summer-bootcamp-2027/learning',
      );
      expect(sent.headers[HttpHeaders.acceptHeader], 'application/json');
      expect(sent.body, isEmpty);
    });

    test('carries the signed-in student\'s token as a Bearer header', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return jsonResponse(contractBody());
      }, sessionStore: signedIn('student-tok'));

      await repository.getCourseLearning('summer-bootcamp-2027');

      expect(sent.headers['Authorization'], 'Bearer student-tok');
    });

    test(
      'percent-encodes a slug so it cannot open a path of its own',
      () async {
        late http.Request sent;
        final repository = repositoryReturning((request) async {
          sent = request;
          return jsonResponse(contractBody());
        });

        await repository.getCourseLearning('a/b?c');

        expect(
          sent.url.toString(),
          'https://api.ai-academy.asia/me/courses/a%2Fb%3Fc/learning',
        );
      },
    );
  });

  group('without a usable session', () {
    test('signed out: sends nothing and asks for sign-in', () async {
      var requests = 0;
      final repository = repositoryReturning((_) async {
        requests++;
        return jsonResponse(contractBody());
      }, sessionStore: AuthSessionStore());

      final failure = await failureFrom(repository);

      expect(failure.kind, CourseLearningFailureKind.sessionExpired);
      expect(requests, 0);
    });

    test('a session past its reported lifetime: sends nothing', () async {
      var requests = 0;
      final store = AuthSessionStore()
        ..save(
          const AuthSession(accessToken: 'old', expiresIn: Duration(hours: 1)),
          now: DateTime(2000),
        );
      final repository = repositoryReturning((_) async {
        requests++;
        return jsonResponse(contractBody());
      }, sessionStore: store);

      final failure = await failureFrom(repository);

      expect(failure.kind, CourseLearningFailureKind.sessionExpired);
      expect(requests, 0);
    });
  });

  group('status mapping', () {
    test('401 is a dead session, and the token is forgotten', () async {
      final store = signedIn();
      final repository = repositoryReturning(
        (_) async => http.Response('', 401),
        sessionStore: store,
      );

      final failure = await failureFrom(repository);

      expect(failure.kind, CourseLearningFailureKind.sessionExpired);
      expect(store.isSignedIn, isFalse);
    });

    test('403 is the contract\'s not_enrolled, and keeps the token', () async {
      final store = signedIn();
      final repository = repositoryReturning(
        (_) async => http.Response('', 403),
        sessionStore: store,
      );

      final failure = await failureFrom(repository);

      expect(failure.kind, CourseLearningFailureKind.notEnrolled);
      // Not a session problem: signing out over a 403 would drop a token that
      // still works everywhere else in the app.
      expect(store.isSignedIn, isTrue);
    });

    test('404 is the contract\'s course_not_found', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('', 404)),
      );

      expect(failure.kind, CourseLearningFailureKind.notFound);
    });

    test('500 is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('', 500)),
      );

      expect(failure.kind, CourseLearningFailureKind.server);
    });

    test('an unlisted 4xx has no more specific reading', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('', 409)),
      );

      expect(failure.kind, CourseLearningFailureKind.unexpected);
    });

    test('a request that never completes is a network failure', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => throw const SocketException('down')),
      );

      expect(failure.kind, CourseLearningFailureKind.network);
    });
  });

  group('mapping the contract\'s response', () {
    test('reads the course identity, Mongolian first', () async {
      final path = await pathFrom(contractBody());

      expect(path.courseSlug, 'summer-bootcamp-2027');
      expect(path.courseTitle, 'AI хэрхэн ажилладаг вэ');
      expect(path.description, 'Тайлбар');
    });

    test('falls back to English when only "en" is sent', () async {
      final body = contractBody();
      (body['course'] as Map<String, Object?>)['title'] = {
        'en': 'How AI works',
      };

      final path = await pathFrom(body);

      expect(path.courseTitle, 'How AI works');
    });

    test('displays progress.percent rather than deriving one', () async {
      // Two modules, one completed — a module-based figure would be 50.
      final path = await pathFrom(contractBody(percent: 30));

      expect(path.percentComplete, 30);
    });

    test('clamps a percent outside 0-100 instead of failing', () async {
      expect((await pathFrom(contractBody(percent: 140))).percentComplete, 100);
      expect((await pathFrom(contractBody(percent: -5))).percentComplete, 0);
    });

    test('uses the bundled hero illustration, not banner_image_url', () async {
      final path = await pathFrom(contractBody());

      expect(
        path.illustrationAsset,
        HttpCourseLearningRepository.heroIllustrationAsset,
      );
    });

    test('reads continue.module_id as the continue target', () async {
      final path = await pathFrom(contractBody());

      expect(path.continueModuleId, 31);
    });

    test('a null "continue" leaves no target', () async {
      final path = await pathFrom(contractBody(continueTarget: null));

      expect(path.continueModuleId, isNull);
    });

    test(
      'takes completed and locked from the server, not from state',
      () async {
        final path = await pathFrom(contractBody());

        expect(path.modules.map((m) => m.id), [30, 31]);
        expect(path.modules.map((m) => m.order), [1, 2]);
        expect(path.modules.map((m) => m.title), [
          'AI хэрхэн ажилладаг вэ',
          'Хоёрдугаар',
        ]);
        expect(path.modules.map((m) => m.completed), [true, false]);
        expect(path.modules.map((m) => m.locked), [false, true]);
      },
    );

    test('maps order onto the bundled icon/accent palette', () async {
      final path = await pathFrom(contractBody());

      expect(
        path.modules.first.iconAsset,
        'assets/images/course_learning/module_ai.svg',
      );
      expect(path.modules.first.accentColor, const Color(0xFF408CFF));
      expect(
        path.modules.last.iconAsset,
        'assets/images/course_learning/module_training.svg',
      );
      expect(path.modules.last.accentColor, const Color(0xFFFFC640));
    });

    test('wraps the palette past its fifth entry', () async {
      final path = await pathFrom(
        contractBody(
          modules: [
            {
              'id': 36,
              'order': 6,
              'title': {'en': 'Sixth'},
              'schedule': null,
              'lesson_count': 0,
              'completed_lessons': 0,
              'completed': false,
              'locked': false,
            },
          ],
        ),
      );

      expect(
        path.modules.single.iconAsset,
        'assets/images/course_learning/module_ai.svg',
      );
    });

    test('reads each module\'s lesson_count and completed_lessons', () async {
      final path = await pathFrom(contractBody());

      expect(path.modules.map((m) => m.lessonCount), [4, 4]);
      expect(path.modules.map((m) => m.completedLessons), [4, 0]);
    });

    test('keeps the server\'s module order, and each module\'s own data', () {
      Map<String, Object?> module(int id, int order, String mn) => {
        'id': id,
        'order': order,
        'title': {'mn': mn, 'en': 'Module $order'},
        'schedule': null,
        'lesson_count': order,
        'completed_lessons': 0,
        'completed': false,
        'locked': false,
      };

      return pathFrom(
        contractBody(
          modules: [
            module(40, 1, 'Нэг'),
            module(41, 2, 'Хоёр'),
            module(42, 3, 'Гурав'),
          ],
        ),
      ).then((path) {
        expect(path.modules.map((m) => m.id), [40, 41, 42]);
        expect(path.modules.map((m) => m.order), [1, 2, 3]);
        expect(path.modules.map((m) => m.title), ['Нэг', 'Хоёр', 'Гурав']);
        expect(path.modules.map((m) => m.lessonCount), [1, 2, 3]);
      });
    });

    test('a module title falls back to English when only "en" is sent', () {
      final body = contractBody();
      ((body['modules'] as List).first as Map<String, Object?>)['title'] = {
        'en': 'How AI works',
      };

      return pathFrom(
        body,
      ).then((path) => expect(path.modules.first.title, 'How AI works'));
    });

    test('reads continue.lesson_id and certificate.status', () async {
      final path = await pathFrom(contractBody());

      expect(path.continueLessonId, 204);
      expect(path.certificateStatus, 'not_eligible');
    });

    test('accepts an empty module list', () async {
      final path = await pathFrom(contractBody(modules: []));

      expect(path.modules, isEmpty);
    });
  });

  group('the schedule label', () {
    Future<String> labelFor(Object? schedule) async => (await pathFrom(
      contractBody(schedule: schedule),
    )).modules.first.scheduleLabel;

    test('composes MM/dd, the Mongolian weekday and the start time', () async {
      // 2026-08-06 is a Thursday — Пүрэв.
      expect(
        await labelFor(const {'date': '2026-08-06', 'start_time': '09:00'}),
        '08/06 • Пү • 09:00',
      );
    });

    test('abbreviates every weekday', () async {
      // 2026-08-03 is a Monday, so this walks Monday through Sunday.
      const expected = ['Да', 'Мя', 'Лх', 'Пү', 'Ба', 'Бя', 'Ня'];
      for (var day = 3; day <= 9; day++) {
        final date = '2026-08-${day.toString().padLeft(2, '0')}';
        expect(
          await labelFor({'date': date, 'start_time': '09:00'}),
          '08/${day.toString().padLeft(2, '0')} • ${expected[day - 3]} • 09:00',
          reason: date,
        );
      }
    });

    test('trims seconds off a start_time that carries them', () async {
      expect(
        await labelFor(const {'date': '2026-08-06', 'start_time': '09:00:00'}),
        '08/06 • Пү • 09:00',
      );
    });

    test('a self-paced module (schedule: null) draws no date line', () async {
      expect(await labelFor(null), isEmpty);
    });

    test('an unparseable date is a server fault, named', () async {
      final failure = await failureFrom(
        repositoryAnswering(
          contractBody(
            schedule: const {'date': 'the sixth', 'start_time': '09:00'},
          ),
        ),
      );

      expect(failure.kind, CourseLearningFailureKind.server);
      expect(failure.detail, contains('module.schedule.date'));
    });
  });

  group('a 200 that does not match the contract', () {
    Future<CourseLearningFailure> failureForBody(Object? body) =>
        failureFrom(repositoryReturning((_) async => jsonResponse(body)));

    test('malformed JSON', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('{not json', 200)),
      );

      expect(failure.kind, CourseLearningFailureKind.server);
      expect(failure.detail, contains('malformed JSON'));
    });

    test('a body that is not an object', () async {
      final failure = await failureForBody([1, 2, 3]);

      expect(failure.kind, CourseLearningFailureKind.server);
      expect(failure.detail, contains('not a JSON object'));
    });

    test('names the missing field: course', () async {
      final body = contractBody()..remove('course');

      final failure = await failureForBody(body);

      expect(failure.detail, contains('course'));
    });

    test('names the missing field: progress.percent', () async {
      final body = contractBody();
      (body['progress'] as Map<String, Object?>).remove('percent');

      final failure = await failureForBody(body);

      expect(failure.detail, contains('progress.percent'));
    });

    test('names the missing field: modules', () async {
      final body = contractBody()..['modules'] = 'not a list';

      final failure = await failureForBody(body);

      expect(failure.detail, contains('modules'));
    });

    test(
      'a title with neither language is a fault, not an empty card',
      () async {
        final body = contractBody();
        (body['course'] as Map<String, Object?>)['title'] = <String, Object?>{};

        final failure = await failureForBody(body);

        expect(failure.detail, contains('course.title'));
      },
    );

    test('a module missing "locked" is a fault, not a guess', () async {
      final body = contractBody();
      final firstModule =
          (body['modules'] as List).first as Map<String, Object?>;
      firstModule.remove('locked');

      final failure = await failureForBody(body);

      expect(failure.detail, contains('locked'));
    });

    test('a module missing lesson_count is a fault, named', () async {
      final body = contractBody();
      ((body['modules'] as List).first as Map<String, Object?>).remove(
        'lesson_count',
      );

      final failure = await failureForBody(body);

      expect(failure.kind, CourseLearningFailureKind.server);
      expect(failure.detail, contains('module.lesson_count'));
    });

    test('a non-numeric completed_lessons is a fault, named', () async {
      final body = contractBody();
      ((body['modules'] as List).first
              as Map<String, Object?>)['completed_lessons'] =
          'four';

      final failure = await failureForBody(body);

      expect(failure.detail, contains('module.completed_lessons'));
    });

    test(
      'an absent description is tolerated — the card renders without it',
      () async {
        final body = contractBody();
        (body['course'] as Map<String, Object?>).remove('description');

        final path = await pathFrom(body);

        expect(path.description, isEmpty);
      },
    );
  });

  group('the endpoints this task did not integrate', () {
    test('getLessons and getExercise still come from the sample', () async {
      final repository = repositoryReturning(
        (_) async => fail('no HTTP call is made for these yet'),
      );

      expect(await repository.getLessons(2), isNotEmpty);
      expect((await repository.getExercise(2)).title, isNotEmpty);
    });
  });
}
