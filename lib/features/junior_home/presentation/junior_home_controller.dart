import 'package:flutter/foundation.dart';

import '../../course_learning/domain/course_learning_failure.dart';
import '../domain/junior_home_repository.dart';
import '../domain/junior_learning_map.dart';
import 'junior_home_strings.dart';

/// Loads the Junior learning map.
///
/// The house controller shape, matching `HomeController` field for field: a
/// plain [ChangeNotifier], a `_disposed` guard, [hasLoadedOnce] so [isEmpty]
/// cannot answer true before a fetch has finished, and one fixed string per
/// [CourseLearningFailureKind] via [JuniorHomeStrings.messageFor]. No new
/// state architecture — this feature had no controller at all while its data
/// was a constant.
class JuniorHomeController extends ChangeNotifier {
  JuniorHomeController({required this._repository});

  final JuniorHomeRepository _repository;

  bool _disposed = false;
  bool _loading = false;
  bool _hasLoadedOnce = false;
  JuniorLearningMap? _map;
  String? _errorMessage;

  bool get loading => _loading;

  /// True once a fetch has *completed*, successfully or not.
  bool get hasLoadedOnce => _hasLoadedOnce;

  /// Null until the first fetch succeeds, and again after one fails.
  JuniorLearningMap? get map => _map;

  /// Set only when the most recent fetch failed. Cleared as soon as another
  /// fetch starts, so a retry never shows the previous attempt's message.
  String? get errorMessage => _errorMessage;

  /// True once a fetch has completed and left nothing to draw — the student
  /// is enrolled in no course. Not an error: the repository answers null.
  bool get isEmpty =>
      _hasLoadedOnce && !_loading && _errorMessage == null && _map == null;

  /// Fetches the map. Safe to call again — retry.
  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    _notify();

    try {
      _map = await _repository.getLearningMap();
    } on CourseLearningFailure catch (failure) {
      _map = null;
      _errorMessage = JuniorHomeStrings.messageFor(failure.kind);
    } catch (_) {
      _map = null;
      _errorMessage = JuniorHomeStrings.unexpectedError;
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
