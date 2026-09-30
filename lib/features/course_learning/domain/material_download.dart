/// Where one lesson material can be fetched from, right now —
/// `course_learning_api_contract_v1.md` §2.4's answer to
/// `GET /me/materials/{material_id}/download`.
///
/// [url] is a pre-signed S3 GET: it needs no `Authorization` header and is
/// valid for five minutes, until [expiresAt]. It is asked for at the moment
/// of use rather than held on to — a new one is requested for every
/// download.
class MaterialDownload {
  const MaterialDownload({
    required this.url,
    required this.expiresAt,
    required this.fileName,
    required this.sizeBytes,
  });

  final Uri url;
  final DateTime expiresAt;

  /// The stored file's own name, e.g. `week2-slides.pdf`.
  final String fileName;

  final int sizeBytes;
}
