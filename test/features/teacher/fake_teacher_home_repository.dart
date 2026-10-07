import 'dart:async';

import 'package:aia_mobile/features/auth/domain/current_user.dart';
import 'package:aia_mobile/features/auth/domain/user_type.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_class.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_home_repository.dart';

/// A repository the tests drive by hand: returns [classes], throws
/// [failure], or — with [hold] — waits for [release].
class FakeTeacherHomeRepository implements TeacherHomeRepository {
  FakeTeacherHomeRepository({
    this.classes = const [],
    this.failure,
    this.hold = false,
  });

  List<TeacherClass> classes;
  TeacherFailure? failure;
  bool hold;
  int callCount = 0;

  Completer<void>? _gate;

  void release() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<List<TeacherClass>> getClasses() async {
    callCount++;
    if (hold) {
      _gate = Completer<void>();
      await _gate!.future;
    }
    final failure = this.failure;
    if (failure != null) throw failure;
    return classes;
  }
}

/// A teacher account in `/auth/me`'s verified shape — no `ui_mode`, as the
/// live teacher response has none. [actorId] is the teacher id.
CurrentUser teacherUser({int actorId = 7}) => CurrentUser(
  id: 31,
  actorId: actorId,
  actorType: 'teacher',
  email: 'teacher@example.mn',
  role: 'teacher',
  isActive: true,
  mustChangePassword: false,
  profile: const UserProfile(
    id: 31,
    firstName: 'Test',
    lastName: 'Teacher',
    phone: '99000000',
    uiMode: null,
  ),
  userType: UserType.teacher,
);
