import 'dart:async';

import 'package:aia_mobile/features/teacher/domain/teacher_class.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_gradebook_repository.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_submission.dart';

/// A repository the tests drive by hand: [classes], each class's
/// [assignments], each assignment's [submissionsOf] (the latest per
/// student), each submission by id in [submissions]; [failure] fails the
/// class, assignment and submissions-list reads, [submissionFailure] the
/// detail; [hold] parks the next class read until [release].
class FakeTeacherGradebookRepository implements TeacherGradebookRepository {
  FakeTeacherGradebookRepository({
    this.classes = const [],
    this.assignments = const {},
    this.submissionsOf = const {},
    this.submissions = const {},
    this.failure,
    this.submissionFailure,
    this.hold = false,
  });

  List<TeacherClass> classes;
  Map<int, List<TeacherAssignment>> assignments;
  Map<int, List<TeacherSubmission>> submissionsOf;
  Map<int, TeacherSubmission> submissions;
  TeacherFailure? failure;
  TeacherFailure? submissionFailure;
  bool hold;

  int classCalls = 0;
  final List<int> assignmentCalls = [];
  final List<int> submissionListCalls = [];
  final List<int> submissionCalls = [];

  Completer<void>? _gate;

  void release() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<List<TeacherClass>> getClasses() async {
    classCalls++;
    if (hold) {
      _gate = Completer<void>();
      await _gate!.future;
    }
    final failure = this.failure;
    if (failure != null) throw failure;
    return classes;
  }

  @override
  Future<List<TeacherAssignment>> getAssignments(int cohortId) async {
    assignmentCalls.add(cohortId);
    final failure = this.failure;
    if (failure != null) throw failure;
    return assignments[cohortId] ?? const [];
  }

  @override
  Future<List<TeacherSubmission>> getSubmissions(int assignmentId) async {
    submissionListCalls.add(assignmentId);
    final failure = this.failure;
    if (failure != null) throw failure;
    return submissionsOf[assignmentId] ?? const [];
  }

  @override
  Future<TeacherSubmission> getSubmission(int submissionId) async {
    submissionCalls.add(submissionId);
    final failure = submissionFailure;
    if (failure != null) throw failure;
    final submission = submissions[submissionId];
    if (submission == null) {
      throw const TeacherFailure(TeacherFailureKind.rejected);
    }
    return submission;
  }
}

/// A latest-per-student submission in the confirmed list shape. Test
/// values only.
TeacherSubmission sampleSubmission({
  int id = 18,
  int assignmentId = 2,
  int studentId = 13,
  String studentName = 'Хүслэн Цэрэндорж',
  String? initials = 'ХЦ',
  String status = 'reviewed',
  num? score = 80,
  String? feedback = 'Validation хэсэг дутуу байна.',
  String? description = 'Засварласан хувилбар.',
  String? link = 'https://github.com/example/hw-2',
  DateTime? submittedAt,
}) => TeacherSubmission(
  id: id,
  assignmentId: assignmentId,
  student: SubmissionStudent(
    id: studentId,
    name: studentName,
    initials: initials,
  ),
  status: status,
  score: score,
  feedback: feedback,
  description: description,
  link: link,
  submittedAt: submittedAt ?? DateTime(2026, 4, 30, 14),
);
