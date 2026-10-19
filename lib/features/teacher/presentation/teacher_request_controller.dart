import 'package:flutter/foundation.dart';

import '../domain/schedule_change.dart';
import '../domain/teacher_failure.dart';
import 'teacher_request_screen.dart';
import 'teacher_schedule_strings.dart';

/// "Багш нар" for one session (Issue #449): loads who the session can be
/// handed to, and sends the request to one of them.
///
/// Same `ChangeNotifier`/`_disposed` shape as the other teacher controllers.
/// Nothing is shown before the server has said it: the list is the server's,
/// a row reads "Хүлээгдэж байна" only once a send is confirmed (`201`, or
/// `200` for an identical retry), and a failure is copy, never a success.
class TeacherRequestController extends ChangeNotifier {
  TeacherRequestController({
    required this._repository,
    required this.sessionId,
  });

  final ScheduleChangeRepository _repository;

  /// The session being handed over — `ScheduledSession.session.id`.
  final int sessionId;

  bool _disposed = false;
  bool _loading = false;
  bool _hasLoaded = false;
  List<EligibleTeacher> _teachers = const [];
  String? _loadError;
  final Map<int, TeacherRequestStatus> _statuses = {};
  int? _sendingTeacherId;

  /// True while the list is being read.
  bool get loading => _loading;

  /// True once a read has answered, either way.
  bool get hasLoaded => _hasLoaded;

  /// The teachers the server listed, in its order. Empty until a read
  /// succeeds — and after one that failed.
  List<EligibleTeacher> get teachers => _teachers;

  /// The last read's failure copy, or null — see
  /// [TeacherScheduleStrings.requestFailure].
  String? get loadError => _loadError;

  /// The teacher whose request is being sent, or null. While one is in
  /// flight every row's send is disabled.
  int? get sendingTeacherId => _sendingTeacherId;

  /// Where [teacherId]'s request stands on this screen: "not sent" until a
  /// send to them is confirmed.
  TeacherRequestStatus statusOf(int teacherId) =>
      _statuses[teacherId] ?? TeacherRequestStatus.notSent;

  /// Reads the eligible teachers. Safe to call again — the error view's
  /// retry — and ignored while a read is in flight.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _loadError = null;
    _notify();

    try {
      _teachers = await _repository.getEligibleTeachers(sessionId);
    } on TeacherFailure catch (failure) {
      _teachers = const [];
      _loadError = TeacherScheduleStrings.requestFailure(failure);
    } catch (_) {
      _teachers = const [];
      _loadError = TeacherScheduleStrings.requestFailure(
        const TeacherFailure(TeacherFailureKind.unexpected),
      );
    } finally {
      _loading = false;
      _hasLoaded = true;
      _notify();
    }
  }

  /// Sends the session to [teacherId].
  ///
  /// [TeacherRequestSent] once the server has confirmed it — the row then
  /// reads "Хүлээгдэж байна"; [TeacherRequestFailed] with the failure's copy
  /// otherwise. [TeacherRequestIgnored], with nothing sent, while any send is
  /// in flight or for a teacher whose request is already confirmed, so a
  /// double tap never sends twice.
  Future<TeacherRequestOutcome> send(int teacherId) async {
    if (_sendingTeacherId != null ||
        statusOf(teacherId) != TeacherRequestStatus.notSent) {
      return const TeacherRequestIgnored();
    }
    _sendingTeacherId = teacherId;
    _notify();

    try {
      final sent = await _repository.sendRequest(
        sessionId: sessionId,
        recipientTeacherId: teacherId,
      );
      // `pending` is the only status a confirmed send carries (see
      // `sentScheduleChangeFromJson`).
      if (sent.status == 'pending') {
        _statuses[teacherId] = TeacherRequestStatus.pending;
      }
      return const TeacherRequestSent();
    } on TeacherFailure catch (failure) {
      return TeacherRequestFailed(
        TeacherScheduleStrings.requestFailure(failure),
      );
    } catch (_) {
      return TeacherRequestFailed(
        TeacherScheduleStrings.requestFailure(
          const TeacherFailure(TeacherFailureKind.unexpected),
        ),
      );
    } finally {
      _sendingTeacherId = null;
      _notify();
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

/// What [TeacherRequestController.send] did.
sealed class TeacherRequestOutcome {
  const TeacherRequestOutcome();
}

/// The server confirmed the request: show "Хүсэлт илгээгдлээ".
final class TeacherRequestSent extends TeacherRequestOutcome {
  const TeacherRequestSent();
}

/// Nothing was sent — a send was already in flight, or this teacher's
/// request is already confirmed. Show nothing.
final class TeacherRequestIgnored extends TeacherRequestOutcome {
  const TeacherRequestIgnored();
}

/// The send failed: show [message], never a success.
final class TeacherRequestFailed extends TeacherRequestOutcome {
  const TeacherRequestFailed(this.message);

  final String message;
}
