import 'dart:async';

import 'package:aia_mobile/features/teacher/domain/teacher_class.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_gradebook_repository.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_submission.dart';

/// A repository the tests drive by hand: [classes], each submission by id
/// in [submissions]; [failure] / [submissionFailure] throw; [hold] parks
/// the next class read until [release].
class FakeTeacherGradebookRepository implements TeacherGradebookRepository {
  FakeTeacherGradebookRepository({
    this.classes = const [],
    this.submissions = const {},
    this.failure,
    this.submissionFailure,
    this.hold = false,
  });

  List<TeacherClass> classes;
  Map<int, TeacherSubmission> submissions;
  TeacherFailure? failure;
  TeacherFailure? submissionFailure;
  bool hold;

  int classCalls = 0;
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
