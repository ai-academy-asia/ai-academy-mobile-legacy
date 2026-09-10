import 'dart:async';

import 'package:aia_mobile/features/auth/domain/auth_failure.dart';
import 'package:aia_mobile/features/auth/domain/auth_repository.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';

/// A repository the tests drive by hand.
///
/// Either completes with a session, throws a chosen [AuthFailure], or — when
/// [hold] is set — waits for [release], which is how the loading state gets
/// observed while the request is still in flight.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.failure, this.session, this.hold = false});

  /// Thrown instead of returning a session, when set.
  AuthFailure? failure;

  /// Returned on success. Defaults to a token-bearing session.
  AuthSession? session;

  /// When true, [signIn] blocks until [release] is called.
  bool hold;

  /// Every call, in order — so a test can assert what was actually sent.
  final List<({String email, String password})> calls = [];

  Completer<void>? _gate;

  /// Lets a held [signIn] finish.
  void release() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<AuthSession> signIn({required String email, required String password}) async {
    calls.add((email: email, password: password));

    if (hold) {
      _gate = Completer<void>();
      await _gate!.future;
    }

    final failure = this.failure;
    if (failure != null) throw failure;

    return session ?? const AuthSession(accessToken: 'test-token');
  }
}
