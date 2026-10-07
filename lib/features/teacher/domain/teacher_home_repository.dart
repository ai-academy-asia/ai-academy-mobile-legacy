import 'teacher_class.dart';

abstract interface class TeacherHomeRepository {
  /// Every class the signed-in teacher teaches, in the order the API lists
  /// them. Teacher Home narrows them to today's with [classesMeetingOn].
  ///
  /// Throws `TeacherFailure` when there is no usable session, the account is
  /// not a teacher, the API refuses or cannot be reached, or the response
  /// does not match the verified shape.
  Future<List<TeacherClass>> getClasses();
}
