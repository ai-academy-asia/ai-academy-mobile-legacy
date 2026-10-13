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

/// A changed student's record as the server now holds it, when it differs
/// from what the teacher's edit was based on (Issue #378): a QR check-in, or
/// another teacher's or staff member's mark, since the roster was read.
class AttendanceConflict {
  const AttendanceConflict({required this.status, required this.method});

  final AttendanceStatus status;

  /// `qr`, `manual`, or null for no record (shown as `absent`).
  final String? method;
}

/// One student on the manual screen: the status the server last confirmed
/// ([saved]) and the one the teacher has chosen ([current]).
class AttendanceRow {
  AttendanceRow(this.student)
    : saved = student.status,
      current = student.status,
      baseStatus = student.status,
      baseMethod = student.method;

  final StudentAttendance student;

  /// As the server last stored it — the roster's, then each confirmed
  /// write's answer.
  AttendanceStatus saved;

  /// As the teacher has set it.
  AttendanceStatus current;

  /// The server record the teacher's edit is based on — `status` and
  /// `method` as last read or written. A confirm sends this row only while
  /// the server still holds exactly this.
  AttendanceStatus baseStatus;
  String? baseMethod;

  /// Set when the server's record moved away from the base: the row is not
  /// sent until the teacher resolves it.
  AttendanceConflict? conflict;

  AttendanceWrite write = AttendanceWrite.idle;

  /// Only a changed row is ever sent — an untouched `late` or `excused`,
  /// or a QR check-in, is never overwritten.
  bool get changed => current != saved;

  /// Takes [status]/[method] as the server's latest, unchanged by the
  /// teacher.
  void _adopt(AttendanceStatus status, String? method) {
    saved = status;
    current = status;
    baseStatus = status;
    baseMethod = method;
    conflict = null;
    write = AttendanceWrite.idle;
  }
}

/// What a confirm ended in.
enum AttendanceSubmitResult {
  /// Every intended write was stored: the success card may show.
  allSaved,

  /// At least one write failed; its rows stay changed for a retry.
  someFailed,

  /// At least one changed student's server record moved since it was read:
  /// those rows were not sent and wait for the teacher's decision.
  conflicts,

  /// The roster could not be re-read before saving, so nothing was sent.
  checkFailed,

  /// Nothing was sent: no row changed, or a submit was already running.
  nothingSent,
}

/// Drives the manual attendance screen (Issues #374, #378): loads the
/// session's roster, tracks each student's chosen status against the stored
/// one, and sends only the rows that changed.
///
/// There is no batch endpoint, so a confirm is one
/// `PUT /teacher/sessions/{id}/attendance/{student_id}` per changed row,
/// one at a time. A row whose write succeeds takes the server's answer as
/// its stored status, so it is no longer changed and is **never sent
/// again**; a row whose write fails stays changed and is the only thing the
/// next confirm sends. A confirm while one runs sends nothing.
///
/// **Before any write, the roster is read again** (`GET .../attendance`,
/// Issue #378). A changed row is sent only if the server still holds the
/// `status` and `method` the teacher's edit was based on; otherwise it
/// becomes an [AttendanceConflict] and waits for the teacher to
/// [keepServer] or [applyMine]. Rows the teacher did not touch take the
/// server's latest values.
///
/// **What this does not close:** the PUT is an unconditional overwrite, and
/// the backend offers no conditional write (no version, ETag or expected
/// status). A change that lands between this re-read and a row's PUT — a
/// window of seconds, one PUT at a time — can still be overwritten. Closing
/// it needs a backend change (`DATA_AND_API.md` §1).
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
  String? _checkError;
  Future<void>? _inFlight;

  /// Writes stored since the teacher's last completed confirm — so a
  /// confirm finished after resolving conflicts still reports success for
  /// the writes it made, and one that wrote nothing never does.
  int _storedInConfirm = 0;

  bool get loading => _loading;
  bool get submitting => _submitting;

  /// Null until the roster loads, and again after a load fails.
  List<AttendanceRow>? get rows => _rows;

  /// Set only when the most recent load failed.
  String? get errorMessage => _errorMessage;

  /// Set when the last confirm could not re-read the roster.
  String? get checkError => _checkError;

  /// Rows whose last write failed.
  int get failedCount =>
      _rows?.where((r) => r.write == AttendanceWrite.failed).length ?? 0;

  /// Rows waiting for the teacher to resolve a server change.
  List<AttendanceRow> get conflicts => [
    for (final row in _rows ?? const <AttendanceRow>[])
      if (row.conflict != null) row,
  ];

  /// Whether a confirm would send anything.
  bool get hasChanges => _rows?.any((r) => r.changed) ?? false;

  /// Whether "Баталгаажуулах" does anything: no unresolved conflict, and
  /// something to send or a confirm to finish.
  bool get canConfirm =>
      !_submitting && conflicts.isEmpty && (hasChanges || _storedInConfirm > 0);

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

  /// Sets [row]'s chosen status. Ignored while a confirm runs, and on a row
  /// in conflict — that is resolved with [keepServer] or [applyMine].
  /// Choosing the stored status again clears a failed write — there is
  /// nothing to send.
  void choose(AttendanceRow row, AttendanceStatus status) {
    if (_submitting || row.conflict != null) return;
    row.current = status;
    if (!row.changed) row.write = AttendanceWrite.idle;
    _notify();
  }

  /// Resolves [row]'s conflict by taking the server's record: nothing is
  /// sent for it.
  void keepServer(AttendanceRow row) {
    final conflict = row.conflict;
    if (_submitting || conflict == null) return;
    row._adopt(conflict.status, conflict.method);
    _notify();
  }

  /// Resolves [row]'s conflict by keeping the teacher's choice: the
  /// server's record becomes the base, and the next confirm — after reading
  /// the roster again — sends the choice.
  void applyMine(AttendanceRow row) {
    final conflict = row.conflict;
    if (_submitting || conflict == null) return;
    row
      ..saved = conflict.status
      ..baseStatus = conflict.status
      ..baseMethod = conflict.method
      ..conflict = null
      ..write = AttendanceWrite.idle;
    _notify();
  }

  /// Re-reads the roster, then sends every changed row whose server record
  /// is still its base, one PUT each, in roster order.
  Future<AttendanceSubmitResult> submit() async {
    final rows = _rows;
    if (_submitting || rows == null || conflicts.isNotEmpty) {
      return AttendanceSubmitResult.nothingSent;
    }
    if (!rows.any((r) => r.changed)) {
      if (_storedInConfirm == 0) return AttendanceSubmitResult.nothingSent;
      _storedInConfirm = 0;
      return AttendanceSubmitResult.allSaved;
    }

    _submitting = true;
    _checkError = null;
    _notify();

    // The final re-read: what the server holds right before writing.
    final Map<int, StudentAttendance> latest;
    try {
      final attendance = await _repository.getSessionAttendance(sessionId);
      latest = {for (final s in attendance.students) s.studentId: s};
    } catch (failure) {
      if (_disposed) return AttendanceSubmitResult.nothingSent;
      _checkError = TeacherHomeStrings.messageFor(
        failure is TeacherFailure
            ? failure.kind
            : TeacherFailureKind.unexpected,
      );
      _submitting = false;
      _notify();
      return AttendanceSubmitResult.checkFailed;
    }
    if (_disposed) return AttendanceSubmitResult.nothingSent;

    final targets = <AttendanceRow>[];
    var failed = 0;
    for (final row in rows) {
      final server = latest[row.student.studentId];
      if (!row.changed) {
        // Untouched: show the server's latest.
        if (server != null) row._adopt(server.status, server.method);
        continue;
      }
      if (server == null) {
        // No longer on the roster: the PUT would be refused; not sent.
        row.write = AttendanceWrite.failed;
        failed++;
        continue;
      }
      if (server.status == row.baseStatus && server.method == row.baseMethod) {
        targets.add(row);
      } else if (server.status == row.current && server.method == 'manual') {
        // The teacher's own write already landed (an answer lost on the
        // way back): stored — not sent again.
        row._adopt(server.status, server.method);
        _storedInConfirm++;
      } else {
        row
          ..conflict = AttendanceConflict(
            status: server.status,
            method: server.method,
          )
          ..write = AttendanceWrite.idle;
      }
    }

    for (final row in targets) {
      row.write = AttendanceWrite.saving;
    }
    _notify();

    for (final row in targets) {
      try {
        final stored = await _repository.markAttendance(
          sessionId: sessionId,
          studentId: row.student.studentId,
          status: row.current,
        );
        if (_disposed) return AttendanceSubmitResult.nothingSent;
        // The server's answer is the truth; a mark is always `manual`.
        row._adopt(stored, 'manual');
        _storedInConfirm++;
      } catch (_) {
        if (_disposed) return AttendanceSubmitResult.nothingSent;
        row.write = AttendanceWrite.failed;
        failed++;
      }
      _notify();
    }

    _submitting = false;
    final AttendanceSubmitResult result;
    if (conflicts.isNotEmpty) {
      result = AttendanceSubmitResult.conflicts;
    } else if (failed > 0 || hasChanges) {
      result = AttendanceSubmitResult.someFailed;
    } else {
      _storedInConfirm = 0;
      result = AttendanceSubmitResult.allSaved;
    }
    _notify();
    return result;
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
