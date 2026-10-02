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

  /// Thrown by [signOut] instead of completing, when set.
  AuthFailure? signOutFailure;

  /// Every refresh token [signOut] was asked to revoke, in order.
  final List<String> signOutCalls = [];

  /// When true, [signOut] blocks until [releaseSignOut] is called — how a
  /// test holds a sign-out in flight.
  bool holdSignOut = false;

  Completer<void>? _signOutGate;

  /// Lets a held [signOut] finish.
  void releaseSignOut() {
    final gate = _signOutGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

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

  @override
  Future<void> signOut({required String refreshToken}) async {
    signOutCalls.add(refreshToken);
    if (holdSignOut) {
      _signOutGate = Completer<void>();
      await _signOutGate!.future;
    }
    final failure = signOutFailure;
    if (failure != null) throw failure;
  }
}
