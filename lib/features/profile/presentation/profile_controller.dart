import 'package:flutter/foundation.dart';

import '../../auth/domain/current_user.dart';
import '../../auth/domain/current_user_failure.dart';
import '../../auth/domain/current_user_repository.dart';
import 'profile_strings.dart';

/// Loads the signed-in user's own account for the profile header.
///
/// Same shape as `EnrolledCohortsController`: a plain [ChangeNotifier], a
/// `_disposed` guard, one fixed string per [CurrentUserFailureKind] (via
/// [ProfileStrings.messageFor]), and [hasLoadedOnce] that says whether the
/// first fetch has actually completed.
class ProfileController extends ChangeNotifier {
  ProfileController({required this._repository});

  final CurrentUserRepository _repository;

  bool _disposed = false;
  bool _loading = false;
  bool _hasLoadedOnce = false;
  CurrentUser? _user;
  String? _errorMessage;

  bool get loading => _loading;

  /// True once a fetch has *completed*, successfully or not.
  bool get hasLoadedOnce => _hasLoadedOnce;

  /// Set only on a successful fetch. Cleared as soon as another fetch fails.
  CurrentUser? get user => _user;

  /// Set only when the most recent fetch failed. Cleared as soon as another
  /// fetch starts.
  String? get errorMessage => _errorMessage;

  /// Fetches the signed-in user's account. Safe to call again — retry —
  /// while a previous call is still in flight.
  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    _notify();

    try {
      _user = await _repository.getCurrentUser();
    } on CurrentUserFailure catch (failure) {
      _user = null;
      _errorMessage = ProfileStrings.messageFor(failure.kind);
    } catch (_) {
      _user = null;
      _errorMessage = ProfileStrings.unexpectedError;
    } finally {
      _loading = false;
      _hasLoadedOnce = true;
      _notify();
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
