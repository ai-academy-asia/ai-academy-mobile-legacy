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
    this.request,
    this.requestFailures = const [],
    this.decisionFailure,
    this.holdDecision = false,
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

  // --- Incoming requests (Issue #453) --------------------------------------

  /// What a read answers — and what a decision answers, at its new status.
  ScheduleChangeRequest? request;

  /// Thrown by successive reads, in order; once used up, reads answer
  /// [request].
  List<TeacherFailure> requestFailures;

  /// Thrown by accept or reject, instead of deciding.
  TeacherFailure? decisionFailure;

  /// When true, a decision waits for [releaseDecision].
  bool holdDecision;

  /// Every request id read, in order.
  final List<int> requestReads = [];

  /// Every decision, as (request id, 'accept' | 'reject', reason).
  final List<(int, String, String?)> decisions = [];

  Completer<void>? _decisionGate;

  /// Lets a held decision finish.
  void releaseDecision() {
    final gate = _decisionGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

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

  @override
  Future<ScheduleChangeRequest> getRequest(int requestId) async {
    requestReads.add(requestId);
    if (requestFailures.isNotEmpty) {
      final failure = requestFailures.first;
      requestFailures = requestFailures.sublist(1);
      throw failure;
    }
    final request = this.request;
    if (request == null) {
      throw const TeacherFailure(
        TeacherFailureKind.rejected,
        code: 'request_not_found',
      );
    }
    return request;
  }

  @override
  Future<ScheduleChangeRequest> acceptRequest(int requestId) =>
      _decide(requestId, 'accept', null, 'accepted');

  @override
  Future<ScheduleChangeRequest> rejectRequest(
    int requestId, {
    String? reason,
  }) => _decide(requestId, 'reject', reason, 'rejected');

  Future<ScheduleChangeRequest> _decide(
    int requestId,
    String action,
    String? reason,
    String status,
  ) async {
    decisions.add((requestId, action, reason));
    if (holdDecision) {
      _decisionGate = Completer<void>();
      await _decisionGate!.future;
    }
    final failure = decisionFailure;
    if (failure != null) throw failure;
    final decided = sampleIncomingRequest(id: requestId, status: status);
    request = decided;
    return decided;
  }
}

/// An incoming request, as `GET …/{id}` reads it. Test values only.
ScheduleChangeRequest sampleIncomingRequest({
  int id = 12,
  String status = 'pending',
  String? courseTitle = 'Corporate Leaders',
  String? cohortName = 'CL-2026-10',
  String? room = 'Room 204',
  String? startTime = '09:00',
  String? endTime = '11:00',
}) => ScheduleChangeRequest(
  id: id,
  sessionId: 345,
  status: status,
  senderName: 'Анар Бат',
  sessionDate: DateTime(2026, 10, 20),
  startTime: startTime,
  endTime: endTime,
  courseTitle: courseTitle,
  cohortName: cohortName,
  room: room,
);

/// Two teachers, as `eligible-teachers` lists them.
const sampleEligibleTeachers = [
  EligibleTeacher(id: 5, name: 'Болд Бат'),
  EligibleTeacher(id: 8, name: 'Сараа Ганбат'),
];
