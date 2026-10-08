/// Where the student stands on one course's certificate — §2.9
/// `GET /me/courses/{course_slug}/certificate` (Issue #155).
///
/// Only what the app draws is read: the `status`, and for an issued
/// certificate its `cert_number` (the download key) and `issued_at` (the
/// "Completed date"). The response's `requirements` list and `verify_url`
/// are left unread — no design draws them — and eligibility is never
/// computed here: the status is the server's (§4.2, still subject to
/// product sign-off).
class CourseCertificate {
  const CourseCertificate({required this.status, this.issued});

  final CertificateStatus status;

  /// The issued certificate, when the response carries one — only ever for
  /// [CertificateStatus.issued].
  final IssuedCertificate? issued;

  bool get isIssued => status == CertificateStatus.issued;
}

/// The contract's three `status` values, and [unknown] for anything else —
/// a value this build does not know is never read as issued.
enum CertificateStatus {
  notEligible,
  eligible,
  issued,
  unknown;

  static CertificateStatus fromApi(Object? value) => switch (value) {
    'not_eligible' => notEligible,
    'eligible' => eligible,
    'issued' => issued,
    _ => unknown,
  };
}

/// An issued certificate's `certificate` object.
class IssuedCertificate {
  const IssuedCertificate({required this.certNumber, this.issuedAt});

  /// The key `GET /me/certificates/{cert_number}/download` takes.
  final String certNumber;

  /// When it was issued. Null when the response carried no readable
  /// timestamp.
  final DateTime? issuedAt;
}

/// §2.9 `GET /me/certificates/{cert_number}/download` — a pre-signed link to
/// the certificate's file. Fetched fresh on every tap, never cached: it
/// expires.
class CertificateDownload {
  const CertificateDownload({required this.url, required this.expiresAt});

  final Uri url;
  final DateTime expiresAt;
}
