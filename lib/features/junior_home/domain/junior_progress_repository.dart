import 'junior_progress.dart';

abstract interface class JuniorProgressRepository {
  /// The signed-in junior student's learning progress.
  ///
  /// Null when the student is enrolled in nothing — not a failure. Throws
  /// `HomeFailure` when there is no usable session, the API refuses or cannot
  /// be reached, or a response does not match its modelled shape.
  Future<JuniorProgress?> getProgress();
}
