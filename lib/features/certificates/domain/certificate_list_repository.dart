import 'certificate_entry.dart';

/// The signed-in student's certificates, one per enrolled cohort.
abstract interface class CertificateListRepository {
  /// Throws `CourseLearningFailure` when the list cannot be built.
  Future<List<CertificateEntry>> getCertificates();
}
