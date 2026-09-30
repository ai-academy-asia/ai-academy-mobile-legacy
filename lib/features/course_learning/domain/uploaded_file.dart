/// A file the student has uploaded — `course_learning_api_contract_v1.md`
/// §2.8's answer to `POST /me/files`.
///
/// Stored privately by the backend and unattached until a submission sends
/// its [id] as `file_id`; one nobody attaches is deleted after 24 hours.
class UploadedFile {
  const UploadedFile({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
  });

  /// What a submission sends as `file_id`.
  final int id;

  /// The name the file was uploaded under, e.g. `report.pdf`.
  final String fileName;

  /// As the server recorded it, e.g. `application/pdf`.
  final String contentType;

  final int sizeBytes;
}
