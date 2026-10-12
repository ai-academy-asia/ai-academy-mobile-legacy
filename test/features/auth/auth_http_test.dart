import 'dart:io';

import 'package:aia_mobile/core/api/transport_log.dart';
import 'package:aia_mobile/features/auth/data/auth_http.dart';
import 'package:aia_mobile/features/auth/domain/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The auth transport's handling of requests that never complete (Issue
/// #339) — the same rule as `api_client.dart`'s, with the sign-in body's
/// credentials in play. `MockClient` stands in for the network.
void main() {
  final url = Uri.parse('https://api.example.test/auth/login?next=secret');
  const body = {'email': 'student@example.test', 'password': 'hunter2-secret'};
  const timeout = Duration(seconds: 1);

  late List<String> logged;
  setUp(() {
    logged = [];
    debugTransportFailureSink = logged.add;
  });
  tearDown(() => debugTransportFailureSink = null);

  Future<AuthFailure> failureFrom(Object error) async {
    try {
      await postJson(
        client: MockClient((_) async => throw error),
        url: url,
        body: body,
        timeout: timeout,
        headers: const {'Authorization': 'Bearer secret-token-123'},
      );
    } on AuthFailure catch (failure) {
      return failure;
    }
    fail('expected an AuthFailure');
  }

  test('a HandshakeException is a network failure', () async {
    final failure = await failureFrom(
      const HandshakeException('Handshake error in client'),
    );
    expect(failure.kind, AuthFailureKind.network);
  });

  test('a TlsException is a network failure', () async {
    final failure = await failureFrom(const TlsException('bad record'));
    expect(failure.kind, AuthFailureKind.network);
  });

  test('socket, client and timeout failures are unchanged', () async {
    expect(
      (await failureFrom(const SocketException('no route'))).kind,
      AuthFailureKind.network,
    );
    expect(
      (await failureFrom(http.ClientException('closed'))).kind,
      AuthFailureKind.network,
    );

    AuthFailure? timedOut;
    try {
      await postJson(
        client: MockClient(
          (_) => Future.delayed(
            const Duration(milliseconds: 200),
            () => http.Response('{}', 200),
          ),
        ),
        url: url,
        body: body,
        timeout: const Duration(milliseconds: 10),
      );
    } on AuthFailure catch (f) {
      timedOut = f;
    }
    expect(timedOut?.kind, AuthFailureKind.network);
    expect(timedOut?.detail, 'request timed out');
  });

  test('a refused sign-in is still invalid credentials, not logged', () async {
    AuthFailure? failure;
    try {
      await postJson(
        client: MockClient((_) async => http.Response('{}', 401)),
        url: url,
        body: body,
        timeout: timeout,
      );
    } on AuthFailure catch (f) {
      failure = f;
    }
    expect(failure?.kind, AuthFailureKind.invalidCredentials);
    expect(logged, isEmpty);
  });

  test('logs only the transport, kind and exception type — never the '
      'credentials, token, URL or exception message', () async {
    await failureFrom(
      http.ClientException(
        'POST $url failed with hunter2-secret student@example.test',
        url,
      ),
    );
    await failureFrom(const HandshakeException('Handshake error in client'));

    expect(logged, [
      'auth: network (ClientException)',
      'auth: network (HandshakeException)',
    ]);
    for (final line in logged) {
      for (final secret in [
        'hunter2-secret',
        'student@example.test',
        'secret-token-123',
        'secret',
        'api.example.test',
        '/auth/login',
        'Handshake error',
      ]) {
        expect(line, isNot(contains(secret)), reason: line);
      }
    }
  });
}
