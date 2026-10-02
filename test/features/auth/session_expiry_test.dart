import 'dart:convert';

import 'package:aia_mobile/features/attendance/data/http_attendance_repository.dart';
import 'package:aia_mobile/features/auth/data/authenticated_client.dart';
import 'package:aia_mobile/features/auth/data/http_password_repository.dart';
import 'package:aia_mobile/features/auth/data/session_refresher.dart';
import 'package:aia_mobile/features/auth/domain/auth_failure.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/presentation/sign_out.dart';
import 'package:aia_mobile/features/course_learning/data/http_course_learning_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_auth_repository.dart';

/// Session expiry end to end (Issue #176): a session that cannot be renewed
/// returns to Login once, and the real Adult and Junior repositories recover
/// through the shared client when it can.
void main() {
  late AuthSessionStore store;
  late FakeAuthRepository auth;
  late SessionRefresher refresher;

  setUp(() {
    store = AuthSessionStore()
      ..save(const AuthSession(accessToken: 'old', refreshToken: 'r1'));
    auth = FakeAuthRepository()
      ..refreshed = const AuthSession(accessToken: 'new', refreshToken: 'r2');
    refresher = SessionRefresher(sessionStore: store, authRepository: auth);
  });

  /// A server that refuses the `old` token as expired and answers [body] to
  /// anything else.
  AuthenticatedClient serverAnswering(Object body, {List<String?>? sent}) =>
      AuthenticatedClient(
        sessionStore: store,
        refresher: refresher,
        inner: MockClient((request) async {
          final token = request.headers['Authorization'];
          sent?.add(token);
          if (token == 'Bearer old') {
            return http.Response('{"error":"token_expired"}', 401);
          }
          return http.Response.bytes(
            utf8.encode(jsonEncode(body)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

  group('returning to Login', () {
    late GlobalKey<NavigatorState> navigatorKey;
    late int loginPushes;

    Future<void> pumpProtectedScreen(WidgetTester tester) async {
      navigatorKey = GlobalKey<NavigatorState>();
      loginPushes = 0;
      returnToLoginWhenSessionEnds(refresher, navigatorKey);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          routes: {
            '/': (_) => const Scaffold(body: Text('home')),
            loginRoute: (_) {
              loginPushes++;
              return const Scaffold(body: Text('login'));
            },
          },
        ),
      );
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('attendance')),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a failed renewal lands on Login, with nothing to go back to', (
      tester,
    ) async {
      auth.refreshed = null;
      await pumpProtectedScreen(tester);

      await tester.runAsync(
        () => serverAnswering(const {}).get(
          Uri.parse('https://api.ai-academy.asia/me/cohorts'),
          headers: store.authorizationHeader,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('login'), findsOneWidget);
      expect(find.text('attendance'), findsNothing);
      expect(navigatorKey.currentState!.canPop(), isFalse);
      expect(store.isSignedIn, isFalse);
    });

    testWidgets('several requests failing together push Login once', (
      tester,
    ) async {
      auth.refreshed = null;
      await pumpProtectedScreen(tester);
      final client = serverAnswering(const {});
      final url = Uri.parse('https://api.ai-academy.asia/me/cohorts');

      await tester.runAsync(
        () => Future.wait([
          client.get(url, headers: store.authorizationHeader),
          client.get(url, headers: store.authorizationHeader),
          client.get(url, headers: store.authorizationHeader),
        ]),
      );
      await tester.pumpAndSettle();

      expect(auth.refreshCalls, ['r1']);
      expect(loginPushes, 1);
      expect(find.text('login'), findsOneWidget);
    });

    testWidgets('a successful renewal stays where it is', (tester) async {
      await pumpProtectedScreen(tester);

      final response = await tester.runAsync(
        () => serverAnswering(const {'ok': true}).get(
          Uri.parse('https://api.ai-academy.asia/me/cohorts'),
          headers: store.authorizationHeader,
        ),
      );
      await tester.pumpAndSettle();

      expect(response!.statusCode, 200);
      expect(find.text('attendance'), findsOneWidget);
      expect(find.text('login'), findsNothing);
      expect(loginPushes, 0);
    });
  });

  group('the real repositories, through the shared client', () {
    test('Adult: attendance recovers from an expired token', () async {
      final sent = <String?>[];
      final repository = HttpAttendanceRepository(
        client: serverAnswering({
          'cohort_id': 3,
          'course_id': 9,
          'sessions': [],
          'summary': {'attended': 8, 'percent': 88, 'total_past': 9},
        }, sent: sent),
        sessionStore: store,
      );

      final attendance = await repository.getCourseAttendance('ai-x');

      expect(attendance.attended, 8);
      expect(sent, ['Bearer old', 'Bearer new']);
      expect(store.accessToken, 'new');
    });

    test(
      'Junior: the learning map\'s call recovers from an expired token',
      () async {
        final sent = <String?>[];
        final repository = HttpCourseLearningRepository(
          client: serverAnswering({
            'course': {
              'id': 6,
              'slug': 'junior-ai',
              'title': {'mn': 'AI BootCamp', 'en': 'AI BootCamp'},
              'description': {'mn': '', 'en': ''},
            },
            'enrollment_id': 1,
            'cohort_id': 7,
            'progress': {
              'percent': 40,
              'completed_lessons': 2,
              'total_lessons': 5,
            },
            'continue': null,
            'certificate': {'status': 'not_eligible'},
            'modules': [],
          }, sent: sent),
          sessionStore: store,
        );

        final path = await repository.getCourseLearning('junior-ai');

        expect(path.percentComplete, 40);
        expect(sent, ['Bearer old', 'Bearer new']);
      },
    );

    test('a locally expired session is renewed, not refused', () async {
      store.save(
        const AuthSession(
          accessToken: 'old',
          refreshToken: 'r1',
          expiresIn: Duration(hours: 1),
        ),
        now: DateTime.now().subtract(const Duration(hours: 2)),
      );
      final sent = <String?>[];
      final repository = HttpAttendanceRepository(
        client: serverAnswering({
          'cohort_id': 3,
          'course_id': 9,
          'sessions': [],
          'summary': {'attended': 1, 'percent': 10, 'total_past': 10},
        }, sent: sent),
        sessionStore: store,
      );

      await repository.getCourseAttendance('ai-x');

      // Renewed before sending: the stale token never went out.
      expect(sent, ['Bearer new']);
    });

    test('a wrong current password is still a wrong password', () async {
      final client = AuthenticatedClient(
        sessionStore: store,
        refresher: refresher,
        inner: MockClient(
          (_) async => http.Response('{"error":"invalid_credentials"}', 401),
        ),
      );
      final repository = HttpPasswordRepository(
        client: client,
        sessionStore: store,
      );

      await expectLater(
        repository.changePassword(currentPassword: 'x', newPassword: 'y'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.kind,
            'kind',
            AuthFailureKind.invalidCredentials,
          ),
        ),
      );
      expect(auth.refreshCalls, isEmpty);
      expect(store.accessToken, 'old');
    });
  });

  testWidgets('explicit sign-out still works, and revokes the rotated token', (
    tester,
  ) async {
    // A renewal rotates r1 to r2 ...
    await tester.runAsync(
      () => serverAnswering(const {}).get(
        Uri.parse('https://api.ai-academy.asia/me/cohorts'),
        headers: store.authorizationHeader,
      ),
    );
    expect(store.session?.refreshToken, 'r2');

    // ... and "Гарах" then revokes r2, clears the session and lands on Login.
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        routes: {
          '/': (_) => const Scaffold(body: Text('profile')),
          loginRoute: (_) => const Scaffold(body: Text('login')),
        },
      ),
    );
    await signOutToLogin(
      navigatorKey.currentState!,
      repository: auth,
      sessionStore: store,
    );
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, ['r2']);
    expect(store.isSignedIn, isFalse);
    expect(find.text('login'), findsOneWidget);
  });
}
