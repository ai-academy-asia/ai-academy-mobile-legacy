import 'package:flutter/foundation.dart';

import '../domain/teacher_attendance.dart';
import '../domain/teacher_failure.dart';
import 'teacher_home_strings.dart';

/// Where a row's write stands.
enum AttendanceWrite {
  /// Nothing in flight, nothing failed.
  idle,

  /// Its PUT is in flight.
  saving,

  /// Its last PUT failed; it is sent again on the next confirm.
  failed,
}

/// One student on the manual screen: the status the server last confirmed
/// ([saved]) and the one the teacher has chosen ([current]).
class AttendanceRow {
  AttendanceRow(this.student)
    : saved = student.status,
      current = student.status;

  final StudentAttendance student;

  /// As the server last stored it — the roster's, then each confirmed
  /// write's answer.
  AttendanceStatus saved;

  /// As the teacher has set it.
  AttendanceStatus current;

  AttendanceWrite write = AttendanceWrite.idle;

  /// Only a changed row is ever sent — an untouched `late` or `excused`,
  /// or a QR check-in, is never overwritten.
  bool get changed => current != saved;
}

/// What a confirm ended in.
enum AttendanceSubmitResult {
  /// Every changed row was stored: the success card may show.
  allSaved,

  /// At least one write failed; its rows stay changed for a retry.
  someFailed,

  /// Nothing was sent: no row changed, or a submit was already running.
  nothingSent,
}

/// Drives the manual attendance screen (Issue #374): loads the session's
/// roster, tracks each student's chosen status against the stored one, and
/// sends only the rows that changed.
///
/// There is no batch endpoint, so a confirm is one
/// `PUT /teacher/sessions/{id}/attendance/{student_id}` per changed row,
/// one at a time. A row whose write succeeds takes the server's answer as
/// its stored status, so it is no longer changed and is **never sent
/// again**; a row whose write fails stays changed and is the only thing the
/// next confirm sends. A confirm while one runs sends nothing.
class ManualAttendanceController extends ChangeNotifier {
  ManualAttendanceController({
    required this._repository,
    required this.sessionId,
  });

  final TeacherAttendanceRepository _repository;
  final int sessionId;

  bool _disposed = false;
  bool _loading = false;
  bool _submitting = false;
  List<AttendanceRow>? _rows;
  String? _errorMessage;
  Future<void>? _inFlight;

  bool get loading => _loading;
  bool get submitting => _submitting;

  /// Null until the roster loads, and again after a load fails.
  List<AttendanceRow>? get rows => _rows;

  /// Set only when the most recent load failed.
  String? get errorMessage => _errorMessage;

  /// Rows whose last write failed.
  int get failedCount =>
      _rows?.where((r) => r.write == AttendanceWrite.failed).length ?? 0;

  /// Whether a confirm would send anything.
  bool get hasChanges => _rows?.any((r) => r.changed) ?? false;

  /// Loads the roster. Joins a load in flight.
  Future<void> load() =>
      _inFlight ??= _fetch().whenComplete(() => _inFlight = null);

  Future<void> _fetch() async {
    _loading = true;
    _errorMessage = null;
    _notify();
    try {
      final attendance = await _repository.getSessionAttendance(sessionId);
      if (_disposed) return;
      _rows = [for (final s in attendance.students) AttendanceRow(s)];
    } on TeacherFailure catch (failure) {
      if (_disposed) return;
      _rows = null;
      _errorMessage = TeacherHomeStrings.messageFor(failure.kind);
    } catch (_) {
      if (_disposed) return;
      _rows = null;
      _errorMessage = TeacherHomeStrings.messageFor(
        TeacherFailureKind.unexpected,
      );
    }
    _loading = false;
    _notify();
  }

  /// Sets [row]'s chosen status. Ignored while a confirm runs. Choosing the
  /// stored status again clears a failed write — there is nothing to send.
  void choose(AttendanceRow row, AttendanceStatus status) {
    if (_submitting) return;
    row.current = status;
    if (!row.changed) row.write = AttendanceWrite.idle;
    _notify();
  }

  /// Sends every changed row, one PUT each, in roster order.
  Future<AttendanceSubmitResult> submit() async {
    final rows = _rows;
    if (_submitting || rows == null) return AttendanceSubmitResult.nothingSent;
    final targets = [
      for (final row in rows)
        if (row.changed) row,
    ];
    if (targets.isEmpty) return AttendanceSubmitResult.nothingSent;

    _submitting = true;
    for (final row in targets) {
      row.write = AttendanceWrite.saving;
    }
    _notify();

    var failed = 0;
    for (final row in targets) {
      final sent = row.current;
      try {
        final stored = await _repository.markAttendance(
          sessionId: sessionId,
          studentId: row.student.studentId,
          status: sent,
        );
        if (_disposed) return AttendanceSubmitResult.nothingSent;
        row.saved = stored;
        // The server's answer is the truth; it only differs from what was
        // sent if the backend changes its rules.
        row.current = stored;
        row.write = AttendanceWrite.idle;
      } catch (_) {
        if (_disposed) return AttendanceSubmitResult.nothingSent;
        row.write = AttendanceWrite.failed;
        failed++;
      }
      _notify();
    }

    _submitting = false;
    _notify();
    return failed == 0 && !hasChanges
        ? AttendanceSubmitResult.allSaved
        : AttendanceSubmitResult.someFailed;
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
