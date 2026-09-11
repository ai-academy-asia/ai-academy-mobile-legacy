import 'course.dart';

/// The public course catalog.
///
/// No authentication: `GET /courses` is confirmed to need none, so — unlike
/// the auth repositories — nothing implementing this reads a session or a
/// token. A screen depends on this interface rather than on the HTTP class
/// directly, so the transport can change without the screen being rewritten.
abstract interface class CourseRepository {
  /// Every course the catalog currently lists.
  ///
  /// Throws `ApiFailure` when the list cannot be fetched or the response does
  /// not match the confirmed shape.
  Future<List<Course>> getCourses();
}
