import 'dart:io';

import 'package:aia_mobile/core/api/api_client.dart';
import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/core/api/transport_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The shared transport's handling of requests that never complete (Issue
/// #339): TLS failures are network failures like a socket or client error,
/// and every such failure is logged in debug builds — its kind and exception
/// type only. `MockClient` stands in for the network; nothing is sent.
void main() {
  /// A URL carrying what must never reach a log: a host, a path id and a
  /// query token.
  final url = Uri.parse(
    'https://api.example.test/me/lessons/42?token=secret-token-123',
  );
  const timeout = Duration(seconds: 1);

  late List<String> logged;
  setUp(() {
    logged = [];
    debugTransportFailureSink = logged.add;
  });
  tearDown(() => debugTransportFailureSink = null);

  Future<ApiFailure> failureFrom(Object error) async {
    try {
      await getJson(
        client: MockClient((_) async => throw error),
        url: url,
        timeout: timeout,
        headers: const {'Authorization': 'Bearer secret-token-123'},
      );
    } on ApiFailure catch (failure) {
      return failure;
    }
    fail('expected an ApiFailure');
  }

  group('TLS failures are network failures', () {
    test('HandshakeException', () async {
      final failure = await failureFrom(
        const HandshakeException('Handshake error in client'),
      );
      expect(failure.kind, ApiFailureKind.network);
      expect(failure.detail, 'Handshake error in client');
    });

    test('TlsException', () async {
      final failure = await failureFrom(const TlsException('bad record'));
      expect(failure.kind, ApiFailureKind.network);
    });
  });

  group('the other never-completed requests are unchanged', () {
    test('SocketException', () async {
      final failure = await failureFrom(const SocketException('no route'));
      expect(failure.kind, ApiFailureKind.network);
      expect(failure.detail, 'no route');
    });

    test('ClientException', () async {
      final failure = await failureFrom(http.ClientException('closed'));
      expect(failure.kind, ApiFailureKind.network);
      expect(failure.detail, 'closed');
    });

    test('a timeout', () async {
      ApiFailure? failure;
      try {
        await getJson(
          client: MockClient(
            (_) => Future.delayed(
              const Duration(milliseconds: 200),
              () => http.Response('{}', 200),
            ),
          ),
          url: url,
          timeout: const Duration(milliseconds: 10),
        );
      } on ApiFailure catch (f) {
        failure = f;
      }
      expect(failure?.kind, ApiFailureKind.network);
      expect(failure?.detail, 'request timed out');
      expect(logged, ['api: network (TimeoutException)']);
    });

    test(
      'status codes still map as before, and are not transport failures',
      () async {
        ApiFailure? failure;
        try {
          await getJson(
            client: MockClient((_) async => http.Response('boom', 503)),
            url: url,
            timeout: timeout,
          );
        } on ApiFailure catch (f) {
          failure = f;
        }
        expect(failure?.kind, ApiFailureKind.server);
        expect(logged, isEmpty);
      },
    );
  });

  group('debug logging', () {
    test('logs the transport, the kind and the exception type', () async {
      await failureFrom(const HandshakeException('Handshake error in client'));
      await failureFrom(const SocketException('no route'));
      expect(logged, [
        'api: network (HandshakeException)',
        'api: network (SocketException)',
      ]);
    });

    test('never logs the message, URL, query, header or token — even when '
        'the exception carries them', () async {
      await failureFrom(
        http.ClientException('GET $url failed: Bearer secret-token-123', url),
      );
      await failureFrom(
        HandshakeException(
          'CERTIFICATE_VERIFY_FAILED for api.example.test',
          const OSError('subject=CN=api.example.test', 1),
        ),
      );
      expect(logged, hasLength(2));
      for (final line in logged) {
        for (final secret in [
          'secret-token-123',
          'token=',
          'Bearer',
          'api.example.test',
          '/me/lessons',
          '42',
          'CERTIFICATE',
          'subject',
        ]) {
          expect(line, isNot(contains(secret)), reason: line);
        }
      }
    });

    test('a successful request logs nothing', () async {
      await getJson(
        client: MockClient((_) async => http.Response('{}', 200)),
        url: url,
        timeout: timeout,
      );
      expect(logged, isEmpty);
    });
  });
}
