import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/course_learning/data/http_course_learning_repository.dart';
import 'package:aia_mobile/features/course_learning/domain/course_certificate.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// §2.9's two student certificate endpoints (Issue #155), against the
/// contract's shapes — `status` with `certificate {cert_number, issued_at}`,
/// and a pre-signed `{url, expires_at}` — through this repository's existing
/// `MockClient` pattern. No live backend is called.
void main() {
  AuthSessionStore signedIn() =>
      AuthSessionStore()..save(const AuthSession(accessToken: 'tok-123'));

  final requests = <http.Request>[];

  HttpCourseLearningRepository repositoryReturning(
    Object? body, [
    int status = 200,
  ]) {
    requests.clear();
    return HttpCourseLearningRepository(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response.bytes(
          utf8.encode(jsonEncode(body)),
          status,
          headers: {
            HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
          },
        );
      }),
      sessionStore: signedIn(),
    );
  }

  Future<CourseLearningFailure> failureOf(Future<Object?> call) async {
    try {
      await call;
    } on CourseLearningFailure catch (failure) {
      return failure;
    }
    fail('expected a CourseLearningFailure');
  }

  group('getCourseCertificate', () {
    test('asks for the course\'s certificate, authenticated', () async {
      final repository = repositoryReturning({'status': 'not_eligible'});

      await repository.getCourseCertificate('summer-bootcamp-2027');

      expect(requests.single.method, 'GET');
      expect(
        requests.single.url.toString(),
        'https://api.ai-academy.asia/me/courses/summer-bootcamp-2027/certificate',
      );
      expect(requests.single.headers['Authorization'], 'Bearer tok-123');
    });

    test('reads an issued certificate\'s number and date', () async {
      final certificate = await repositoryReturning({
        'status': 'issued',
        'requirements': [],
        'certificate': {
          'cert_number': 'AIAA-2026-0042',
          'issued_at': '2026-07-21T03:00:00+00:00',
          'verify_url': 'https://example.test/verify/AIAA-2026-0042',
        },
      }).getCourseCertificate('summer-bootcamp-2027');

      expect(certificate.status, CertificateStatus.issued);
      expect(certificate.isIssued, isTrue);
      expect(certificate.issued?.certNumber, 'AIAA-2026-0042');
      expect(certificate.issued?.issuedAt, DateTime.utc(2026, 7, 21, 3));
    });

    test('maps the contract\'s three statuses, and nothing else to issued', () {
      expect(
        CertificateStatus.fromApi('not_eligible'),
        CertificateStatus.notEligible,
      );
      expect(CertificateStatus.fromApi('eligible'), CertificateStatus.eligible);
      expect(CertificateStatus.fromApi('issued'), CertificateStatus.issued);
      for (final other in ['revoked', 'ISSUED', '', null, 3]) {
        expect(
          CertificateStatus.fromApi(other),
          CertificateStatus.unknown,
          reason: '$other',
        );
      }
    });

    test('a status without a certificate object has nothing issued', () async {
      final certificate = await repositoryReturning({
        'status': 'eligible',
        'requirements': [
          {'key': 'lessons', 'met': true},
        ],
        'certificate': null,
      }).getCourseCertificate('summer-bootcamp-2027');

      expect(certificate.status, CertificateStatus.eligible);
      expect(certificate.issued, isNull);
    });

    test('an unreadable issued_at keeps the number, without a date', () async {
      final certificate = await repositoryReturning({
        'status': 'issued',
        'certificate': {'cert_number': 'AIAA-1', 'issued_at': 'soon'},
      }).getCourseCertificate('summer-bootcamp-2027');

      expect(certificate.issued?.certNumber, 'AIAA-1');
      expect(certificate.issued?.issuedAt, isNull);
    });

    test('a body without a status is the server\'s fault', () async {
      final failure = await failureOf(
        repositoryReturning({
          'certificate': null,
        }).getCourseCertificate('summer-bootcamp-2027'),
      );

      expect(failure.kind, CourseLearningFailureKind.server);
    });

    test('statuses map as every course-learning read does', () async {
      for (final (status, kind) in [
        (401, CourseLearningFailureKind.sessionExpired),
        (404, CourseLearningFailureKind.notFound),
        (500, CourseLearningFailureKind.server),
      ]) {
        final failure = await failureOf(
          repositoryReturning(
            const {},
            status,
          ).getCourseCertificate('summer-bootcamp-2027'),
        );
        expect(failure.kind, kind, reason: '$status');
      }
    });
  });

  group('getCertificateDownload', () {
    test('asks for the certificate\'s link and reads it', () async {
      final repository = repositoryReturning({
        'url': 'https://s3.example.test/certs/AIAA-1.pdf?X-Amz-Signature=x',
        'expires_at': '2026-08-06T01:05:00+00:00',
      });

      final download = await repository.getCertificateDownload('AIAA-1');

      expect(
        requests.single.url.toString(),
        'https://api.ai-academy.asia/me/certificates/AIAA-1/download',
      );
      expect(requests.single.headers['Authorization'], 'Bearer tok-123');
      expect(
        download.url,
        Uri.parse('https://s3.example.test/certs/AIAA-1.pdf?X-Amz-Signature=x'),
      );
      expect(download.expiresAt, DateTime.utc(2026, 8, 6, 1, 5));
    });

    test(
      'a missing or non-http url, or no expiry, is the server\'s fault',
      () async {
        for (final body in [
          {'expires_at': '2026-08-06T01:05:00+00:00'},
          {'url': 'file:///etc/passwd', 'expires_at': '2026-08-06T01:05:00Z'},
          {'url': 'https://s3.example.test/x.pdf'},
          {'url': 'https://s3.example.test/x.pdf', 'expires_at': 'soon'},
        ]) {
          final failure = await failureOf(
            repositoryReturning(body).getCertificateDownload('AIAA-1'),
          );
          expect(
            failure.kind,
            CourseLearningFailureKind.server,
            reason: '$body',
          );
        }
      },
    );

    test('a 404 is not found', () async {
      final failure = await failureOf(
        repositoryReturning(const {}, 404).getCertificateDownload('AIAA-1'),
      );

      expect(failure.kind, CourseLearningFailureKind.notFound);
    });
  });
}
