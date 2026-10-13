import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/teacher_attendance.dart';
import '../domain/teacher_failure.dart';
import '../domain/teacher_session.dart';
import 'teacher_home_strings.dart';

/// What the QR screen's code area shows.
enum AttendanceQrPhase {
  /// The first token is on its way.
  loading,

  /// A live token is drawn.
  showing,

  /// `409 session_not_today` — the backend issues QRs only on the
  /// session's date (Ulaanbaatar).
  notToday,

  /// The token's five minutes ran out before a fresh one arrived.
  expired,

  /// No token could be fetched.
  failed,
}

/// Drives the QR attendance screen (Issue #374): issues the session's
/// check-in token and re-issues it before it expires, and polls the
/// session's counts while the screen is open.
///
/// Same shape as the other Teacher controllers: a plain [ChangeNotifier]
/// with a `_disposed` guard, so an answer arriving after the screen closed
/// changes nothing. [dispose] cancels every timer.
///
/// The code encodes the issued `token` itself, raw — no URL or JSON around
/// it — exactly what the student's check-in sends back as `{"token"}`
/// (Issue #380; the backend's own tests do the same). The token is never
/// logged or put in an error message, and the code widget is keyed by
/// [tokenGeneration], not by the token.
class AttendanceQrController extends ChangeNotifier {
  AttendanceQrController({
    required this._repository,
    required this.sessionId,
    this.refreshEvery = const Duration(minutes: 4),
    this.pollEvery = const Duration(seconds: 15),
  });

  final TeacherAttendanceRepository _repository;
  final int sessionId;

  /// Before the token's [AttendanceQrToken.lifetime] runs out.
  final Duration refreshEvery;

  /// How often the counts are re-read while the screen is open.
  final Duration pollEvery;

  bool _disposed = false;
  bool _started = false;

  AttendanceQrPhase _phase = AttendanceQrPhase.loading;
  AttendanceQrToken? _token;
  int _tokenGeneration = 0;
  String? _qrError;
  AttendanceCounts? _counts;
  String? _countsError;

  Timer? _refreshTimer;
  Timer? _expiryTimer;
  Timer? _pollTimer;
  Future<void>? _issuing;
  Future<void>? _reading;

  AttendanceQrPhase get phase => _phase;

  /// What the QR encodes: the raw token — only in
  /// [AttendanceQrPhase.showing].
  String? get qrData {
    final token = _token;
    if (_phase != AttendanceQrPhase.showing || token == null) return null;
    return token.token;
  }

  /// Counts the tokens received — a new one is a new picture. Safe to put
  /// in a key or a log, unlike the token.
  int get tokenGeneration => _tokenGeneration;

  /// The message for [AttendanceQrPhase.failed].
  String? get qrError => _qrError;

  /// The latest counts read; kept through a failed poll.
  AttendanceCounts? get counts => _counts;

  /// Set only while no counts have ever been read and the last read failed.
  String? get countsError => _countsError;

  /// Starts the token and the polling. Once.
  void start() {
    if (_started) return;
    _started = true;
    issue();
    refreshCounts();
    _pollTimer = Timer.periodic(pollEvery, (_) => refreshCounts());
  }

  /// Fetches a fresh token — the first, a scheduled refresh, or a retry.
  /// Joins one in flight: a retry or a refresh never overlaps another.
  Future<void> issue() =>
      _issuing ??= _issue().whenComplete(() => _issuing = null);

  Future<void> _issue() async {
    if (_token == null) {
      _phase = AttendanceQrPhase.loading;
      _qrError = null;
      _notify();
    }
    try {
      final token = await _repository.issueQr(sessionId);
      if (_disposed) return;
      _token = token;
      _tokenGeneration++;
      _phase = AttendanceQrPhase.showing;
      _qrError = null;
      _schedule();
    } on TeacherFailure catch (failure) {
      if (_disposed) return;
      _onIssueFailed(failure);
    } catch (_) {
      if (_disposed) return;
      _onIssueFailed(const TeacherFailure(TeacherFailureKind.unexpected));
    }
    _notify();
  }

  void _onIssueFailed(TeacherFailure failure) {
    if (failure.code == 'session_not_today') {
      _cancelTokenTimers();
      _token = null;
      _phase = AttendanceQrPhase.notToday;
      return;
    }
    // A refresh that failed leaves the code on screen until it expires —
    // the expiry timer is still set; a retry is offered once it does.
    if (_token != null) return;
    _phase = AttendanceQrPhase.failed;
    _qrError = TeacherHomeStrings.messageFor(failure.kind);
  }

  /// A refresh [refreshEvery] after this token arrived, and its expiry
  /// [AttendanceQrToken.lifetime] after — timed by this phone from the
  /// arrival, not by `expires_at`, which a phone whose clock is off would
  /// misread.
  void _schedule() {
    _cancelTokenTimers();
    _refreshTimer = Timer(refreshEvery, issue);
    _expiryTimer = Timer(AttendanceQrToken.lifetime, _expire);
  }

  void _expire() {
    if (_disposed) return;
    _cancelTokenTimers();
    _token = null;
    _phase = AttendanceQrPhase.expired;
    _notify();
  }

  void _cancelTokenTimers() {
    _refreshTimer?.cancel();
    _expiryTimer?.cancel();
    _refreshTimer = null;
    _expiryTimer = null;
  }

  /// Re-reads the counts — on the poll, and when the manual screen
  /// returns. Joins a read in flight.
  Future<void> refreshCounts() =>
      _reading ??= _readCounts().whenComplete(() => _reading = null);

  Future<void> _readCounts() async {
    try {
      final attendance = await _repository.getSessionAttendance(sessionId);
      if (_disposed) return;
      _counts = attendance.counts;
      _countsError = null;
    } on TeacherFailure catch (failure) {
      if (_disposed) return;
      if (_counts == null) {
        _countsError = TeacherHomeStrings.messageFor(failure.kind);
      }
    } catch (_) {
      if (_disposed) return;
      if (_counts == null) {
        _countsError = TeacherHomeStrings.messageFor(
          TeacherFailureKind.unexpected,
        );
      }
    }
    _notify();
  }

  /// The token in view — for tests.
  @visibleForTesting
  AttendanceQrToken? get token => _token;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTokenTimers();
    _pollTimer?.cancel();
    _pollTimer = null;
    super.dispose();
  }
}
