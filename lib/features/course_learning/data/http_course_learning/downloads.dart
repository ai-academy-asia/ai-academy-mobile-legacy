part of '../http_course_learning_repository.dart';

/// §2.3's mark-complete answer: `completed` and `progress.percent`, read as
/// strictly as the learning path reads the same progress object.
LessonCompletion _completionFromBody(String body) {
  final decoded = _decodeObject(body);
  return LessonCompletion(
    completed: _requireBool(decoded, 'completion.completed'),
    percentComplete: _requirePercent(_requireObject(decoded, 'progress')),
  );
}

/// §2.4's download answer — `{"url", "expires_at", "file_name",
/// "size_bytes"}` — read in full.
///
/// `url` must be an absolute `http(s)` URL: it is handed straight to the OS
/// to open, so anything else is a server fault rather than something to try.
MaterialDownload _downloadFromBody(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (e) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'malformed JSON: ${e.message}',
    );
  }

  if (decoded is! Map<String, dynamic>) {
    throw const CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'response was not a JSON object',
    );
  }

  final url = _requireHttpUrl(decoded, 'download.url');

  final rawExpiresAt = _requireString(decoded, 'download.expires_at');
  final expiresAt = DateTime.tryParse(rawExpiresAt);
  if (expiresAt == null) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'download.expires_at: not a timestamp ("$rawExpiresAt")',
    );
  }

  final sizeBytes = _requireInt(decoded, 'download.size_bytes');
  if (sizeBytes < 0) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'download.size_bytes: expected 0 or more, got $sizeBytes',
    );
  }

  return MaterialDownload(
    url: url,
    expiresAt: expiresAt,
    fileName: _requireString(decoded, 'download.file_name'),
    sizeBytes: sizeBytes,
  );
}

/// §2.9's certificate response: `status` (required), and the issued
/// `certificate` object's `cert_number` and `issued_at` when it is present.
/// `has_file` is read inside `certificate` first, then at the top level — its
/// place is not documented (Issue #296); anything but a boolean is unknown.
///
/// A status this build does not know reads as [CertificateStatus.unknown],
/// never as issued. An issued status without a readable `certificate`
/// object keeps [CourseCertificate.issued] null — the screen then has no
/// number to download with. `requirements` and `verify_url` are not read.
CourseCertificate _certificateFromBody(String body) {
  final decoded = _decodeObject(body);
  final status = decoded['status'];
  if (status is! String || status.isEmpty) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail:
          'certificate.status: expected a non-empty string, '
          'got ${status.runtimeType}',
    );
  }

  final certificate = decoded['certificate'];
  IssuedCertificate? issued;
  bool? hasFile;
  if (certificate is Map<String, dynamic>) {
    if (certificate['has_file'] case final bool value) hasFile = value;
    final certNumber = certificate['cert_number'];
    final issuedAt = certificate['issued_at'];
    if (certNumber is String && certNumber.isNotEmpty) {
      issued = IssuedCertificate(
        certNumber: certNumber,
        issuedAt: issuedAt is String ? DateTime.tryParse(issuedAt) : null,
      );
    }
  }

  if (decoded['has_file'] case final bool value) hasFile ??= value;

  return CourseCertificate(
    status: CertificateStatus.fromApi(status),
    issued: issued,
    hasFile: hasFile,
  );
}
