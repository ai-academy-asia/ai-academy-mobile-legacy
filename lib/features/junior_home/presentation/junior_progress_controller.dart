import 'package:flutter/foundation.dart';

import '../../home/domain/home_failure.dart';
import '../../home/presentation/home_strings.dart';
import '../domain/junior_progress.dart';
import '../domain/junior_progress_repository.dart';

/// Loads the junior student's learning progress.
///
/// `JuniorHomeController`'s shape, field for field: a plain [ChangeNotifier],
/// a `_disposed` guard, [hasLoadedOnce] so [isEmpty] cannot answer true
/// before a fetch has finished, and one fixed string per failure kind. The
/// failures are the dashboard's [HomeFailure]s, so the strings are
/// [HomeStrings.messageFor]'s — the same wording Junior Home and adult Home
/// already show for the same situations.
class JuniorProgressController extends ChangeNotifier {
  JuniorProgressController({required this._repository});

  final JuniorProgressRepository _repository;

  bool _disposed = false;
  bool _loading = false;
  bool _hasLoadedOnce = false;
  JuniorProgress? _progress;
  String? _errorMessage;

  bool get loading => _loading;

  /// True once a fetch has *completed*, successfully or not.
  bool get hasLoadedOnce => _hasLoadedOnce;

  /// Null until the first fetch succeeds, and again after one fails.
  JuniorProgress? get progress => _progress;

  /// Set only when the most recent fetch failed. Cleared as soon as another
  /// fetch starts, so a retry never shows the previous attempt's message.
  String? get errorMessage => _errorMessage;

  /// True once a fetch has completed and left nothing to draw — the student
  /// is enrolled in nothing. Not an error: the repository answers null.
  bool get isEmpty =>
      _hasLoadedOnce && !_loading && _errorMessage == null && _progress == null;

  /// Fetches the progress. Safe to call again — retry.
  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    _notify();

    try {
      _progress = await _repository.getProgress();
    } on HomeFailure catch (failure) {
      _progress = null;
      _errorMessage = HomeStrings.messageFor(failure.kind);
    } catch (_) {
      _progress = null;
      _errorMessage = HomeStrings.unexpectedError;
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
