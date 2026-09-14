import 'enrollment.dart';

/// Enrolls the signed-in student in a cohort.
///
/// Authenticated, unlike `CohortRepository`: the request names no student, so
/// the bearer token is what says who is enrolling. A screen depends on this
/// interface rather than the HTTP class directly, so tests can drive it by
/// hand and the transport can change without the screen being rewritten.
abstract interface class EnrollmentRepository {
  /// Enrolls the signed-in student in cohort [cohortId] and returns the
  /// enrollment the API created.
  ///
  /// Throws `EnrollmentFailure` when there is no usable session, the API
  /// refuses or cannot be reached, or the response does not match the
  /// confirmed shape.
  Future<Enrollment> enroll(int cohortId);
}
