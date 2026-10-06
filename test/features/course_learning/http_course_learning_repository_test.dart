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
import 'package:aia_mobile/features/course_learning/domain/uploaded_file.dart';
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

      test('keeps file and link materials in the server\'s order', () async {
        final exercise = await exerciseFrom(lessonBody());

        expect(exercise.materials.map((m) => m.id), [88, 89, 90]);
        expect(exercise.materials.map((m) => m.name), [
          'Course material 1',
          'Reading list',
          'Notes',
        ]);
        expect(exercise.materials.map((m) => m.isLink), [false, true, false]);
      });

      test('a file has its size and no URL of its own', () async {
        final file = (await exerciseFrom(lessonBody())).materials.first;

        expect(file.url, isNull);
        expect(file.sizeLabel, '10 MB');
      });

      test('a link keeps the server\'s URL exactly, and has no size', () async {
        const raw = 'https://reading.example.test/list?ref=lesson-204#part-2';
        final exercise = await exerciseFrom(
          lessonBody(
            materials: [
              {
                'id': 77,
                'title': 'Further reading',
                'type': 'link',
                'url': raw,
              },
            ],
          ),
        );

        final link = exercise.materials.single;
        expect(link.id, 77);
        expect(link.name, 'Further reading');
        expect(link.url.toString(), raw);
        expect(link.sizeLabel, isEmpty);
      });

      test('a link without a usable http(s) URL is a fault', () async {
        for (final url in <Object?>[
          null,
          '',
          42,
          'www.example.test/no-scheme',
          'ftp://files.example.test/a.pdf',
          'javascript:alert(1)',
          'https://',
        ]) {
          final failure = await failureForExerciseBody(
            lessonBody(
              materials: [
                {'id': 89, 'title': 'Reading list', 'type': 'link', 'url': url},
              ],
            ),
          );

          expect(
            failure.kind,
            CourseLearningFailureKind.server,
            reason: '$url',
          );
          expect(failure.detail, contains('material.url'), reason: '$url');
        }
      });

      test('a link without its title or id is a fault', () async {
        for (final key in ['title', 'id']) {
          final link = <String, Object?>{
            'id': 89,
            'title': 'Reading list',
            'type': 'link',
            'url': 'https://reading.example.test/list',
          }..remove(key);

          final failure = await failureForExerciseBody(
            lessonBody(materials: [link]),
          );

          expect(failure.detail, contains('material.$key'), reason: key);
        }
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

      group('quiz (§2.7 summary)', () {
        Map<String, Object?> quizBody({
          Object? attemptsLeft,
          Object? openAttemptId,
          Object? lastResult,
        }) => {
          'id': 9,
          'title': {'mn': 'Давталтын quiz', 'en': 'Loops quiz'},
          'question_count': 5,
          'pass_percent': 70,
          'attempts_used': 1,
          'attempts_left': attemptsLeft,
          'open_attempt_id': openAttemptId,
          'last_result': lastResult,
        };

        test('reads the summary, Mongolian title first', () async {
          final body = lessonBody()
            ..['quiz'] = quizBody(attemptsLeft: 2, openAttemptId: 41);

          final quiz = (await exerciseFrom(body)).quiz!;

          expect(quiz.id, 9);
          expect(quiz.title, 'Давталтын quiz');
          expect(quiz.questionCount, 5);
          expect(quiz.attemptsLeft, 2);
          expect(quiz.openAttemptId, 41);
          expect(quiz.lastResult, isNull);
          expect(quiz.canRetake, isTrue);
        });

        test('null attempts_left is unlimited, 0 is none left', () async {
          final unlimited = (await exerciseFrom(
            lessonBody()..['quiz'] = quizBody(),
          )).quiz!;
          final none = (await exerciseFrom(
            lessonBody()..['quiz'] = quizBody(attemptsLeft: 0),
          )).quiz!;

          expect(unlimited.attemptsLeft, isNull);
          expect(unlimited.canRetake, isTrue);
          expect(none.canRetake, isFalse);
        });

        test('reads last_result as the server sent it', () async {
          final body = lessonBody()
            ..['quiz'] = quizBody(
              lastResult: {
                'attempt_id': 40,
                'correct': 4,
                'total': 5,
                'percent': 80,
                'passed': true,
                'finished_at': '2026-08-06T03:00:00+00:00',
              },
            );

          final result = (await exerciseFrom(body)).quiz!.lastResult!;

          expect(result.attemptId, 40);
          expect(result.correct, 4);
          expect(result.total, 5);
          expect(result.percent, 80);
          expect(result.passed, isTrue);
        });

        test('the result title is the module\'s, as the Figma frame writes '
            'it', () async {
          final body = lessonBody()..['quiz'] = quizBody();

          final quiz = (await exerciseFrom(body)).quiz!;

          expect(quiz.resultTitle, 'Level 2 - Хоёрдугаар');
        });

        test(
          'with no module title, the quiz\'s own title heads the result',
          () async {
            final body = lessonBody()..['quiz'] = quizBody();
            (body['module']! as Map<String, Object?>).remove('title');

            final quiz = (await exerciseFrom(body)).quiz!;

            expect(quiz.resultTitle, 'Давталтын quiz');
          },
        );

        test('a malformed summary is a server fault', () async {
          for (final quiz in <Object?>[
            'quiz',
            {...quizBody(), 'id': null},
            {...quizBody(), 'question_count': '5'},
            {...quizBody(), 'attempts_left': 'many'},
            {...quizBody(), 'last_result': 'none'},
            {
              ...quizBody(),
              'last_result': {'attempt_id': 40},
            },
          ]) {
            final failure = await failureForExerciseBody(
              lessonBody()..['quiz'] = quiz,
            );

            expect(
              failure.kind,
              CourseLearningFailureKind.server,
              reason: '$quiz',
            );
          }
        });
      });
    });

    // §2.6: the lesson's `assignment`, read-only.
    group('assignment', () {
      /// The contract's §2.6 feedback object.
      Map<String, Object?> feedbackBody({
        Object? role = 'teacher',
        Object? createdAt,
        Object? mentor = _defaultMentor,
      }) => {
        'message': 'Сайн ажил — баталгаажуулалтыг сайжруул.',
        'created_at':
            createdAt ?? DateTime(2026, 8, 6, 14, 20).toUtc().toIso8601String(),
        'mentor': identical(mentor, _defaultMentor)
            ? {'id': 4, 'name': 'Дорж Бат', 'initials': 'ДБ', 'role': role}
            : mentor,
      };

      /// The contract's §2.6 submission object.
      Map<String, Object?> submissionBody({
        Object? status = 'submitted',
        Object? link = 'https://github.com/student/loops',
        Object? description = 'Давталтын дасгал',
        Object? submittedAt = '2026-08-05T03:00:00+00:00',
        Object? feedback,
      }) => {
        'id': 301,
        'version': 2,
        'status': status,
        'link': link,
        'description': description,
        'file': null,
        'submitted_at': submittedAt,
        'score': null,
        'feedback': feedback,
      };

      /// The contract's §2.6 assignment object — every documented field,
      /// including the ones this client does not read.
      Map<String, Object?> assignmentBody({
        Object? submission,
        Object? attachment,
      }) => {
        'id': 17,
        'title': {'mn': 'Даалгавар', 'en': 'Assignment'},
        'instructions': null,
        'due_date': null,
        'max_score': 100,
        'attachment': attachment,
        'submission': submission,
      };

      Future<CourseExercise> withAssignment(Object? assignment) =>
          exerciseFrom(lessonBody()..['assignment'] = assignment);

      Future<CourseLearningFailure> failureWithAssignment(Object? assignment) =>
          failureForExerciseBody(lessonBody()..['assignment'] = assignment);

      test('assignment: null is no assignment', () async {
        final exercise = await withAssignment(null);

        expect(exercise.assignment, isNull);
      });

      test('an absent assignment is no assignment, as for the note', () async {
        final exercise = await exerciseFrom(lessonBody()..remove('assignment'));

        expect(exercise.assignment, isNull);
      });

      test('an assignment with nothing submitted yet', () async {
        final exercise = await withAssignment(assignmentBody());

        expect(exercise.assignment!.id, 17);
        expect(exercise.assignment!.submission, isNull);
      });

      test('a submission not yet reviewed', () async {
        final exercise = await withAssignment(
          assignmentBody(submission: submissionBody()),
        );

        final submission = exercise.assignment!.submission!;
        expect(submission.id, 301);
        expect(submission.version, 2);
        expect(submission.status, AssignmentSubmissionStatus.submitted);
        expect(submission.link, 'https://github.com/student/loops');
        expect(submission.description, 'Давталтын дасгал');
        expect(submission.submittedAt, DateTime.utc(2026, 8, 5, 3));
        expect(submission.feedback, isNull);
      });

      test('a reviewed submission carries the mentor\'s feedback', () async {
        final exercise = await withAssignment(
          assignmentBody(
            submission: submissionBody(
              status: 'reviewed',
              feedback: feedbackBody(),
            ),
          ),
        );

        final submission = exercise.assignment!.submission!;
        expect(submission.status, AssignmentSubmissionStatus.reviewed);
        final feedback = submission.feedback!;
        expect(feedback.mentorInitials, 'ДБ');
        expect(feedback.mentorName, 'Дорж Бат');
        expect(feedback.mentorRole, 'Lead Mentor');
        expect(feedback.message, 'Сайн ажил — баталгаажуулалтыг сайжруул.');
        expect(feedback.timestampLabel, 'Today, 14:20');
      });

      test('an older review is dated MM/dd', () async {
        final exercise = await withAssignment(
          assignmentBody(
            submission: submissionBody(
              feedback: feedbackBody(
                createdAt: DateTime(2026, 8, 1, 9, 5).toUtc().toIso8601String(),
              ),
            ),
          ),
        );

        expect(
          exercise.assignment!.submission!.feedback!.timestampLabel,
          '08/01, 09:05',
        );
      });

      test('a role with no copy draws no role label', () async {
        final exercise = await withAssignment(
          assignmentBody(
            submission: submissionBody(feedback: feedbackBody(role: 'staff')),
          ),
        );

        expect(exercise.assignment!.submission!.feedback!.mentorRole, isEmpty);
      });

      test('the documented nullable fields may be null', () async {
        final exercise = await withAssignment(
          assignmentBody(
            submission: submissionBody(link: null, description: null),
          ),
        );

        final submission = exercise.assignment!.submission!;
        expect(submission.link, isNull);
        expect(submission.description, isNull);
      });

      test('an unrecognised status is unknown, not a failure', () async {
        final exercise = await withAssignment(
          assignmentBody(submission: submissionBody(status: 'archived')),
        );

        expect(
          exercise.assignment!.submission!.status,
          AssignmentSubmissionStatus.unknown,
        );
      });

      test('the sample-only assignment fields stay empty', () async {
        final exercise = await withAssignment(
          assignmentBody(submission: submissionBody(feedback: feedbackBody())),
        );

        // The canned sequence and the attachment are the sample's; a backend
        // lesson's feedback lives on its submission.
        expect(exercise.assignmentFeedback, isEmpty);
        expect(exercise.assignmentAttachment, isNull);
      });

      group('attachment (§2.6: a §2.4 material or null)', () {
        /// The teacher's attachment as §2.4 sends a stored file.
        const fileAttachment = <String, Object?>{
          'id': 55,
          'title': 'Homework template',
          'type': 'file',
          'file_name': 'homework-template.pdf',
          'content_type': 'application/pdf',
          'size_bytes': 2097152,
        };

        /// …and as an external link.
        const linkAttachment = <String, Object?>{
          'id': 56,
          'title': 'Starter repository',
          'type': 'link',
          'url': 'https://github.com/ai-academy/starter?ref=lesson-204#readme',
        };

        test(
          'attachment: null is no attachment, and adds no material',
          () async {
            final exercise = await withAssignment(assignmentBody());

            expect(exercise.assignment!.attachment, isNull);
            expect(
              exercise.allMaterials.map((m) => m.id),
              exercise.materials.map((m) => m.id),
            );
          },
        );

        test('a file attachment reads as a file material', () async {
          final exercise = await withAssignment(
            assignmentBody(attachment: fileAttachment),
          );

          final attachment = exercise.assignment!.attachment!;
          expect(attachment.id, 55);
          expect(attachment.name, 'Homework template');
          expect(attachment.sizeLabel, '2 MB');
          expect(attachment.url, isNull);
          expect(attachment.isLink, isFalse);
        });

        test('a link attachment keeps the server\'s URL exactly, and has no '
            'size', () async {
          final exercise = await withAssignment(
            assignmentBody(attachment: linkAttachment),
          );

          final attachment = exercise.assignment!.attachment!;
          expect(attachment.id, 56);
          expect(attachment.name, 'Starter repository');
          expect(attachment.url.toString(), linkAttachment['url']);
          expect(attachment.sizeLabel, isEmpty);
          expect(attachment.isLink, isTrue);
        });

        test('it is listed after the lesson\'s own materials', () async {
          final exercise = await withAssignment(
            assignmentBody(attachment: fileAttachment),
          );

          // The lesson's own list is untouched…
          expect(exercise.materials.map((m) => m.id), [88, 89, 90]);
          // …and the Course materials tab lists the attachment after it.
          expect(exercise.allMaterials.map((m) => m.id), [88, 89, 90, 55]);
        });

        test('one that is also among the lesson\'s materials is listed '
            'once, in its own place', () async {
          final exercise = await withAssignment(
            assignmentBody(attachment: {...fileAttachment, 'id': 89}),
          );

          expect(exercise.allMaterials.map((m) => m.id), [88, 89, 90]);
        });

        test('an unrecognised type is left out, as for a lesson material — '
            'not a failure', () async {
          final exercise = await withAssignment(
            assignmentBody(
              attachment: const {
                'id': 57,
                'title': 'Mystery',
                'type': 'hologram',
              },
            ),
          );

          expect(exercise.assignment, isNotNull);
          expect(exercise.assignment!.attachment, isNull);
          expect(exercise.allMaterials.map((m) => m.id), [88, 89, 90]);
        });

        test(
          'it never reaches the Assignment tab\'s sample-only attachment',
          () async {
            final exercise = await withAssignment(
              assignmentBody(attachment: fileAttachment),
            );

            expect(exercise.assignmentAttachment, isNull);
          },
        );

        test('it survives a submission landing', () async {
          final exercise = await withAssignment(
            assignmentBody(attachment: linkAttachment),
          );

          final submitted = exercise.withAssignmentSubmission(
            AssignmentSubmission(
              id: 302,
              version: 1,
              status: AssignmentSubmissionStatus.submitted,
              submittedAt: DateTime.utc(2026, 8, 6),
              link: 'https://github.com/student/loops',
            ),
          );

          expect(
            submitted.assignment!.attachment,
            same(exercise.assignment!.attachment),
          );
          expect(submitted.assignment!.submission!.id, 302);
          expect(
            submitted.allMaterials.map((m) => m.id),
            exercise.allMaterials.map((m) => m.id),
          );
        });

        group('a malformed attachment is a server fault', () {
          Future<void> expectFault(Object? attachment, String field) async {
            final failure = await failureWithAssignment(
              assignmentBody(attachment: attachment),
            );

            expect(failure.kind, CourseLearningFailureKind.server);
            expect(failure.detail, contains(field));
          }

          test('not an object', () async {
            await expectFault('template.pdf', 'material');
            await expectFault([fileAttachment], 'material');
          });

          test('no type', () async {
            await expectFault(
              {...fileAttachment}..remove('type'),
              'material.type',
            );
          });

          test('a file without its id, title or size_bytes', () async {
            for (final key in ['id', 'title', 'size_bytes']) {
              await expectFault(
                {...fileAttachment}..remove(key),
                'material.$key',
              );
            }
          });

          test('a link without a usable http(s) URL', () async {
            for (final url in <Object?>[null, '', 'javascript:alert(1)']) {
              await expectFault({
                ...linkAttachment,
                'url': url,
              }, 'material.url');
            }
          });
        });
      });

      group('a malformed assignment is a server fault', () {
        Future<void> expectFault(Object? assignment, String field) async {
          final failure = await failureWithAssignment(assignment);

          expect(failure.kind, CourseLearningFailureKind.server);
          expect(failure.detail, contains(field));
        }

        test('not an object', () async {
          await expectFault('assignment', 'assignment');
          await expectFault([], 'assignment');
        });

        test('no id', () async {
          await expectFault(assignmentBody()..remove('id'), 'assignment.id');
        });

        test('a submission that is not an object', () async {
          await expectFault(
            assignmentBody(submission: 'done'),
            'assignment.submission',
          );
        });

        test('a submission without id, version or status', () async {
          for (final field in ['id', 'version', 'status']) {
            await expectFault(
              assignmentBody(submission: submissionBody()..remove(field)),
              'assignment.submission.$field',
            );
          }
        });

        test('a submitted_at that is missing or not a timestamp', () async {
          for (final value in <Object?>[null, 'yesterday']) {
            await expectFault(
              assignmentBody(submission: submissionBody(submittedAt: value)),
              'assignment.submission.submitted_at',
            );
          }
        });

        test('a link or description that is not a string', () async {
          await expectFault(
            assignmentBody(submission: submissionBody(link: 42)),
            'assignment.submission.link',
          );
          await expectFault(
            assignmentBody(submission: submissionBody(description: true)),
            'assignment.submission.description',
          );
        });

        test('feedback that is not an object', () async {
          await expectFault(
            assignmentBody(submission: submissionBody(feedback: 'good')),
            'assignment.submission.feedback',
          );
        });

        test('feedback without a mentor, or a mentor without a name', () async {
          await expectFault(
            assignmentBody(
              submission: submissionBody(feedback: feedbackBody(mentor: null)),
            ),
            'mentor',
          );
          await expectFault(
            assignmentBody(
              submission: submissionBody(
                feedback: feedbackBody(
                  mentor: const {'id': 4, 'initials': 'ДБ', 'role': 'teacher'},
                ),
              ),
            ),
            'feedback.mentor.name',
          );
        });

        test('feedback without a message or created_at', () async {
          await expectFault(
            assignmentBody(
              submission: submissionBody(
                feedback: feedbackBody()..remove('message'),
              ),
            ),
            'feedback.message',
          );
          await expectFault(
            assignmentBody(
              submission: submissionBody(
                feedback: feedbackBody(createdAt: 'soon'),
              ),
            ),
            'feedback.created_at',
          );
        });
      });
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
  group('completeLesson (§2.3 mark complete)', () {
    /// The contract's own answer: `completed` and §2.1's progress object.
    Map<String, Object?> completionBody({
      Object? completed = true,
      Object? progress = const {
        'percent': 35,
        'completed_lessons': 7,
        'total_lessons': 20,
      },
    }) => {'completed': completed, 'progress': progress};

    Future<CourseLearningFailure> failureOf(
      Future<Object?> Function() call,
    ) async {
      try {
        await call();
      } on CourseLearningFailure catch (failure) {
        return failure;
      }
      fail('expected a CourseLearningFailure');
    }

    test('POSTs to the lesson it was asked for, with the token and no '
        'body', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return jsonResponse(completionBody());
      });

      await repository.completeLesson(204);

      expect(sent.method, 'POST');
      expect(
        sent.url.toString(),
        'https://api.ai-academy.asia/me/lessons/204/complete',
      );
      expect(sent.headers[HttpHeaders.authorizationHeader], 'Bearer tok-123');
      expect(sent.body, isEmpty);
    });

    test('reads completed and progress.percent', () async {
      final completion = await repositoryReturning(
        (_) async => jsonResponse(completionBody()),
      ).completeLesson(204);

      expect(completion.completed, isTrue);
      expect(completion.percentComplete, 35);
    });

    test('reads a completed: false as sent, rather than assuming '
        'true', () async {
      final completion = await repositoryReturning(
        (_) async => jsonResponse(completionBody(completed: false)),
      ).completeLesson(204);

      expect(completion.completed, isFalse);
    });

    test('clamps a percent outside 0-100, as the learning path does', () async {
      final completion = await repositoryReturning(
        (_) async => jsonResponse(completionBody(progress: {'percent': 140})),
      ).completeLesson(204);

      expect(completion.percentComplete, 100);
    });

    test('status mapping follows the lesson detail\'s', () async {
      Future<CourseLearningFailureKind> kindFor(
        int status,
        String code,
      ) async => (await failureOf(
        () => repositoryReturning(
          (_) async => jsonResponse({'error': code}, status),
        ).completeLesson(204),
      )).kind;

      expect(
        await kindFor(404, 'lesson_not_found'),
        CourseLearningFailureKind.notFound,
      );
      expect(
        await kindFor(403, 'not_enrolled'),
        CourseLearningFailureKind.notEnrolled,
      );
      expect(
        await kindFor(409, 'lesson_locked'),
        CourseLearningFailureKind.locked,
      );
      expect(await kindFor(500, 'boom'), CourseLearningFailureKind.server);
    });

    test('401 is a dead session, and the token is forgotten', () async {
      final store = signedIn();
      final failure = await failureOf(
        () => repositoryReturning(
          (_) async => jsonResponse({'error': 'invalid_token'}, 401),
          sessionStore: store,
        ).completeLesson(204),
      );

      expect(failure.kind, CourseLearningFailureKind.sessionExpired);
      expect(store.isSignedIn, isFalse);
    });

    test('a request that never completes is a network failure', () async {
      final failure = await failureOf(
        () => repositoryReturning(
          (_) async => throw const SocketException('offline'),
        ).completeLesson(204),
      );

      expect(failure.kind, CourseLearningFailureKind.network);
    });

    test('a malformed answer is a server fault', () async {
      for (final body in <Object?>[
        'done',
        completionBody(completed: null),
        completionBody(completed: 'true'),
        completionBody(progress: null),
        completionBody(progress: {'percent': '35'}),
      ]) {
        final failure = await failureOf(
          () => repositoryReturning(
            (_) async => jsonResponse(body),
          ).completeLesson(204),
        );

        expect(failure.kind, CourseLearningFailureKind.server, reason: '$body');
      }
    });

    test('without a session, nothing is sent', () async {
      var sent = false;
      final failure = await failureOf(
        () => repositoryReturning((_) async {
          sent = true;
          return jsonResponse(completionBody());
        }, sessionStore: AuthSessionStore()).completeLesson(204),
      );

      expect(sent, isFalse);
      expect(failure.kind, CourseLearningFailureKind.sessionExpired);
    });
  });

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
          // Parses with an empty authority, but names no host to open.
          'https://',
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

  // §2.6: POST /me/assignments/{assignment_id}/submissions — a link.
  group('submitAssignment', () {
    /// 2026-08-06, 15:00 local — the "today" feedback is labelled against.
    final now = DateTime(2026, 8, 6, 15);

    /// The contract's §2.6 submission object, as a submit answers.
    Map<String, Object?> submissionBody({
      Object? feedback,
      Object? version = 1,
    }) => {
      'id': 301,
      'version': version,
      'status': 'submitted',
      'link': 'https://github.com/student/loops',
      'description': 'Давталтын дасгал',
      'file': null,
      'submitted_at': '2026-08-06T03:00:00+00:00',
      'score': null,
      'feedback': feedback,
    };

    HttpCourseLearningRepository submitRepository(
      Future<http.Response> Function(http.Request request) handler, {
      AuthSessionStore? sessionStore,
    }) => HttpCourseLearningRepository(
      client: MockClient(handler),
      sessionStore: sessionStore ?? signedIn(),
      clock: () => now,
    );

    Future<CourseLearningFailure> submitFailureFrom(
      HttpCourseLearningRepository repository,
    ) async {
      try {
        await repository.submitAssignment(17, link: 'https://x.test');
      } on CourseLearningFailure catch (failure) {
        return failure;
      }
      fail('expected a CourseLearningFailure');
    }

    Future<CourseLearningFailure> failureForStatus(
      int status, [
      Object? body = const {},
    ]) => submitFailureFrom(
      submitRepository((_) async => jsonResponse(body, status)),
    );

    group('the request', () {
      test(
        'POSTs the link as JSON to the assignment, with the token',
        () async {
          late http.Request sent;
          final repository = submitRepository((request) async {
            sent = request;
            return jsonResponse(submissionBody(), 201);
          });

          await repository.submitAssignment(
            17,
            link: 'https://github.com/student/loops',
            description: 'Давталтын дасгал',
          );

          expect(sent.method, 'POST');
          expect(
            sent.url.toString(),
            'https://api.ai-academy.asia/me/assignments/17/submissions',
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
          expect(jsonDecode(sent.body), {
            'link': 'https://github.com/student/loops',
            'description': 'Давталтын дасгал',
            'file_id': null,
          });
        },
      );

      test('file_id is always sent — null when no file is attached', () async {
        late http.Request sent;
        final repository = submitRepository((request) async {
          sent = request;
          return jsonResponse(submissionBody(), 201);
        });

        await repository.submitAssignment(17, link: 'https://x.test');

        final body = jsonDecode(sent.body) as Map<String, dynamic>;
        expect(body.containsKey('file_id'), isTrue);
        expect(body['file_id'], isNull);
        // No description is sent as null, not left out.
        expect(body.containsKey('description'), isTrue);
        expect(body['description'], isNull);
      });

      test('a file submission sends the upload\'s id as file_id', () async {
        late http.Request sent;
        final repository = submitRepository((request) async {
          sent = request;
          return jsonResponse(submissionBody(), 201);
        });

        await repository.submitAssignment(
          17,
          fileId: 77,
          description: 'Тайлбар',
        );

        // The same three keys as a link submission; the link is null.
        expect(jsonDecode(sent.body), {
          'link': null,
          'description': 'Тайлбар',
          'file_id': 77,
        });
      });

      test('a link and a file are sent together', () async {
        late http.Request sent;
        final repository = submitRepository((request) async {
          sent = request;
          return jsonResponse(submissionBody(), 201);
        });

        await repository.submitAssignment(
          17,
          link: 'https://x.test',
          fileId: 77,
        );

        final body = jsonDecode(sent.body) as Map<String, dynamic>;
        expect(body['link'], 'https://x.test');
        expect(body['file_id'], 77);
      });

      test('signed out: sends nothing and asks for sign-in', () async {
        var requests = 0;
        final repository = submitRepository((_) async {
          requests++;
          return jsonResponse(submissionBody(), 201);
        }, sessionStore: AuthSessionStore());

        final failure = await submitFailureFrom(repository);

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
        final repository = submitRepository((_) async {
          requests++;
          return jsonResponse(submissionBody(), 201);
        }, sessionStore: store);

        final failure = await submitFailureFrom(repository);

        expect(failure.kind, CourseLearningFailureKind.sessionExpired);
        expect(requests, 0);
      });
    });

    group('the answer', () {
      test('201 reads the new submission', () async {
        final submission = await submitRepository(
          (_) async => jsonResponse(submissionBody(version: 2), 201),
        ).submitAssignment(17, link: 'https://x.test');

        expect(submission.id, 301);
        expect(submission.version, 2);
        expect(submission.status, AssignmentSubmissionStatus.submitted);
        expect(submission.link, 'https://github.com/student/loops');
        expect(submission.description, 'Давталтын дасгал');
        expect(submission.submittedAt, DateTime.utc(2026, 8, 6, 3));
        expect(submission.feedback, isNull);
      });

      test(
        'feedback in the answer is read like the lesson detail\'s',
        () async {
          final submission = await submitRepository(
            (_) async => jsonResponse(
              submissionBody(
                feedback: {
                  'message': 'Сайн.',
                  'created_at': DateTime(
                    2026,
                    8,
                    6,
                    14,
                    20,
                  ).toUtc().toIso8601String(),
                  'mentor': {
                    'id': 4,
                    'name': 'Дорж Бат',
                    'initials': 'ДБ',
                    'role': 'teacher',
                  },
                },
              ),
              201,
            ),
          ).submitAssignment(17, link: 'https://x.test');

          final feedback = submission.feedback!;
          expect(feedback.mentorName, 'Дорж Бат');
          expect(feedback.mentorRole, 'Lead Mentor');
          expect(feedback.timestampLabel, 'Today, 14:20');
        },
      );
    });

    group('status mapping', () {
      test('the three 400 codes are their own kinds', () async {
        final expected = {
          'submission_empty': CourseLearningFailureKind.submissionEmpty,
          'invalid_link': CourseLearningFailureKind.invalidLink,
          'description_too_long': CourseLearningFailureKind.descriptionTooLong,
        };
        for (final MapEntry(key: code, value: kind) in expected.entries) {
          final failure = await failureForStatus(400, {'error': code});

          expect(failure.kind, kind, reason: code);
        }
      });

      test('an undocumented 400 code is unexpected, not guessed at', () async {
        for (final code in ['file_required', 'submission_conflict']) {
          final failure = await failureForStatus(400, {'error': code});

          expect(
            failure.kind,
            CourseLearningFailureKind.unexpected,
            reason: code,
          );
        }
      });

      test('409 past_due is its own kind, not locked', () async {
        final failure = await failureForStatus(409, {'error': 'past_due'});

        expect(failure.kind, CourseLearningFailureKind.pastDue);
      });

      test('409 lesson_locked, or any other 409, is still locked', () async {
        for (final body in <Object?>[
          {'error': 'lesson_locked'},
          {'error': 'submission_conflict'},
          'not json',
        ]) {
          final failure = await failureForStatus(409, body);

          expect(
            failure.kind,
            CourseLearningFailureKind.locked,
            reason: '$body',
          );
        }
      });

      test('401 is a dead session, and the token is forgotten', () async {
        final store = signedIn();
        final failure = await submitFailureFrom(
          submitRepository(
            (_) async => jsonResponse({'error': 'token_expired'}, 401),
            sessionStore: store,
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.sessionExpired);
        expect(store.isSignedIn, isFalse);
      });

      test('403 is not_enrolled, and keeps the token', () async {
        final store = signedIn();
        final failure = await submitFailureFrom(
          submitRepository(
            (_) async => jsonResponse({'error': 'not_enrolled'}, 403),
            sessionStore: store,
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.notEnrolled);
        expect(store.isSignedIn, isTrue);
      });

      test('404 assignment_not_found is not found', () async {
        final failure = await failureForStatus(404, {
          'error': 'assignment_not_found',
        });

        expect(failure.kind, CourseLearningFailureKind.notFound);
      });

      test('5xx is a server fault', () async {
        for (final status in [500, 503]) {
          final failure = await failureForStatus(status);

          expect(
            failure.kind,
            CourseLearningFailureKind.server,
            reason: 'HTTP $status',
          );
        }
      });

      test('a request that never completes is a network failure', () async {
        final failure = await submitFailureFrom(
          submitRepository((_) async => throw const SocketException('off')),
        );

        expect(failure.kind, CourseLearningFailureKind.network);
      });
    });

    group('a malformed answer is a server fault', () {
      test('not JSON', () async {
        final failure = await submitFailureFrom(
          submitRepository((_) async => http.Response('<html>', 201)),
        );

        expect(failure.kind, CourseLearningFailureKind.server);
      });

      test('not an object', () async {
        for (final body in <Object?>[null, [], 'ok']) {
          final failure = await submitFailureFrom(
            submitRepository((_) async => jsonResponse(body, 201)),
          );

          expect(
            failure.kind,
            CourseLearningFailureKind.server,
            reason: '$body',
          );
        }
      });

      test('a submission without its required fields', () async {
        for (final field in ['id', 'version', 'status', 'submitted_at']) {
          final failure = await submitFailureFrom(
            submitRepository(
              (_) async => jsonResponse(submissionBody()..remove(field), 201),
            ),
          );

          expect(failure.kind, CourseLearningFailureKind.server, reason: field);
          expect(
            failure.detail,
            contains('assignment.submission.$field'),
            reason: field,
          );
        }
      });
    });
  });

  // §2.8: POST /me/files — one multipart part, `file`.
  group('uploadFile', () {
    /// The contract's §2.8 answer.
    Map<String, Object?> fileBody({
      Object? id = 77,
      Object? fileName = 'report.pdf',
      Object? contentType = 'application/pdf',
      Object? sizeBytes = 482133,
    }) => {
      'id': id,
      'file_name': fileName,
      'content_type': contentType,
      'size_bytes': sizeBytes,
    };

    /// Deliberately not UTF-8, with CR/LF inside, so the part's bytes can
    /// only match if they were sent exactly.
    const bytes = <int>[0x25, 0x50, 0x44, 0x46, 0x00, 0xFF, 0x0D, 0x0A, 0x80];

    Future<UploadedFile> upload(
      HttpCourseLearningRepository repository, {
      String fileName = 'report.pdf',
    }) => repository.uploadFile(fileName: fileName, bytes: bytes);

    Future<CourseLearningFailure> uploadFailureFrom(
      HttpCourseLearningRepository repository,
    ) async {
      try {
        await upload(repository);
      } on CourseLearningFailure catch (failure) {
        return failure;
      }
      fail('expected a CourseLearningFailure');
    }

    Future<CourseLearningFailure> failureForStatus(
      int status, [
      Object? body = const {},
    ]) => uploadFailureFrom(
      repositoryReturning((_) async => jsonResponse(body, status)),
    );

    group('the request', () {
      test('POSTs one multipart part, `file`, with the token', () async {
        late http.Request sent;
        final repository = repositoryReturning((request) async {
          sent = request;
          return jsonResponse(fileBody(), 201);
        });

        await upload(repository, fileName: 'Даалгавар 1.pdf');

        expect(sent.method, 'POST');
        expect(sent.url.toString(), 'https://api.ai-academy.asia/me/files');
        expect(sent.headers[HttpHeaders.authorizationHeader], 'Bearer tok-123');
        expect(sent.headers[HttpHeaders.acceptHeader], 'application/json');

        final parts = _multipartParts(sent);
        expect(parts, hasLength(1));
        final part = parts.single;
        expect(part.disposition, contains('form-data'));
        expect(part.disposition, contains('name="file"'));
        expect(part.filename, 'Даалгавар 1.pdf');
        expect(part.bytes, bytes);
      });

      test('the content type is multipart/form-data with a boundary', () async {
        late http.Request sent;
        final repository = repositoryReturning((request) async {
          sent = request;
          return jsonResponse(fileBody(), 201);
        });

        await upload(repository);

        expect(
          sent.headers[HttpHeaders.contentTypeHeader],
          startsWith('multipart/form-data; boundary='),
        );
      });

      test('signed out: sends nothing and asks for sign-in', () async {
        var requests = 0;
        final repository = repositoryReturning((_) async {
          requests++;
          return jsonResponse(fileBody(), 201);
        }, sessionStore: AuthSessionStore());

        final failure = await uploadFailureFrom(repository);

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
          return jsonResponse(fileBody(), 201);
        }, sessionStore: store);

        final failure = await uploadFailureFrom(repository);

        expect(failure.kind, CourseLearningFailureKind.sessionExpired);
        expect(requests, 0);
      });

      test('runs under uploadTimeout, not the JSON timeout', () async {
        HttpCourseLearningRepository slowServer({
          required Duration timeout,
          required Duration uploadTimeout,
        }) => HttpCourseLearningRepository(
          client: MockClient((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return jsonResponse(fileBody(), 201);
          }),
          sessionStore: signedIn(),
          timeout: timeout,
          uploadTimeout: uploadTimeout,
        );

        // A JSON budget the answer would miss does not apply to an upload…
        final file = await upload(
          slowServer(
            timeout: const Duration(milliseconds: 10),
            uploadTimeout: const Duration(seconds: 5),
          ),
        );
        expect(file.id, 77);

        // …and an upload budget it misses is a network failure.
        final failure = await uploadFailureFrom(
          slowServer(
            timeout: const Duration(seconds: 5),
            uploadTimeout: const Duration(milliseconds: 10),
          ),
        );
        expect(failure.kind, CourseLearningFailureKind.network);
      });

      test('the upload budget defaults to three minutes', () {
        expect(
          HttpCourseLearningRepository().uploadTimeout,
          const Duration(minutes: 3),
        );
        expect(
          HttpCourseLearningRepository().timeout,
          const Duration(seconds: 15),
        );
      });
    });

    group('the answer', () {
      test('201 reads the stored file in full', () async {
        final file = await upload(
          repositoryReturning((_) async => jsonResponse(fileBody(), 201)),
        );

        expect(file.id, 77);
        expect(file.fileName, 'report.pdf');
        expect(file.contentType, 'application/pdf');
        expect(file.sizeBytes, 482133);
      });
    });

    group('status mapping', () {
      test('400 unsupported_file_type is its own kind', () async {
        final failure = await failureForStatus(400, {
          'error': 'unsupported_file_type',
        });

        expect(failure.kind, CourseLearningFailureKind.unsupportedFileType);
      });

      test('413 file_too_large is its own kind', () async {
        final failure = await failureForStatus(413, {
          'error': 'file_too_large',
        });

        expect(failure.kind, CourseLearningFailureKind.fileTooLarge);
      });

      test('an undocumented 400 code is unexpected', () async {
        final failure = await failureForStatus(400, {'error': 'virus_found'});

        expect(failure.kind, CourseLearningFailureKind.unexpected);
      });

      test('a 413 without its code is unexpected, not guessed at', () async {
        for (final body in <Object?>[
          {'error': 'payload_too_large'},
          'Request Entity Too Large',
        ]) {
          final failure = await failureForStatus(413, body);

          expect(
            failure.kind,
            CourseLearningFailureKind.unexpected,
            reason: '$body',
          );
        }
      });

      test('401 is a dead session, and the token is forgotten', () async {
        final store = signedIn();
        final failure = await uploadFailureFrom(
          repositoryReturning(
            (_) async => jsonResponse({'error': 'token_expired'}, 401),
            sessionStore: store,
          ),
        );

        expect(failure.kind, CourseLearningFailureKind.sessionExpired);
        expect(store.isSignedIn, isFalse);
      });

      test('502 storage_error is a server fault', () async {
        final failure = await failureForStatus(502, {'error': 'storage_error'});

        expect(failure.kind, CourseLearningFailureKind.server);
      });

      test('503 storage_error is a server fault', () async {
        final failure = await failureForStatus(503, {'error': 'storage_error'});

        expect(failure.kind, CourseLearningFailureKind.server);
      });

      test('a request that never completes is a network failure', () async {
        final failure = await uploadFailureFrom(
          repositoryReturning((_) async => throw const SocketException('off')),
        );

        expect(failure.kind, CourseLearningFailureKind.network);
      });
    });

    group('a malformed 201 is a server fault', () {
      test('not JSON', () async {
        final failure = await uploadFailureFrom(
          repositoryReturning((_) async => http.Response('<html>', 201)),
        );

        expect(failure.kind, CourseLearningFailureKind.server);
      });

      test('not an object', () async {
        for (final body in <Object?>[null, [], 'ok']) {
          final failure = await uploadFailureFrom(
            repositoryReturning((_) async => jsonResponse(body, 201)),
          );

          expect(
            failure.kind,
            CourseLearningFailureKind.server,
            reason: '$body',
          );
        }
      });

      test('a missing or mistyped field', () async {
        final cases = <String, Map<String, Object?>>{
          'file.id': fileBody(id: null),
          'file.id ': fileBody(id: '77'),
          'file.file_name': fileBody(fileName: null),
          'file.content_type': fileBody(contentType: 42),
          'file.size_bytes': fileBody(sizeBytes: null),
          'file.size_bytes ': fileBody(sizeBytes: -1),
        };
        for (final MapEntry(key: field, value: body) in cases.entries) {
          final failure = await uploadFailureFrom(
            repositoryReturning((_) async => jsonResponse(body, 201)),
          );

          expect(failure.kind, CourseLearningFailureKind.server, reason: field);
          expect(failure.detail, contains(field.trim()), reason: field);
        }
      });
    });
  });

  group('quiz attempts (§2.7)', () {
    Map<String, Object?> attemptBody({Object? firstAnswer}) => {
      'attempt_id': 41,
      'quiz_id': 9,
      'status': 'in_progress',
      'started_at': '2026-08-06T03:00:00+00:00',
      'questions': [
        {
          'id': 101,
          'order': 1,
          'prompt': 'AI гэж юу вэ?',
          'image': null,
          'options': [
            {'id': 501, 'text': 'Хиймэл оюун'},
            {'id': 502, 'text': 'Тоглоом'},
          ],
          'answer': firstAnswer,
        },
        {
          'id': 102,
          'order': 2,
          'prompt': 'Machine Learning гэж юу вэ?',
          'image': null,
          'options': [
            {'id': 503, 'text': 'Өгөгдлөөс сурах'},
          ],
          'answer': null,
        },
      ],
    };

    Map<String, Object?> answerBody({Object? explanation = 'Учир нь…'}) => {
      'question_id': 101,
      'option_id': 502,
      'correct': false,
      'correct_option_id': 501,
      'explanation': explanation,
    };

    Map<String, Object?> resultBody() => {
      'attempt_id': 41,
      'correct': 1,
      'total': 2,
      'percent': 50,
      'passed': false,
      'started_at': '2026-08-06T03:00:00+00:00',
      'finished_at': '2026-08-06T03:05:00+00:00',
      'questions': [
        {'question_id': 101, 'order': 1, 'correct': true},
        {'question_id': 102, 'order': 2, 'correct': false},
      ],
    };

    Future<CourseLearningFailure> failureOf(
      Future<Object?> Function() call,
    ) async {
      try {
        await call();
      } on CourseLearningFailure catch (failure) {
        return failure;
      }
      fail('expected a CourseLearningFailure');
    }

    group('startQuizAttempt', () {
      test('POSTs to the quiz, with the token and no body', () async {
        late http.Request sent;
        final repository = repositoryReturning((request) async {
          sent = request;
          return jsonResponse(attemptBody(), 201);
        });

        await repository.startQuizAttempt(9);

        expect(sent.method, 'POST');
        expect(
          sent.url.toString(),
          'https://api.ai-academy.asia/me/quizzes/9/attempts',
        );
        expect(sent.headers[HttpHeaders.authorizationHeader], 'Bearer tok-123');
        expect(sent.body, isEmpty);
      });

      test('reads the attempt, its questions and options in order', () async {
        final attempt = await repositoryReturning(
          (_) async => jsonResponse(attemptBody(), 201),
        ).startQuizAttempt(9);

        expect(attempt.attemptId, 41);
        expect(attempt.questions.map((q) => q.id), [101, 102]);
        final first = attempt.questions.first;
        expect(first.prompt, 'AI гэж юу вэ?');
        expect(first.options.map((o) => (o.id, o.text)), [
          (501, 'Хиймэл оюун'),
          (502, 'Тоглоом'),
        ]);
        expect(first.answered, isFalse);
      });

      test('a resumed attempt (200) marks an answered question by its '
          'answer\'s presence alone', () async {
        final attempt = await repositoryReturning(
          (_) async => jsonResponse(
            attemptBody(firstAnswer: {'option_id': 502, 'correct': false}),
          ),
        ).startQuizAttempt(9);

        expect(attempt.questions[0].answered, isTrue);
        expect(attempt.questions[1].answered, isFalse);
      });

      test('409 no_attempts_left is its own kind', () async {
        final failure = await failureOf(
          () => repositoryReturning(
            (_) async => jsonResponse({'error': 'no_attempts_left'}, 409),
          ).startQuizAttempt(9),
        );

        expect(failure.kind, CourseLearningFailureKind.noAttemptsLeft);
      });

      test('404 quiz_not_found is notFound, 403 notEnrolled', () async {
        final notFound = await failureOf(
          () => repositoryReturning(
            (_) async => jsonResponse({'error': 'quiz_not_found'}, 404),
          ).startQuizAttempt(9),
        );
        final notEnrolled = await failureOf(
          () => repositoryReturning(
            (_) async => jsonResponse({'error': 'not_enrolled'}, 403),
          ).startQuizAttempt(9),
        );

        expect(notFound.kind, CourseLearningFailureKind.notFound);
        expect(notEnrolled.kind, CourseLearningFailureKind.notEnrolled);
      });

      test('a malformed attempt is a server fault', () async {
        for (final body in <Object?>[
          'attempt',
          {...attemptBody(), 'attempt_id': null},
          {...attemptBody(), 'questions': 'none'},
          {
            ...attemptBody(),
            'questions': [
              {'id': 101, 'prompt': 'Q', 'options': 'none'},
            ],
          },
          {
            ...attemptBody(),
            'questions': [
              {
                'id': 101,
                'prompt': 'Q',
                'options': [
                  {'id': 501},
                ],
              },
            ],
          },
        ]) {
          final failure = await failureOf(
            () => repositoryReturning(
              (_) async => jsonResponse(body, 201),
            ).startQuizAttempt(9),
          );

          expect(
            failure.kind,
            CourseLearningFailureKind.server,
            reason: '$body',
          );
        }
      });

      test('without a session, nothing is sent', () async {
        var sent = false;
        final failure = await failureOf(
          () => repositoryReturning((_) async {
            sent = true;
            return jsonResponse(attemptBody(), 201);
          }, sessionStore: AuthSessionStore()).startQuizAttempt(9),
        );

        expect(sent, isFalse);
        expect(failure.kind, CourseLearningFailureKind.sessionExpired);
      });
    });

    group('answerQuizQuestion', () {
      test('POSTs the question and option to the attempt, as JSON', () async {
        late http.Request sent;
        final repository = repositoryReturning((request) async {
          sent = request;
          return jsonResponse(answerBody());
        });

        await repository.answerQuizQuestion(41, questionId: 101, optionId: 502);

        expect(sent.method, 'POST');
        expect(
          sent.url.toString(),
          'https://api.ai-academy.asia/me/quiz-attempts/41/answers',
        );
        expect(sent.headers[HttpHeaders.authorizationHeader], 'Bearer tok-123');
        expect(jsonDecode(sent.body), {'question_id': 101, 'option_id': 502});
      });

      test(
        'reads the server\'s verdict, right option and explanation',
        () async {
          final answer = await repositoryReturning(
            (_) async => jsonResponse(answerBody()),
          ).answerQuizQuestion(41, questionId: 101, optionId: 502);

          expect(answer.questionId, 101);
          expect(answer.optionId, 502);
          expect(answer.correct, isFalse);
          expect(answer.correctOptionId, 501);
          expect(answer.explanation, 'Учир нь…');
        },
      );

      test('a missing explanation is no explanation, not a fault', () async {
        final answer = await repositoryReturning(
          (_) async => jsonResponse(answerBody(explanation: null)),
        ).answerQuizQuestion(41, questionId: 101, optionId: 502);

        expect(answer.explanation, isEmpty);
      });

      test(
        '409 already_answered and attempt_finished are their own kinds',
        () async {
          final expected = {
            'already_answered': CourseLearningFailureKind.alreadyAnswered,
            'attempt_finished': CourseLearningFailureKind.attemptFinished,
          };
          for (final MapEntry(key: code, value: kind) in expected.entries) {
            final failure = await failureOf(
              () => repositoryReturning(
                (_) async => jsonResponse({'error': code}, 409),
              ).answerQuizQuestion(41, questionId: 101, optionId: 502),
            );

            expect(failure.kind, kind, reason: code);
          }
        },
      );

      test('400 invalid_option is unexpected', () async {
        final failure = await failureOf(
          () => repositoryReturning(
            (_) async => jsonResponse({'error': 'invalid_option'}, 400),
          ).answerQuizQuestion(41, questionId: 101, optionId: 999),
        );

        expect(failure.kind, CourseLearningFailureKind.unexpected);
      });

      test('a malformed answer is a server fault', () async {
        for (final body in <Object?>[
          'answer',
          {...answerBody(), 'correct': 'no'},
          {...answerBody(), 'correct_option_id': null},
        ]) {
          final failure = await failureOf(
            () => repositoryReturning(
              (_) async => jsonResponse(body),
            ).answerQuizQuestion(41, questionId: 101, optionId: 502),
          );

          expect(
            failure.kind,
            CourseLearningFailureKind.server,
            reason: '$body',
          );
        }
      });
    });

    group('finishQuizAttempt', () {
      test('POSTs to the attempt\'s finish, with no body', () async {
        late http.Request sent;
        final repository = repositoryReturning((request) async {
          sent = request;
          return jsonResponse(resultBody());
        });

        await repository.finishQuizAttempt(41);

        expect(sent.method, 'POST');
        expect(
          sent.url.toString(),
          'https://api.ai-academy.asia/me/quiz-attempts/41/finish',
        );
        expect(sent.headers[HttpHeaders.authorizationHeader], 'Bearer tok-123');
        expect(sent.body, isEmpty);
      });

      test('reads the server-graded result as sent', () async {
        final result = await repositoryReturning(
          (_) async => jsonResponse(resultBody()),
        ).finishQuizAttempt(41);

        expect(result.attemptId, 41);
        expect(result.correct, 1);
        expect(result.total, 2);
        expect(result.percent, 50);
        expect(result.passed, isFalse);
        expect(
          result.questions.map((q) => (q.questionId, q.order, q.correct)),
          [(101, 1, true), (102, 2, false)],
        );
      });

      test('409 attempt_finished is its own kind', () async {
        final failure = await failureOf(
          () => repositoryReturning(
            (_) async => jsonResponse({'error': 'attempt_finished'}, 409),
          ).finishQuizAttempt(41),
        );

        expect(failure.kind, CourseLearningFailureKind.attemptFinished);
      });

      test('a malformed result is a server fault', () async {
        for (final body in <Object?>[
          'result',
          {...resultBody(), 'percent': null},
          {...resultBody(), 'questions': 'none'},
          {
            ...resultBody(),
            'questions': [
              {'question_id': 101, 'order': 1},
            ],
          },
        ]) {
          final failure = await failureOf(
            () => repositoryReturning(
              (_) async => jsonResponse(body),
            ).finishQuizAttempt(41),
          );

          expect(
            failure.kind,
            CourseLearningFailureKind.server,
            reason: '$body',
          );
        }
      });
    });

    group('getQuizAttempt', () {
      test('GETs the attempt and reads it as the finish answer', () async {
        late http.Request sent;
        final result = await repositoryReturning((request) async {
          sent = request;
          return jsonResponse(resultBody());
        }).getQuizAttempt(41);

        expect(sent.method, 'GET');
        expect(
          sent.url.toString(),
          'https://api.ai-academy.asia/me/quiz-attempts/41',
        );
        expect(sent.headers[HttpHeaders.authorizationHeader], 'Bearer tok-123');
        expect(result.percent, 50);
      });

      test('404 attempt_not_found is notFound', () async {
        final failure = await failureOf(
          () => repositoryReturning(
            (_) async => jsonResponse({'error': 'attempt_not_found'}, 404),
          ).getQuizAttempt(41),
        );

        expect(failure.kind, CourseLearningFailureKind.notFound);
      });
    });
  });
}

/// Sentinel for `feedbackBody(mentor: ...)`: "the caller did not pass one"
/// (use the contract's mentor) versus an explicit `null` (a fault).
const Object _defaultMentor = Object();

/// One part of a `multipart/form-data` body, as the server would read it.
typedef _Part = ({String disposition, String? filename, List<int> bytes});

/// Splits [request]'s body on its boundary — read from the content type the
/// client actually sent — into its parts. Decoded as latin1, which maps every
/// byte to one character and back, so a part's bytes compare exactly.
List<_Part> _multipartParts(http.Request request) {
  final contentType = request.headers[HttpHeaders.contentTypeHeader]!;
  final boundary = RegExp(r'boundary=(.+)$').firstMatch(contentType)!.group(1)!;
  final body = latin1.decode(request.bodyBytes);

  final parts = <_Part>[];
  for (final chunk in body.split('--$boundary')) {
    // The preamble before the first boundary, and the closing `--`.
    if (chunk.isEmpty || chunk.startsWith('--')) continue;
    final split = chunk.indexOf('\r\n\r\n');
    final head = chunk.substring(0, split);
    // Each part ends with the CRLF that precedes the next boundary.
    final content = chunk.substring(split + 4, chunk.length - 2);
    final disposition = head
        .split('\r\n')
        .firstWhere(
          (line) => line.toLowerCase().startsWith('content-disposition'),
        );
    // The filename header is UTF-8 on the wire; re-read it as such.
    final rawName = RegExp(
      r'filename="([^"]*)"',
    ).firstMatch(disposition)?.group(1);
    parts.add((
      disposition: disposition,
      filename: rawName == null ? null : utf8.decode(latin1.encode(rawName)),
      bytes: latin1.encode(content),
    ));
  }
  return parts;
}
