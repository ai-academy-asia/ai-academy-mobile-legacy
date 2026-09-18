import 'dart:async';

import 'package:aia_mobile/features/auth/domain/current_user.dart';
import 'package:aia_mobile/features/auth/domain/current_user_failure.dart';
import 'package:aia_mobile/features/auth/domain/current_user_repository.dart';

/// A repository the tests drive by hand. Same shape as
/// `FakeEnrolledCohortsRepository`: either returns [user], throws a chosen
/// [CurrentUserFailure], or — when [hold] is set — waits for [release], which
/// is how the loading state gets observed while the request is still in
/// flight.
class FakeCurrentUserRepository implements CurrentUserRepository {
  FakeCurrentUserRepository({this.user = _defaultUser, this.failure, this.hold = false});

  /// Returned on success.
  CurrentUser user;

  /// Thrown instead of returning, when set.
  CurrentUserFailure? failure;

  /// When true, [getCurrentUser] blocks until [release] is called.
  bool hold;

  /// How many times [getCurrentUser] has been called — so a test can assert a
  /// retry actually asked again.
  int callCount = 0;

  Completer<void>? _gate;

  /// Lets a held [getCurrentUser] finish.
  void release() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<CurrentUser> getCurrentUser() async {
    callCount++;

    if (hold) {
      _gate = Completer<void>();
      await _gate!.future;
    }

    final failure = this.failure;
    if (failure != null) throw failure;

    return user;
  }
}

const _defaultUser = CurrentUser(
  id: 9,
  actorId: 5,
  actorType: 'student',
  email: 'crud-test-student-20260909@example.mn',
  role: 'student',
  isActive: true,
  mustChangePassword: true,
  profile: UserProfile(
    id: 5,
    firstName: 'CRUD',
    lastName: 'TestStudent',
    phone: '99123456',
    uiMode: 'kids',
  ),
);
