import 'package:flutter/foundation.dart';

import '../domain/teacher_failure.dart';
import '../domain/teacher_gradebook_repository.dart';
import '../domain/teacher_submission.dart';
import 'teacher_home_strings.dart';
import 'widgets/gradebook_widgets.dart';

/// Loads a class's submitted assignments for the Gradebook student list
/// (Issue #233).
///
/// Same shape as `TeacherHomeController`: a plain [ChangeNotifier], a
/// `_disposed` guard, one fixed string per [TeacherFailureKind] and a
/// single-flight [load].
///
/// The rows are the class's assignments (`/teacher/cohorts/{id}/
/// assignments`), each with its latest submission per student
/// (`/teacher/assignments/{id}/submissions`) — one request per assignment.
/// So only students who submitted appear, once per assignment they
/// submitted; no single assignment is picked for them. Newest first.
class GradebookClassController extends ChangeNotifier {
  GradebookClassController({required this._repository, required this.cohortId});

  final TeacherGradebookRepository _repository;
  final int cohortId;

  bool _disposed = false;
  bool _loading = false;
  List<GradebookRow>? _rows;
  String? _errorMessage;

  bool get loading => _loading;

  /// Null until the first fetch succeeds, and again after one fails.
  List<GradebookRow>? get rows => _rows;

  /// Set only when the most recent fetch failed.
  String? get errorMessage => _errorMessage;

  Future<void>? _inFlight;

  /// Safe to call again — retry and pull to refresh join a fetch in flight.
  Future<void> load() =>
      _inFlight ??= _fetch().whenComplete(() => _inFlight = null);

  Future<void> _fetch() async {
    _loading = true;
    _errorMessage = null;
    _notify();

    try {
      final assignments = await _repository.getAssignments(cohortId);
      final perAssignment = await Future.wait([
        for (final assignment in assignments)
          _repository.getSubmissions(assignment.id),
      ]);
      final rows = <GradebookRow>[
        for (final (index, submissions) in perAssignment.indexed)
          for (final submission in submissions)
            GradebookRow(
              submission: submission,
              assignmentTitle: assignments[index].displayTitle,
            ),
      ];
      rows.sort(_newestFirst);
      _rows = rows;
    } on TeacherFailure catch (failure) {
      _rows = null;
      _errorMessage = TeacherHomeStrings.messageFor(failure.kind);
    } catch (_) {
      _rows = null;
      _errorMessage = TeacherHomeStrings.messageFor(
        TeacherFailureKind.unexpected,
      );
    } finally {
      _loading = false;
      _notify();
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Latest `submitted_at` first; a row without one goes last.
int _newestFirst(GradebookRow a, GradebookRow b) {
  final at = a.submission.submittedAt;
  final bt = b.submission.submittedAt;
  if (at == null && bt == null) return 0;
  if (at == null) return 1;
  if (bt == null) return -1;
  return bt.compareTo(at);
}

/// The rows of [rows] under [filter] — the confirmed `status` decides.
List<GradebookRow> filterRows(
  List<GradebookRow> rows,
  GradebookFilter filter,
) => [
  for (final row in rows)
    if (matchesFilter(row.submission.status, filter)) row,
];
