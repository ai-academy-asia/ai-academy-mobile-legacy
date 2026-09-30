import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/course_learning/data/http_course_learning_repository.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/domain/course_exercise.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_path.dart';
import 'package:aia_mobile/features/course_learning/domain/lesson.dart';
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
        repositoryReturning((_) async => http.Response('', 422)),
      );

      expect(failure.kind, CourseLearningFailureKind.unexpected);
    });

    test('409 is the contract\'s lesson_locked', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('', 409)),
      );

      expect(failure.kind, CourseLearningFailureKind.locked);
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

  group('lessons in a module (§2.2)', () {
    Map<String, Object?> lesson({
      int id = 204,
      int order = 1,
      Object? title = const {'mn': 'Давталт', 'en': 'Nesting loops'},
      Object? type = 'recording',
      Object? durationSeconds = 1455,
      bool completed = false,
      bool locked = false,
    }) => {
      'id': id,
      'order': order,
      'title': title,
      'type': type,
      'duration_seconds': durationSeconds,
      'completed': completed,
      'locked': locked,
    };

    /// The contract's §2.2 body, module 31.
    Map<String, Object?> lessonsBody({List<Map<String, Object?>>? lessons}) => {
      'module': {
        'id': 31,
        'order': 2,
        'title': {'mn': 'Хоёрдугаар', 'en': 'Second'},
      },
      'lessons':
          lessons ??
          [
            lesson(),
            lesson(
              id: 205,
              order: 2,
              type: 'video',
              durationSeconds: 3725,
              completed: true,
            ),
            lesson(
              id: 206,
              order: 3,
              type: 'reading',
              durationSeconds: 0,
              locked: true,
            ),
          ],
    };

    Future<List<Lesson>> lessonsFrom(Object? body) =>
        repositoryReturning((_) async => jsonResponse(body)).getLessons(31);

    Future<CourseLearningFailure> lessonsFailureFrom(
      HttpCourseLearningRepository repository,
    ) async {
      try {
        await repository.getLessons(31);
      } on CourseLearningFailure catch (failure) {
        return failure;
      }
      fail('expected a CourseLearningFailure');
    }

    Future<CourseLearningFailure> failureForLessonsBody(Object? body) =>
        lessonsFailureFrom(
          repositoryReturning((_) async => jsonResponse(body)),
        );

    group('the request', () {
      test('GETs /me/modules/{module_id}/lessons with the token', () async {
        late http.Request sent;
        final repository = repositoryReturning((request) async {
          sent = request;
          return jsonResponse(lessonsBody());
        });

        await repository.getLessons(31);

        expect(sent.method, 'GET');
        expect(
          sent.url.toString(),
          'https://api.ai-academy.asia/me/modules/31/lessons',
        );
        expect(sent.headers[HttpHeaders.authorizationHeader], 'Bearer tok-123');
      });

      test('signed out: sends nothing and asks for sign-in', () async {
        var requests = 0;
        final repository = repositoryReturning((_) async {
          requests++;
          return jsonResponse(lessonsBody());
        }, sessionStore: AuthSessionStore());

        final failure = await lessonsFailureFrom(repository);

        expect(failure.kind, CourseLearningFailureKind.sessionExpired);
        expect(requests, 0);
      });

      test('an expired session: sends nothing', () async {
        var requests = 0;
        final store = AuthSessionStore()
          ..save(
            const AuthSession(
              accessToken: 'old',
              expiresIn: Duration(hours: 1),
            ),
            now: DateTime(2000),
          );
        final repository = repositoryReturning((_) async {
          requests++;
          return jsonResponse(lessonsBody());
        }, sessionStore: store);

        final failure = await lessonsFailureFrom(repository);

        expect(failure.kind, CourseLearningFailureKind.sessionExpired);
        expect(requests, 0);
      });
    });

    group('mapping the response', () {
      test('reads every lesson field', () async {
        final lessons = await lessonsFrom(lessonsBody());

        final first = lessons.first;
        expect(first.id, 204);
        expect(first.order, 1);
        expect(first.title, 'Давталт');
        expect(first.type, LessonType.recording);
        expect(first.durationLabel, '24:15');
        expect(first.completed, isFalse);
        expect(first.locked, isFalse);
      });

      test('tags every lesson with module.id', () async {
        final lessons = await lessonsFrom(lessonsBody());

        expect(lessons.map((l) => l.moduleId), everyElement(31));
      });

      test('prefers Mongolian, falling back to English', () async {
        final lessons = await lessonsFrom(
          lessonsBody(
            lessons: [
              lesson(title: const {'mn': 'Монгол', 'en': 'English'}),
              lesson(id: 205, title: const {'en': 'Only English'}),
            ],
          ),
        );

        expect(lessons.map((l) => l.title), ['Монгол', 'Only English']);
      });

      test('keeps the server\'s array order, never sorting by order', () async {
        final lessons = await lessonsFrom(
          lessonsBody(
            lessons: [
              lesson(id: 1, order: 3),
              lesson(id: 2, order: 1),
              lesson(id: 3, order: 2),
            ],
          ),
        );

        expect(lessons.map((l) => l.id), [1, 2, 3]);
        expect(lessons.map((l) => l.order), [3, 1, 2]);
      });

      test('maps every documented type', () async {
        final lessons = await lessonsFrom(lessonsBody());

        expect(lessons.map((l) => l.type), [
          LessonType.recording,
          LessonType.video,
          LessonType.reading,
        ]);
      });

      test('an unrecognised type is unknown, not a failure', () async {
        final lessons = await lessonsFrom(
          lessonsBody(
            lessons: [
              lesson(type: 'podcast'),
              lesson(id: 205),
            ],
          ),
        );

        expect(lessons.map((l) => l.type), [
          LessonType.unknown,
          LessonType.recording,
        ]);
      });

      test(
        'formats duration_seconds as M:SS, or H:MM:SS from an hour',
        () async {
          final lessons = await lessonsFrom(
            lessonsBody(
              lessons: [
                lesson(id: 1, durationSeconds: 0),
                lesson(id: 2, durationSeconds: 1455),
                lesson(id: 3, durationSeconds: 3725),
                lesson(id: 4, durationSeconds: 59),
                lesson(id: 5, durationSeconds: 3600),
              ],
            ),
          );

          expect(lessons.map((l) => l.durationLabel), [
            '0:00',
            '24:15',
            '1:02:05',
            '0:59',
            '1:00:00',
          ]);
        },
      );

      test('takes completed and locked from the server', () async {
        final lessons = await lessonsFrom(lessonsBody());

        expect(lessons.map((l) => l.completed), [false, true, false]);
        expect(lessons.map((l) => l.locked), [false, false, true]);
      });

      test('an empty lesson list is an empty result', () async {
        expect(await lessonsFrom(lessonsBody(lessons: [])), isEmpty);
      });
    });

    group('a 200 that does not match the contract', () {
      test('malformed JSON', () async {
        final failure = await lessonsFailureFrom(
          repositoryReturning(
            (_) async => http.Response.bytes(utf8.encode('{not json'), 200),
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.server);
      });

      test('a body that is not an object', () async {
        final failure = await failureForLessonsBody([1, 2]);

        expect(failure.kind, CourseLearningFailureKind.server);
      });

      test('names the missing envelope field: module', () async {
        final failure = await failureForLessonsBody(
          lessonsBody()..remove('module'),
        );

        expect(failure.kind, CourseLearningFailureKind.server);
        expect(failure.detail, contains('module'));
      });

      test('names the missing envelope field: lessons', () async {
        final failure = await failureForLessonsBody(
          lessonsBody()..remove('lessons'),
        );

        expect(failure.detail, contains('lessons'));
      });

      test('names the missing field: module.id', () async {
        final body = lessonsBody();
        (body['module'] as Map<String, Object?>).remove('id');

        final failure = await failureForLessonsBody(body);

        expect(failure.detail, contains('module.id'));
      });

      test('names each missing lesson field', () async {
        for (final key in [
          'id',
          'order',
          'title',
          'type',
          'duration_seconds',
          'completed',
          'locked',
        ]) {
          final failure = await failureForLessonsBody(
            lessonsBody(lessons: [lesson()..remove(key)]),
          );

          expect(failure.kind, CourseLearningFailureKind.server, reason: key);
          expect(failure.detail, contains('lesson.$key'), reason: key);
        }
      });

      test('a non-string type is a fault, unlike an unknown string', () async {
        final failure = await failureForLessonsBody(
          lessonsBody(lessons: [lesson(type: 3)]),
        );

        expect(failure.detail, contains('lesson.type'));
      });

      test('a negative duration is a fault', () async {
        final failure = await failureForLessonsBody(
          lessonsBody(lessons: [lesson(durationSeconds: -1)]),
        );

        expect(failure.detail, contains('lesson.duration_seconds'));
      });

      test('a lesson entry that is not an object', () async {
        final failure = await failureForLessonsBody({
          ...lessonsBody(),
          'lessons': ['oops'],
        });

        expect(failure.kind, CourseLearningFailureKind.server);
      });
    });

    group('status mapping', () {
      test('401 is a dead session, and the token is forgotten', () async {
        final store = signedIn();
        final failure = await lessonsFailureFrom(
          repositoryReturning(
            (_) async => jsonResponse({'error': 'token_expired'}, 401),
            sessionStore: store,
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.sessionExpired);
        expect(store.isSignedIn, isFalse);
      });

      test('403 is not_enrolled, and keeps the token', () async {
        final store = signedIn();
        final failure = await lessonsFailureFrom(
          repositoryReturning(
            (_) async => jsonResponse({'error': 'not_enrolled'}, 403),
            sessionStore: store,
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.notEnrolled);
        expect(store.isSignedIn, isTrue);
      });

      test('404 module_not_found is notFound', () async {
        final failure = await lessonsFailureFrom(
          repositoryReturning(
            (_) async => jsonResponse({'error': 'module_not_found'}, 404),
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.notFound);
      });

      test('5xx is a server fault', () async {
        for (final status in [500, 503]) {
          final failure = await lessonsFailureFrom(
            repositoryReturning((_) async => jsonResponse({}, status)),
          );

          expect(
            failure.kind,
            CourseLearningFailureKind.server,
            reason: 'HTTP $status',
          );
        }
      });

      test('a request that never completes is a network failure', () async {
        final failure = await lessonsFailureFrom(
          repositoryReturning(
            (_) async => throw const SocketException('offline'),
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.network);
      });
    });
  });

  group('lesson detail (§2.3)', () {
    /// The contract's §2.3 body, lesson 204 in module 31.
    Map<String, Object?> lessonBody({
      Object? video = const {'embed_url': 'https://www.youtube.com/embed/x'},
      Object? type = 'recording',
      Object? durationSeconds = 1455,
      Object? summary = const {'mn': 'Хураангуй', 'en': 'Summary'},
      List<Object?>? sections,
      List<Object?>? materials,
      Object? note,
      bool completed = false,
    }) => {
      'id': 204,
      'module': {
        'id': 31,
        'order': 2,
        'title': {'mn': 'Хоёрдугаар', 'en': 'Second'},
      },
      'order': 1,
      'title': {'mn': 'Давталт', 'en': 'Nesting loops'},
      'type': type,
      'duration_seconds': durationSeconds,
      'video': video,
      'summary': summary,
      'sections':
          sections ??
          [
            {
              'title': {'mn': 'Эхний хэсэг', 'en': 'First'},
              'body': {'mn': 'Бие', 'en': 'Body'},
              'bullets': [
                {'mn': 'Нэг', 'en': 'One'},
                {'en': 'Two'},
              ],
            },
            {
              'title': {'en': 'Second'},
              'body': {'mn': 'Хоёр', 'en': null},
              'bullets': <Object?>[],
            },
          ],
      'completed': completed,
      'materials':
          materials ??
          [
            {
              'id': 88,
              'title': 'Course material 1',
              'type': 'file',
              'file_name': 'week2-slides.pdf',
              'content_type': 'application/pdf',
              'size_bytes': 10485760,
            },
            {
              'id': 89,
              'title': 'Reading list',
              'type': 'link',
              'url': 'https://example.test/reading',
            },
            {
              'id': 90,
              'title': 'Notes',
              'type': 'file',
              'file_name': 'notes.pdf',
              'content_type': 'application/pdf',
              'size_bytes': 1572864,
            },
          ],
      'note': note,
      'assignment': null,
      'quiz': null,
    };

    Map<String, Object?> file(int id, int sizeBytes) => {
      'id': id,
      'title': 'File $id',
      'type': 'file',
      'file_name': 'f$id.pdf',
      'content_type': 'application/pdf',
      'size_bytes': sizeBytes,
    };

    /// 2026-08-06, 15:00 local — the "today" note timestamps are read
    /// against.
    final now = DateTime(2026, 8, 6, 15);

    HttpCourseLearningRepository lessonRepository(
      Future<http.Response> Function(http.Request request) handler, {
      AuthSessionStore? sessionStore,
    }) => HttpCourseLearningRepository(
      client: MockClient(handler),
      sessionStore: sessionStore ?? signedIn(),
      clock: () => now,
    );

    Future<CourseExercise> exerciseFrom(Object? body) =>
        lessonRepository((_) async => jsonResponse(body)).getExercise(204);

    Future<CourseLearningFailure> exerciseFailureFrom(
      HttpCourseLearningRepository repository,
    ) async {
      try {
        await repository.getExercise(204);
      } on CourseLearningFailure catch (failure) {
        return failure;
      }
      fail('expected a CourseLearningFailure');
    }

    Future<CourseLearningFailure> failureForExerciseBody(Object? body) =>
        exerciseFailureFrom(lessonRepository((_) async => jsonResponse(body)));

    group('the request', () {
      test('GETs /me/lessons/{lesson_id} with the token', () async {
        late http.Request sent;
        final repository = lessonRepository((request) async {
          sent = request;
          return jsonResponse(lessonBody());
        });

        await repository.getExercise(204);

        expect(sent.method, 'GET');
        expect(
          sent.url.toString(),
          'https://api.ai-academy.asia/me/lessons/204',
        );
        expect(sent.headers[HttpHeaders.authorizationHeader], 'Bearer tok-123');
      });

      test('signed out: sends nothing and asks for sign-in', () async {
        var requests = 0;
        final repository = lessonRepository((_) async {
          requests++;
          return jsonResponse(lessonBody());
        }, sessionStore: AuthSessionStore());

        final failure = await exerciseFailureFrom(repository);

        expect(failure.kind, CourseLearningFailureKind.sessionExpired);
        expect(requests, 0);
      });

      test('an expired session: sends nothing', () async {
        var requests = 0;
        final store = AuthSessionStore()
          ..save(
            const AuthSession(
              accessToken: 'old',
              expiresIn: Duration(hours: 1),
            ),
            now: DateTime(2000),
          );
        final repository = lessonRepository((_) async {
          requests++;
          return jsonResponse(lessonBody());
        }, sessionStore: store);

        final failure = await exerciseFailureFrom(repository);

        expect(failure.kind, CourseLearningFailureKind.sessionExpired);
        expect(requests, 0);
      });

      test('getLessons and getExercise both call HTTP', () async {
        final requested = <String>[];
        final repository = lessonRepository((request) async {
          requested.add(request.url.path);
          return jsonResponse(
            request.url.path.endsWith('/lessons')
                ? {
                    'module': {'id': 2},
                    'lessons': <Object?>[],
                  }
                : lessonBody(),
          );
        });

        await repository.getLessons(2);
        await repository.getExercise(204);

        expect(requested, ['/me/modules/2/lessons', '/me/lessons/204']);
      });
    });

    group('mapping the response', () {
      test('reads the lesson identity and its module', () async {
        final exercise = await exerciseFrom(lessonBody());

        expect(exercise.lessonId, 204);
        expect(exercise.moduleId, 31);
        // Built on the client from `module.order`, as §2.3 says.
        expect(exercise.moduleCaption, 'Modules 2');
      });

      test('localises title and summary Mongolian first', () async {
        final exercise = await exerciseFrom(lessonBody());

        expect(exercise.title, 'Давталт');
        expect(exercise.summary, 'Хураангуй');
      });

      test('falls back to English, and to empty for an empty summary', () {
        final body = lessonBody(summary: const {'mn': '', 'en': 'Only en'});
        body['title'] = {'en': 'English title'};

        return exerciseFrom(body).then((exercise) {
          expect(exercise.title, 'English title');
          expect(exercise.summary, 'Only en');
        });
      });

      test('a summary with no text in either language is empty', () async {
        final exercise = await exerciseFrom(
          lessonBody(summary: const {'mn': null, 'en': null}),
        );

        expect(exercise.summary, isEmpty);
      });

      test('reads sections and bullets in server order, localised', () async {
        final exercise = await exerciseFrom(lessonBody());

        expect(exercise.extraSections.map((s) => s.title), [
          'Эхний хэсэг',
          'Second',
        ]);
        expect(exercise.extraSections.map((s) => s.body), ['Бие', 'Хоёр']);
        expect(exercise.extraSections.first.bullets, ['Нэг', 'Two']);
        expect(exercise.extraSections.last.bullets, isEmpty);
      });

      test(
        'formats duration_seconds as M:SS, or H:MM:SS from an hour',
        () async {
          final labels = <String>[];
          for (final seconds in [0, 1455, 3725]) {
            labels.add(
              (await exerciseFrom(
                lessonBody(durationSeconds: seconds),
              )).durationLabel,
            );
          }

          expect(labels, ['0:00', '24:15', '1:02:05']);
        },
      );

      test('maps type, with a badge only for a recording', () async {
        final expected = {
          'recording': (LessonType.recording, 'Live Classroom Recording'),
          'video': (LessonType.video, ''),
          'reading': (LessonType.reading, ''),
          'podcast': (LessonType.unknown, ''),
        };
        for (final entry in expected.entries) {
          final exercise = await exerciseFrom(lessonBody(type: entry.key));

          expect(exercise.type, entry.value.$1, reason: entry.key);
          expect(
            exercise.recordingBadgeLabel,
            entry.value.$2,
            reason: entry.key,
          );
        }
      });

      test('a video object means a video; null means none', () async {
        expect((await exerciseFrom(lessonBody())).hasVideo, isTrue);
        expect((await exerciseFrom(lessonBody(video: null))).hasVideo, isFalse);
      });

      test('reads completed from the server', () async {
        expect((await exerciseFrom(lessonBody())).completed, isFalse);
        expect(
          (await exerciseFrom(lessonBody(completed: true))).completed,
          isTrue,
        );
      });

      test('keeps file materials in order, and leaves links out', () async {
        final exercise = await exerciseFrom(lessonBody());

        expect(exercise.materials.map((m) => m.id), [88, 90]);
        expect(exercise.materials.map((m) => m.name), [
          'Course material 1',
          'Notes',
        ]);
      });

      test('an unrecognised material type is left out, not a failure', () {
        return exerciseFrom(
          lessonBody(
            materials: [
              {'id': 1, 'title': 'Mystery', 'type': 'hologram'},
              file(2, 1024),
            ],
          ),
        ).then((exercise) => expect(exercise.materials.single.id, 2));
      });

      test('formats size_bytes as the materials row draws it', () async {
        final exercise = await exerciseFrom(
          lessonBody(
            materials: [
              file(1, 10485760),
              file(2, 1572864),
              file(3, 12582912),
              file(4, 512),
              file(5, 2048),
              file(6, 0),
              file(7, 1073741824),
            ],
          ),
        );

        expect(exercise.materials.map((m) => m.sizeLabel), [
          '10 MB',
          '1.5 MB',
          '12 MB',
          '512 B',
          '2 KB',
          '0 B',
          '1 GB',
        ]);
      });

      test('reads a note read-only, timestamped against today', () async {
        final exercise = await exerciseFrom(
          lessonBody(
            note: {
              'id': 51,
              'content': 'Remember the base case',
              'created_at': '2026-08-06T01:00:00+00:00',
              'updated_at': DateTime(
                2026,
                8,
                6,
                14,
                20,
              ).toUtc().toIso8601String(),
              'author': {'name': 'Болд Батаа', 'initials': 'ББ'},
            },
          ),
        );

        final note = exercise.note!;
        expect(note.message, 'Remember the base case');
        expect(note.authorName, 'Болд Батаа');
        expect(note.authorInitials, 'ББ');
        expect(note.authorLabel, 'Me');
        expect(note.timestampLabel, 'Today, 14:20');
      });

      test('an older note is dated MM/dd', () async {
        final exercise = await exerciseFrom(
          lessonBody(
            note: {
              'id': 51,
              'content': 'Older',
              'created_at': '2026-08-01T01:00:00+00:00',
              'updated_at': DateTime(
                2026,
                8,
                1,
                9,
                5,
              ).toUtc().toIso8601String(),
              'author': {'name': 'Болд Батаа', 'initials': 'ББ'},
            },
          ),
        );

        expect(exercise.note!.timestampLabel, '08/01, 09:05');
      });

      test('a null note is no note', () async {
        expect((await exerciseFrom(lessonBody())).note, isNull);
      });

      test('a backend lesson simulates no writes, and carries no quiz', () {
        return exerciseFrom(lessonBody()).then((exercise) {
          expect(exercise.simulatesWrites, isFalse);
          expect(exercise.quiz, isNull);
          expect(exercise.assignmentFeedback, isEmpty);
          expect(exercise.assignmentAttachment, isNull);
        });
      });

      test(
        'ignores a quiz summary and an assignment it does not integrate',
        () async {
          final body = lessonBody()
            ..['quiz'] = {'id': 9, 'question_count': 5}
            ..['assignment'] = {'id': 17};

          final exercise = await exerciseFrom(body);

          expect(exercise.quiz, isNull);
          expect(exercise.assignmentFeedback, isEmpty);
        },
      );
    });

    group('a 200 that does not match the contract', () {
      test('malformed JSON', () async {
        final failure = await exerciseFailureFrom(
          lessonRepository(
            (_) async => http.Response.bytes(utf8.encode('{not json'), 200),
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.server);
      });

      test('a body that is not an object', () async {
        expect(
          (await failureForExerciseBody([1])).kind,
          CourseLearningFailureKind.server,
        );
      });

      test('names each missing required field', () async {
        for (final key in [
          'id',
          'module',
          'title',
          'type',
          'duration_seconds',
          'video',
          'summary',
          'sections',
          'completed',
          'materials',
        ]) {
          final failure = await failureForExerciseBody(
            lessonBody()..remove(key),
          );

          expect(failure.kind, CourseLearningFailureKind.server, reason: key);
          expect(failure.detail, contains(key), reason: key);
        }
      });

      test('names a missing module.id and module.order', () async {
        for (final key in ['id', 'order']) {
          final body = lessonBody();
          (body['module'] as Map<String, Object?>).remove(key);

          final failure = await failureForExerciseBody(body);

          expect(failure.detail, contains('module.$key'), reason: key);
        }
      });

      test('a video that is neither an object nor null is a fault', () async {
        final failure = await failureForExerciseBody(lessonBody(video: 'x'));

        expect(failure.detail, contains('lesson.video'));
      });

      test('a section without a title is a fault', () async {
        final failure = await failureForExerciseBody(
          lessonBody(
            sections: [
              {
                'body': {'en': 'Body'},
                'bullets': <Object?>[],
              },
            ],
          ),
        );

        expect(failure.detail, contains('section.title'));
      });

      test('a file material without size_bytes is a fault', () async {
        final material = file(1, 10)..remove('size_bytes');

        final failure = await failureForExerciseBody(
          lessonBody(materials: [material]),
        );

        expect(failure.detail, contains('material.size_bytes'));
      });

      test('a note without its author is a fault', () async {
        final failure = await failureForExerciseBody(
          lessonBody(
            note: {
              'id': 1,
              'content': 'x',
              'created_at': '2026-08-06T01:00:00+00:00',
              'updated_at': '2026-08-06T01:00:00+00:00',
            },
          ),
        );

        expect(failure.detail, contains('author'));
      });

      test('a negative duration is a fault', () async {
        final failure = await failureForExerciseBody(
          lessonBody(durationSeconds: -1),
        );

        expect(failure.detail, contains('lesson.duration_seconds'));
      });
    });

    group('status mapping', () {
      test('401 is a dead session, and the token is forgotten', () async {
        final store = signedIn();
        final failure = await exerciseFailureFrom(
          lessonRepository(
            (_) async => jsonResponse({'error': 'token_expired'}, 401),
            sessionStore: store,
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.sessionExpired);
        expect(store.isSignedIn, isFalse);
      });

      test('403 is not_enrolled, and keeps the token', () async {
        final store = signedIn();
        final failure = await exerciseFailureFrom(
          lessonRepository(
            (_) async => jsonResponse({'error': 'not_enrolled'}, 403),
            sessionStore: store,
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.notEnrolled);
        expect(store.isSignedIn, isTrue);
      });

      test('404 lesson_not_found is notFound', () async {
        final failure = await exerciseFailureFrom(
          lessonRepository(
            (_) async => jsonResponse({'error': 'lesson_not_found'}, 404),
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.notFound);
      });

      test('409 lesson_locked is locked, not a success', () async {
        final failure = await exerciseFailureFrom(
          lessonRepository(
            (_) async => jsonResponse({'error': 'lesson_locked'}, 409),
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.locked);
      });

      test('5xx is a server fault', () async {
        for (final status in [500, 503]) {
          final failure = await exerciseFailureFrom(
            lessonRepository((_) async => jsonResponse({}, status)),
          );

          expect(
            failure.kind,
            CourseLearningFailureKind.server,
            reason: 'HTTP $status',
          );
        }
      });

      test('a request that never completes is a network failure', () async {
        final failure = await exerciseFailureFrom(
          lessonRepository((_) async => throw const SocketException('off')),
        );

        expect(failure.kind, CourseLearningFailureKind.network);
      });
    });
  });

  // §2.5: PUT /me/lessons/{lesson_id}/note — the student's note, saved.
  group('saveNote', () {
    /// 2026-08-06, 15:00 local — the "today" saved timestamps are read
    /// against.
    final now = DateTime(2026, 8, 6, 15);

    /// The contract's §2.5 note object.
    Map<String, Object?> noteBody({
      String content = 'Суурь тохиолдлыг санах',
      Object? updatedAt,
      Object? author = const {'name': 'Сараа Дорж', 'initials': 'СД'},
    }) => {
      'id': 51,
      'content': content,
      'created_at': '2026-08-01T01:00:00+00:00',
      'updated_at':
          updatedAt ?? DateTime(2026, 8, 6, 14, 20).toUtc().toIso8601String(),
      'author': author,
    };

    HttpCourseLearningRepository noteRepository(
      Future<http.Response> Function(http.Request request) handler, {
      AuthSessionStore? sessionStore,
    }) => HttpCourseLearningRepository(
      client: MockClient(handler),
      sessionStore: sessionStore ?? signedIn(),
      clock: () => now,
    );

    Future<CourseExerciseNote> savedFrom(Object? body, [int status = 201]) =>
        noteRepository(
          (_) async => jsonResponse(body, status),
        ).saveNote(204, 'Суурь тохиолдлыг санах');

    Future<CourseLearningFailure> saveFailureFrom(
      HttpCourseLearningRepository repository,
    ) async {
      try {
        await repository.saveNote(204, 'A note');
      } on CourseLearningFailure catch (failure) {
        return failure;
      }
      fail('expected a CourseLearningFailure');
    }

    Future<CourseLearningFailure> failureForStatus(
      int status, [
      Object? body = const {},
    ]) => saveFailureFrom(
      noteRepository((_) async => jsonResponse(body, status)),
    );

    group('the request', () {
      test(
        'PUTs the content as JSON to the lesson\'s note, with the token',
        () async {
          late http.Request sent;
          final repository = noteRepository((request) async {
            sent = request;
            return jsonResponse(noteBody(), 201);
          });

          await repository.saveNote(204, 'Суурь тохиолдлыг санах');

          expect(sent.method, 'PUT');
          expect(
            sent.url.toString(),
            'https://api.ai-academy.asia/me/lessons/204/note',
          );
          expect(
            sent.headers[HttpHeaders.authorizationHeader],
            'Bearer tok-123',
          );
          expect(
            sent.headers[HttpHeaders.contentTypeHeader],
            startsWith('application/json'),
          );
          expect(sent.headers[HttpHeaders.acceptHeader], 'application/json');
          // Decoded as UTF-8, so the Mongolian survives the round trip.
          expect(jsonDecode(sent.body), {'content': 'Суурь тохиолдлыг санах'});
        },
      );

      test('signed out: sends nothing and asks for sign-in', () async {
        var requests = 0;
        final repository = noteRepository((_) async {
          requests++;
          return jsonResponse(noteBody(), 201);
        }, sessionStore: AuthSessionStore());

        final failure = await saveFailureFrom(repository);

        expect(failure.kind, CourseLearningFailureKind.sessionExpired);
        expect(requests, 0);
      });

      test('an expired session: sends nothing', () async {
        var requests = 0;
        final store = AuthSessionStore()
          ..save(
            const AuthSession(
              accessToken: 'old',
              expiresIn: Duration(hours: 1),
            ),
            now: DateTime(2000),
          );
        final repository = noteRepository((_) async {
          requests++;
          return jsonResponse(noteBody(), 201);
        }, sessionStore: store);

        final failure = await saveFailureFrom(repository);

        expect(failure.kind, CourseLearningFailureKind.sessionExpired);
        expect(requests, 0);
      });
    });

    group('the saved note', () {
      test('201 (first save) reads the server\'s note', () async {
        final note = await savedFrom(noteBody(), 201);

        expect(note.message, 'Суурь тохиолдлыг санах');
        expect(note.authorName, 'Сараа Дорж');
        expect(note.authorInitials, 'СД');
        expect(note.authorLabel, 'Me');
      });

      test('200 (an update) reads the same way', () async {
        final note = await savedFrom(noteBody(content: 'Revised'), 200);

        expect(note.message, 'Revised');
        expect(note.authorName, 'Сараа Дорж');
      });

      test('is timestamped from updated_at, against today', () async {
        final note = await savedFrom(noteBody());

        expect(note.timestampLabel, 'Today, 14:20');
      });

      test('an updated_at on another day is dated MM/dd', () async {
        final note = await savedFrom(
          noteBody(
            updatedAt: DateTime(2026, 8, 1, 9, 5).toUtc().toIso8601String(),
          ),
        );

        expect(note.timestampLabel, '08/01, 09:05');
      });
    });

    group('status mapping', () {
      test('400 content_required is its own kind', () async {
        final failure = await failureForStatus(400, {
          'error': 'content_required',
        });

        expect(failure.kind, CourseLearningFailureKind.contentRequired);
      });

      test('400 content_too_long is its own kind', () async {
        final failure = await failureForStatus(400, {
          'error': 'content_too_long',
        });

        expect(failure.kind, CourseLearningFailureKind.contentTooLong);
      });

      test('any other 400, or an unreadable one, is unexpected', () async {
        for (final body in <Object?>[
          {'error': 'invalid_field'},
          {'detail': 'no code'},
          'not an object',
        ]) {
          final failure = await failureForStatus(400, body);

          expect(
            failure.kind,
            CourseLearningFailureKind.unexpected,
            reason: '$body',
          );
        }

        final failure = await saveFailureFrom(
          noteRepository((_) async => http.Response('<html>', 400)),
        );
        expect(failure.kind, CourseLearningFailureKind.unexpected);
      });

      test('401 is a dead session, and the token is forgotten', () async {
        final store = signedIn();
        final failure = await saveFailureFrom(
          noteRepository(
            (_) async => jsonResponse({'error': 'token_expired'}, 401),
            sessionStore: store,
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.sessionExpired);
        expect(store.isSignedIn, isFalse);
      });

      test('403 is not_enrolled, and keeps the token', () async {
        final store = signedIn();
        final failure = await saveFailureFrom(
          noteRepository(
            (_) async => jsonResponse({'error': 'not_enrolled'}, 403),
            sessionStore: store,
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.notEnrolled);
        expect(store.isSignedIn, isTrue);
      });

      test('404 lesson_not_found is not found', () async {
        final failure = await failureForStatus(404, {
          'error': 'lesson_not_found',
        });

        expect(failure.kind, CourseLearningFailureKind.notFound);
      });

      test('409 lesson_locked is locked', () async {
        final failure = await failureForStatus(409, {'error': 'lesson_locked'});

        expect(failure.kind, CourseLearningFailureKind.locked);
      });

      test('5xx is a server fault', () async {
        for (final status in [500, 502, 503]) {
          final failure = await failureForStatus(status);

          expect(
            failure.kind,
            CourseLearningFailureKind.server,
            reason: 'HTTP $status',
          );
        }
      });

      test('a request that never completes is a network failure', () async {
        final failure = await saveFailureFrom(
          noteRepository((_) async => throw const SocketException('off')),
        );

        expect(failure.kind, CourseLearningFailureKind.network);
      });
    });

    group('a malformed answer is a server fault', () {
      test('not JSON', () async {
        final failure = await saveFailureFrom(
          noteRepository((_) async => http.Response('<html>', 201)),
        );

        expect(failure.kind, CourseLearningFailureKind.server);
      });

      test('not an object', () async {
        for (final body in <Object?>[null, [], 'note']) {
          final failure = await saveFailureFrom(
            noteRepository((_) async => jsonResponse(body, 201)),
          );

          expect(
            failure.kind,
            CourseLearningFailureKind.server,
            reason: '$body',
          );
        }
      });

      test('no author', () async {
        final failure = await saveFailureFrom(
          noteRepository(
            (_) async => jsonResponse(noteBody(author: null), 201),
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.server);
        expect(failure.detail, contains('author'));
      });

      test('an updated_at that is not a timestamp', () async {
        final failure = await saveFailureFrom(
          noteRepository(
            (_) async => jsonResponse(noteBody(updatedAt: 'yesterday'), 201),
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.server);
        expect(failure.detail, contains('note.updated_at'));
      });
    });
  });

  // §2.4: GET /me/materials/{material_id}/download — a pre-signed link.
  group('getMaterialDownload', () {
    /// The contract's §2.4 download answer.
    Map<String, Object?> downloadBody({
      Object? url =
          'https://s3.example.test/materials/88.pdf?X-Amz-Signature=x',
      Object? expiresAt = '2026-08-06T01:05:00+00:00',
      Object? fileName = 'week2-slides.pdf',
      Object? sizeBytes = 10485760,
    }) => {
      'url': url,
      'expires_at': expiresAt,
      'file_name': fileName,
      'size_bytes': sizeBytes,
    };

    Future<CourseLearningFailure> downloadFailureFrom(
      HttpCourseLearningRepository repository,
    ) async {
      try {
        await repository.getMaterialDownload(88);
      } on CourseLearningFailure catch (failure) {
        return failure;
      }
      fail('expected a CourseLearningFailure');
    }

    Future<CourseLearningFailure> failureForStatus(
      int status, [
      Object? body = const {},
    ]) => downloadFailureFrom(
      repositoryReturning((_) async => jsonResponse(body, status)),
    );

    Future<CourseLearningFailure> failureForBody(Object? body) =>
        downloadFailureFrom(
          repositoryReturning((_) async => jsonResponse(body)),
        );

    group('the request', () {
      test(
        'GETs /me/materials/{material_id}/download with the token',
        () async {
          late http.Request sent;
          final repository = repositoryReturning((request) async {
            sent = request;
            return jsonResponse(downloadBody());
          });

          await repository.getMaterialDownload(88);

          expect(sent.method, 'GET');
          expect(
            sent.url.toString(),
            'https://api.ai-academy.asia/me/materials/88/download',
          );
          expect(
            sent.headers[HttpHeaders.authorizationHeader],
            'Bearer tok-123',
          );
          expect(sent.headers[HttpHeaders.acceptHeader], 'application/json');
          expect(sent.body, isEmpty);
        },
      );

      test('signed out: sends nothing and asks for sign-in', () async {
        var requests = 0;
        final repository = repositoryReturning((_) async {
          requests++;
          return jsonResponse(downloadBody());
        }, sessionStore: AuthSessionStore());

        final failure = await downloadFailureFrom(repository);

        expect(failure.kind, CourseLearningFailureKind.sessionExpired);
        expect(requests, 0);
      });

      test('an expired session: sends nothing', () async {
        var requests = 0;
        final store = AuthSessionStore()
          ..save(
            const AuthSession(
              accessToken: 'old',
              expiresIn: Duration(hours: 1),
            ),
            now: DateTime(2000),
          );
        final repository = repositoryReturning((_) async {
          requests++;
          return jsonResponse(downloadBody());
        }, sessionStore: store);

        final failure = await downloadFailureFrom(repository);

        expect(failure.kind, CourseLearningFailureKind.sessionExpired);
        expect(requests, 0);
      });
    });

    group('the answer', () {
      test('reads the pre-signed link in full', () async {
        final download = await repositoryAnswering(
          downloadBody(),
        ).getMaterialDownload(88);

        expect(
          download.url,
          Uri.parse(
            'https://s3.example.test/materials/88.pdf?X-Amz-Signature=x',
          ),
        );
        expect(download.expiresAt, DateTime.utc(2026, 8, 6, 1, 5));
        expect(download.fileName, 'week2-slides.pdf');
        expect(download.sizeBytes, 10485760);
      });

      test('an http link is accepted as well as https', () async {
        final download = await repositoryAnswering(
          downloadBody(url: 'http://minio.local/materials/88.pdf'),
        ).getMaterialDownload(88);

        expect(download.url.scheme, 'http');
      });
    });

    group('status mapping', () {
      test('401 is a dead session, and the token is forgotten', () async {
        final store = signedIn();
        final failure = await downloadFailureFrom(
          repositoryReturning(
            (_) async => jsonResponse({'error': 'token_expired'}, 401),
            sessionStore: store,
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.sessionExpired);
        expect(store.isSignedIn, isFalse);
      });

      test('403 is not_enrolled, and keeps the token', () async {
        final store = signedIn();
        final failure = await downloadFailureFrom(
          repositoryReturning(
            (_) async => jsonResponse({'error': 'not_enrolled'}, 403),
            sessionStore: store,
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.notEnrolled);
        expect(store.isSignedIn, isTrue);
      });

      test('404 material_not_found is not found', () async {
        final failure = await failureForStatus(404, {
          'error': 'material_not_found',
        });

        expect(failure.kind, CourseLearningFailureKind.notFound);
      });

      test('409 reads as locked, as it does on every endpoint here', () async {
        final failure = await failureForStatus(409, {'error': 'lesson_locked'});

        expect(failure.kind, CourseLearningFailureKind.locked);
      });

      test('503 storage_error, and any 5xx, is a server fault', () async {
        for (final status in [500, 502, 503]) {
          final failure = await failureForStatus(status, {
            'error': 'storage_error',
          });

          expect(
            failure.kind,
            CourseLearningFailureKind.server,
            reason: 'HTTP $status',
          );
        }
      });

      test('a request that never completes is a network failure', () async {
        final failure = await downloadFailureFrom(
          repositoryReturning((_) async => throw const SocketException('off')),
        );

        expect(failure.kind, CourseLearningFailureKind.network);
      });
    });

    group('a malformed answer is a server fault', () {
      test('not JSON', () async {
        final failure = await downloadFailureFrom(
          repositoryReturning((_) async => http.Response('<html>', 200)),
        );

        expect(failure.kind, CourseLearningFailureKind.server);
      });

      test('not an object', () async {
        for (final body in <Object?>[null, [], 'link']) {
          final failure = await failureForBody(body);

          expect(
            failure.kind,
            CourseLearningFailureKind.server,
            reason: '$body',
          );
        }
      });

      test('no url, or not an http(s) one', () async {
        for (final url in <Object?>[
          null,
          '',
          42,
          '/materials/88.pdf',
          'ftp://files.example.test/88.pdf',
          'javascript:alert(1)',
        ]) {
          final failure = await failureForBody(downloadBody(url: url));

          expect(
            failure.kind,
            CourseLearningFailureKind.server,
            reason: '$url',
          );
          expect(failure.detail, contains('download.url'), reason: '$url');
        }
      });

      test('an expires_at that is missing or not a timestamp', () async {
        for (final expiresAt in <Object?>[null, 'in five minutes']) {
          final failure = await failureForBody(
            downloadBody(expiresAt: expiresAt),
          );

          expect(failure.kind, CourseLearningFailureKind.server);
          expect(failure.detail, contains('download.expires_at'));
        }
      });

      test('no file_name', () async {
        final failure = await failureForBody(downloadBody(fileName: null));

        expect(failure.detail, contains('download.file_name'));
      });

      test('a missing or negative size_bytes', () async {
        for (final size in <Object?>[null, '10 MB', -1]) {
          final failure = await failureForBody(downloadBody(sizeBytes: size));

          expect(failure.kind, CourseLearningFailureKind.server);
          expect(failure.detail, contains('download.size_bytes'));
        }
      });
    });
  });
}
