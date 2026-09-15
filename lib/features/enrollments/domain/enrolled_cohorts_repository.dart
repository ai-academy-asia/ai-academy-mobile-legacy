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
}
