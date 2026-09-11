import 'cohort.dart';

/// The public cohort list.
///
/// `GET /cohorts` is not documented as requiring auth in the confirmed
/// contract; modelled as public, consistent with `CourseRepository`'s
/// `getCourses` and using the same unauthenticated transport. A screen
/// depends on this interface rather than the HTTP class directly, so the
/// transport can change without the screen being rewritten.
abstract interface class CohortRepository {
  /// Every cohort currently scheduled, across every course.
  ///
  /// Throws `ApiFailure` when the list cannot be fetched or the response does
  /// not match the confirmed shape.
  Future<List<Cohort>> getCohorts();
}
