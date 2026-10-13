import 'package:flutter/foundation.dart';

import '../domain/attendance_check_in.dart';
import '../domain/attendance_failure.dart';
import '../domain/attendance_repository.dart';
import 'attendance_scanner_strings.dart';
import 'qr_scan_view.dart';

/// Where the scanner stands.
enum CheckInPhase {
  /// The camera is looking for a code.
  scanning,

  /// A code was read; its check-in is in flight. The camera is stopped.
  checkingIn,

  /// The server answered with a record — [StudentCheckInController.result].
  done,

  /// The check-in was refused or could not be made.
  failed,

  /// The camera cannot scan — [StudentCheckInController.unavailable].
  unavailable,
}

/// Drives the attendance scanner (Issue #384): takes the first QR code the
/// camera reads, checks in with it once, and holds what came back.
///
/// **One check-in at a time.** Only a code read while [CheckInPhase.scanning]
/// is used; any other detection — the same code in the next frame, a second
/// code — is ignored until the student chooses to [rescan].
///
/// **The token is passed on, never kept:** it goes straight to
/// [AttendanceRepository.checkIn] and is not stored, logged or shown.
///
/// **The result is the server's:** [result] is the record as returned —
/// `present`, `late`, or on a repeat a teacher's `absent` or `excused` —
/// never a generic success.
class StudentCheckInController extends ChangeNotifier {
  StudentCheckInController({required this._repository});

  final AttendanceRepository _repository;

  bool _disposed = false;
  CheckInPhase _phase = CheckInPhase.scanning;
  AttendanceCheckIn? _result;
  String? _error;
  bool _canRescan = true;
  QrScanUnavailable? _unavailable;
  int _cameraAttempt = 0;

  CheckInPhase get phase => _phase;

  /// Whether the camera should be scanning.
  bool get scanning => _phase == CheckInPhase.scanning;

  /// The server's record — set in [CheckInPhase.done].
  AttendanceCheckIn? get result => _result;

  /// What went wrong — set in [CheckInPhase.failed] and
  /// [CheckInPhase.unavailable].
  String? get error => _error;

  /// Whether scanning again can help.
  bool get canRescan => _canRescan;

  /// Why the camera cannot scan — set in [CheckInPhase.unavailable].
  QrScanUnavailable? get unavailable => _unavailable;

  /// Bumped to start a fresh camera after it was unavailable.
  int get cameraAttempt => _cameraAttempt;

  /// A code the camera read. Used only while scanning, and only once.
  Future<void> onCode(String token) async {
    if (_phase != CheckInPhase.scanning || token.isEmpty) return;
    _phase = CheckInPhase.checkingIn;
    _notify();
    try {
      final result = await _repository.checkIn(token);
      if (_disposed) return;
      _result = result;
      _phase = CheckInPhase.done;
    } on AttendanceFailure catch (failure) {
      if (_disposed) return;
      _fail(failure);
    } catch (_) {
      if (_disposed) return;
      _fail(const AttendanceFailure(AttendanceFailureKind.unexpected));
    }
    _notify();
  }

  void _fail(AttendanceFailure failure) {
    _phase = CheckInPhase.failed;
    _error = AttendanceScannerStrings.failureMessage(failure);
    // Signing in again is not something a scan can fix.
    _canRescan = failure.kind != AttendanceFailureKind.sessionExpired;
  }

  /// The camera cannot scan. Ignored once a code has been read.
  void onUnavailable(QrScanUnavailable reason) {
    if (_phase != CheckInPhase.scanning && _phase != CheckInPhase.unavailable) {
      return;
    }
    if (_phase == CheckInPhase.unavailable && _unavailable == reason) return;
    _phase = CheckInPhase.unavailable;
    _unavailable = reason;
    _error = AttendanceScannerStrings.unavailableMessage(reason);
    _canRescan = reason != QrScanUnavailable.unsupported;
    _notify();
  }

  /// Back to scanning after a failure, or a fresh camera after it was
  /// unavailable (once camera access is allowed, say).
  void rescan() {
    if (!_canRescan) return;
    if (_phase == CheckInPhase.unavailable) {
      _cameraAttempt++;
    } else if (_phase != CheckInPhase.failed) {
      return;
    }
    _phase = CheckInPhase.scanning;
    _error = null;
    _unavailable = null;
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
