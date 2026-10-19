import 'cohort_listing.dart';

/// The public cohort list.
///
/// `GET /cohorts` is not documented as requiring auth in the confirmed
/// contract; modelled as public, consistent with `CourseRepository`'s
/// `getCourses` and using the same unauthenticated transport. A screen
/// depends on this interface rather than the HTTP class directly, so the
/// transport can change without the screen being rewritten.
abstract interface class CohortRepository {
  /// Every cohort currently scheduled, across every course, read row by row:
  /// a row that does not match the `Cohort` contract is skipped and reported
  /// in [CohortListing.skipped] rather than failing the list (Issue #445).
  ///
  /// Throws `ApiFailure` when the list cannot be fetched or the envelope does
  /// not match the confirmed shape (not JSON, not an object, no `cohorts`
  /// list).
  Future<CohortListing> getCohorts();
}
