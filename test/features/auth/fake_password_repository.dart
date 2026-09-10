import 'dart:async';

import 'package:aia_mobile/features/auth/domain/auth_failure.dart';
import 'package:aia_mobile/features/auth/domain/password_repository.dart';

/// A password repository the tests drive by hand.
///
/// Mirrors `FakeAuthRepository`: completes, throws a chosen [AuthFailure], or —
/// when [hold] is set — waits for [release], which is how the submitting state
/// gets observed while the request is still in flight.
class FakePasswordRepository implements PasswordRepository {
  FakePasswordRepository({this.failure, this.hold = false});

  /// Thrown instead of completing, when set.
  AuthFailure? failure;

  /// When true, [changePassword] blocks until [release] is called.
  bool hold;

  /// Every call, in order.
  final List<({String currentPassword, String newPassword})> calls = [];

  Completer<void>? _gate;

  /// Lets a held [changePassword] finish.
  void release() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    calls.add((currentPassword: currentPassword, newPassword: newPassword));

    if (hold) {
      _gate = Completer<void>();
      await _gate!.future;
    }

    final failure = this.failure;
    if (failure != null) throw failure;
  }
}
