import 'dart:async';

import 'package:aia_mobile/features/teacher/domain/schedule_change.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';

/// A [ScheduleChangeRepository] the tests drive by hand (Issue #449): answers
/// [teachers], or throws [loadFailure]; a send answers a confirmed `pending`
/// request, or throws [sendFailure], and — with [holdSend] — waits for
/// [releaseSend], so a test can tap again while one is in flight.
class FakeScheduleChangeRepository implements ScheduleChangeRepository {
  FakeScheduleChangeRepository({
    this.teachers = const [],
    this.loadFailure,
    this.sendFailure,
    this.holdSend = false,
  });

  List<EligibleTeacher> teachers;
  TeacherFailure? loadFailure;
  TeacherFailure? sendFailure;
  bool holdSend;

  /// Every session id a read asked for, in order.
  final List<int> loadCalls = [];

  /// Every send, as (session id, recipient teacher id), in order.
  final List<(int, int)> sendCalls = [];

  Completer<void>? _gate;

  /// Lets a held send finish.
  void releaseSend() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<List<EligibleTeacher>> getEligibleTeachers(int sessionId) async {
    loadCalls.add(sessionId);
    final failure = loadFailure;
    if (failure != null) throw failure;
    return teachers;
  }

  @override
  Future<SentScheduleChange> sendRequest({
    required int sessionId,
    required int recipientTeacherId,
  }) async {
    sendCalls.add((sessionId, recipientTeacherId));
    if (holdSend) {
      _gate = Completer<void>();
      await _gate!.future;
    }
    final failure = sendFailure;
    if (failure != null) throw failure;
    return SentScheduleChange(
      id: 900 + sendCalls.length,
      recipientTeacherId: recipientTeacherId,
      status: 'pending',
    );
  }
}

/// Two teachers, as `eligible-teachers` lists them.
const sampleEligibleTeachers = [
  EligibleTeacher(id: 5, name: 'Болд Бат'),
  EligibleTeacher(id: 8, name: 'Сараа Ганбат'),
];
