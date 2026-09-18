/// One entry of `GET /me/cohorts`.
class EnrolledCohortSummary {
  const EnrolledCohortSummary({required this.cohortId, this.progressPct});

  final int cohortId;

  /// Same meaning as `Enrollment.progressPct` — the one progress figure this
  /// API confirms — read from this entry when it carries one. The envelope
  /// this endpoint sends beyond `id` is not confirmed, so this is null
  /// whenever an entry does not carry the field, rather than assumed.
  final double? progressPct;
}

/// The signed-in student's own enrolled cohorts.
///
/// Kept apart from `EnrollmentRepository`: that one creates an enrollment,
/// this one reads what already exists — different endpoints, and a screen may
/// need one without the other.
abstract interface class EnrolledCohortsRepository {
  /// Cohort ids the signed-in student is already enrolled in.
  ///
  /// Throws `EnrollmentFailure` when there is no usable session, the API
  /// refuses or cannot be reached, or the response does not match the
  /// modeled shape.
  Future<Set<int>> getEnrolledCohortIds();

  /// The same enrolled cohorts, each with the progress percentage its own
  /// entry carries, when it carries one.
  ///
  /// The same request [getEnrolledCohortIds] makes, read more fully rather
  /// than a second endpoint — see [EnrolledCohortSummary]. Throws on the same
  /// terms.
  Future<List<EnrolledCohortSummary>> getEnrolledCohorts();
}
