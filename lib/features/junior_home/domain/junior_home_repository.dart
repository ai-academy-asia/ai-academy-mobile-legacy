import 'junior_learning_map.dart';

abstract interface class JuniorHomeRepository {
  /// The Junior map for the course the signed-in student is enrolled in.
  ///
  /// Throws `CourseLearningFailure` when there is no usable session, the API
  /// refuses or cannot be reached, or a response does not match its modelled
  /// shape — the same family `CourseLearningRepository` reports, because this
  /// reads the same endpoint.
  ///
  /// A student enrolled in nothing is **not** a failure: it answers null, the
  /// way `HomeDashboard` answers an all-null dashboard rather than throwing.
  Future<JuniorLearningMap?> getLearningMap();
}
