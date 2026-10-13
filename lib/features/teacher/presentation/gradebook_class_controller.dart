import 'package:flutter/foundation.dart';

import '../domain/teacher_failure.dart';
import '../domain/teacher_gradebook_repository.dart';
import '../domain/teacher_submission.dart';
import 'teacher_home_strings.dart';

/// Loads a class's roster for the Programs student list (Issues #233,
/// #390): its enrolled students (`GET /teacher/cohorts/{id}/students`), its
/// assignments, and each assignment's latest submission per student — one
/// request per assignment.
///
/// Same shape as the other Teacher controllers: a plain [ChangeNotifier],
/// a `_disposed` guard, one fixed string per [TeacherFailureKind] and a
/// single-flight [load]. A review saved on the student detail comes back
/// through [replaceSubmission], so the badges stay true without a reload.
class GradebookClassController extends ChangeNotifier {
  GradebookClassController({required this._repository, required this.cohortId});

  final TeacherGradebookRepository _repository;
  final int cohortId;

  bool _disposed = false;
  bool _loading = false;
  List<CohortStudent>? _students;
  List<TeacherAssignment> _assignments = const [];

  /// student id → assignment id → that student's latest submission.
  final Map<int, Map<int, TeacherSubmission>> _byStudent = {};
  String? _errorMessage;
  Future<void>? _inFlight;

  bool get loading => _loading;

  /// The roster, in the API's order (by name). Null until a load succeeds.
  List<CohortStudent>? get students => _students;

  /// The class's assignments, in the API's order.
  List<TeacherAssignment> get assignments => _assignments;

  /// Set only when the most recent load failed.
  String? get errorMessage => _errorMessage;

  /// [studentId]'s latest submission per assignment id.
  Map<int, TeacherSubmission> submissionsOf(int studentId) =>
      Map.unmodifiable(_byStudent[studentId] ?? const {});

  /// How many of [studentId]'s submissions wait for review —
  /// `status: "submitted"`. Other statuses are never counted.
  int pendingOf(int studentId) => (_byStudent[studentId] ?? const {}).values
      .where((s) => s.isPending)
      .length;

  /// Safe to call again — retry and pull to refresh join a load in flight.
  Future<void> load() =>
      _inFlight ??= _fetch().whenComplete(() => _inFlight = null);

  Future<void> _fetch() async {
    _loading = true;
    _errorMessage = null;
    _notify();
    try {
      // Both at once; the first failure is the one reported.
      final first = await Future.wait<Object>([
        _repository.getStudents(cohortId),
        _repository.getAssignments(cohortId),
      ]);
      final students = first[0] as List<CohortStudent>;
      final assignments = first[1] as List<TeacherAssignment>;
      final perAssignment = await Future.wait([
        for (final assignment in assignments)
          _repository.getSubmissions(assignment.id),
      ]);
      if (_disposed) return;
      _byStudent.clear();
      for (final (index, submissions) in perAssignment.indexed) {
        for (final submission in submissions) {
          final studentId = submission.student?.id;
          if (studentId == null) continue;
          (_byStudent[studentId] ??= {})[assignments[index].id] = submission;
        }
      }
      _students = students;
      _assignments = assignments;
    } on TeacherFailure catch (failure) {
      if (_disposed) return;
      _fail(failure);
    } catch (_) {
      if (_disposed) return;
      _fail(const TeacherFailure(TeacherFailureKind.unexpected));
    }
    _loading = false;
    _notify();
  }

  void _fail(TeacherFailure failure) {
    _students = null;
    _errorMessage = TeacherHomeStrings.messageFor(failure.kind);
  }

  /// A review saved for [studentId] — the submission as the server stored
  /// it replaces the one held, so its badge and thread follow.
  void replaceSubmission(int studentId, TeacherSubmission submission) {
    final assignmentId = submission.assignmentId;
    if (assignmentId == null) return;
    (_byStudent[studentId] ??= {})[assignmentId] = submission;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
