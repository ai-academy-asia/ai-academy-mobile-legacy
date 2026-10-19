import 'package:flutter/foundation.dart';

import '../domain/schedule_change.dart';
import '../domain/teacher_failure.dart';
import 'teacher_schedule_strings.dart';

/// One incoming schedule-change request (Issue #453): reads its current
/// state, and accepts or rejects it.
///
/// Same `ChangeNotifier`/`_disposed` shape as the other teacher controllers.
/// Nothing is assumed: the actions show only while the server says the
/// request is `pending`, a decision shows only once the server answers with
/// the request at that status, and a failure is copy, never a success.
class IncomingRequestController extends ChangeNotifier {
  IncomingRequestController({
    required this._repository,
    required this.requestId,
  });

  final ScheduleChangeRepository _repository;

  /// The request — the notification's `data.request_id`.
  final int requestId;

  bool _disposed = false;
  bool _loading = false;
  bool _hasLoaded = false;
  ScheduleChangeRequest? _request;
  String? _loadError;
  String? _actionError;
  bool _busy = false;
  bool _acceptBlocked = false;
  bool _answerClosed = false;

  /// True while the request is being read.
  bool get loading => _loading;

  /// True once a read has answered, either way.
  bool get hasLoaded => _hasLoaded;

  /// The request as the server last reported it; null until a read
  /// succeeds, and after one that failed.
  ScheduleChangeRequest? get request => _request;

  /// Why the request could not be read, or null.
  String? get loadError => _loadError;

  /// Why the last answer failed, or null. Cleared when another starts.
  String? get actionError => _actionError;

  /// True while an accept or reject is in flight.
  bool get busy => _busy;

  /// Whether "Татгалзах" / "Зөвшөөрөх" are drawn: the request is `pending`
  /// and nothing has shown it can no longer be answered from here.
  bool get showActions => (_request?.isPending ?? false) && !_answerClosed;

  /// Whether "Зөвшөөрөх" can be tapped now. A schedule conflict or a
  /// covered session keeps it off — accepting again would fail the same
  /// way — while "Татгалзах" stays available.
  bool get canAccept => showActions && !_busy && !_acceptBlocked;

  /// Whether "Татгалзах" can be tapped now.
  bool get canReject => showActions && !_busy;

  /// The line under the card: the last answer's failure, else where a
  /// resolved request stands, else none.
  String? get message =>
      _actionError ??
      switch (_request) {
        final request? => TeacherScheduleStrings.incomingStatus(request.status),
        null => null,
      };

  /// Reads the request's current state. Ignored while a read is in flight.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _loadError = null;
    _notify();

    try {
      _request = await _repository.getRequest(requestId);
    } on TeacherFailure catch (failure) {
      _request = null;
      _loadError = TeacherScheduleStrings.requestFailure(failure);
    } catch (_) {
      _request = null;
      _loadError = TeacherScheduleStrings.requestFailure(
        const TeacherFailure(TeacherFailureKind.unexpected),
      );
    } finally {
      _loading = false;
      _hasLoaded = true;
      _notify();
    }
  }

  /// Accepts the request. Ignored (nothing sent) unless it can be — see
  /// [canAccept].
  Future<void> accept() => _answer(
    allowed: canAccept,
    send: () => _repository.acceptRequest(requestId),
  );

  /// Rejects the request, with no reason — the sheet has no reason field.
  /// Ignored (nothing sent) unless it can be — see [canReject].
  Future<void> reject() => _answer(
    allowed: canReject,
    send: () => _repository.rejectRequest(requestId),
  );

  Future<void> _answer({
    required bool allowed,
    required Future<ScheduleChangeRequest> Function() send,
  }) async {
    if (!allowed) return;
    _busy = true;
    _actionError = null;
    _notify();

    try {
      // The repository answers only once the server reports the decision.
      _request = await send();
    } on TeacherFailure catch (failure) {
      _actionError = TeacherScheduleStrings.requestFailure(failure);
      await _afterFailure(failure);
    } catch (_) {
      _actionError = TeacherScheduleStrings.requestFailure(
        const TeacherFailure(TeacherFailureKind.unexpected),
      );
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// What a refused answer means for the actions (contract §4):
  ///
  /// * `request_already_resolved`, `session_started` — the request is no
  ///   longer `pending` (the latter is now `expired`): re-read it, so the
  ///   sheet shows where it stands; if that read fails, close the actions.
  /// * `schedule_conflict`, `session_already_covered` — still `pending`,
  ///   but accepting would fail again: accept off, reject stays.
  /// * `not_recipient`, `request_not_found` — this teacher cannot answer it:
  ///   close the actions.
  /// * anything else (network, session, server) — nothing is known to have
  ///   changed: the actions stay, for a retry.
  Future<void> _afterFailure(TeacherFailure failure) async {
    switch (failure.code) {
      case 'request_already_resolved' || 'session_started':
        try {
          _request = await _repository.getRequest(requestId);
        } catch (_) {
          _answerClosed = true;
        }
      case 'schedule_conflict' || 'session_already_covered':
        _acceptBlocked = true;
      case 'not_recipient' || 'request_not_found':
        _answerClosed = true;
      default:
        break;
    }
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
