import 'package:flutter/foundation.dart';

import '../domain/teacher_class.dart';
import '../domain/teacher_failure.dart';
import '../domain/teacher_home_repository.dart';
import 'teacher_home_strings.dart';

/// Loads Teacher Home's classes (Issue #229).
///
/// Same shape as `HomeController`: a plain [ChangeNotifier], a `_disposed`
/// guard, one fixed string per [TeacherFailureKind], a single-flight [load],
/// and [isEmpty] that only answers true once a fetch has completed.
class TeacherHomeController extends ChangeNotifier {
  TeacherHomeController({required this._repository, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final TeacherHomeRepository _repository;

  /// Decides which day "today" is. Injected in tests.
  final DateTime Function() _clock;

  bool _disposed = false;
  bool _loading = false;
  bool _hasLoadedOnce = false;
  List<TeacherClass>? _classes;
  String? _errorMessage;

  bool get loading => _loading;

  /// True once a fetch has *completed*, successfully or not.
  bool get hasLoadedOnce => _hasLoadedOnce;

  /// Every class the teacher teaches. Null until the first fetch succeeds,
  /// and again after one fails.
  List<TeacherClass>? get classes => _classes;

  /// The classes that meet today, earliest first — what the screen draws.
  /// Re-read against the clock on every call, so a screen left open past
  /// midnight shows the new day's classes on its next build.
  List<TeacherClass> get todaysClasses =>
      classesMeetingOn(_classes ?? const [], _clock());

  /// Set only when the most recent fetch failed. Cleared as soon as another
  /// fetch starts.
  String? get errorMessage => _errorMessage;

  /// True once a fetch has completed and no class meets today.
  bool get isEmpty =>
      _hasLoadedOnce &&
      !_loading &&
      _errorMessage == null &&
      _classes != null &&
      todaysClasses.isEmpty;

  /// The fetch in flight, so a second [load] joins it rather than starting
  /// an overlapping request.
  Future<void>? _inFlight;

  /// Fetches the classes. Safe to call again — retry, pull to refresh, or a
  /// tap on the header logo. A call made while a fetch is already running
  /// joins that fetch instead of sending another request.
  Future<void> load() =>
      _inFlight ??= _fetch().whenComplete(() => _inFlight = null);

  Future<void> _fetch() async {
    _loading = true;
    _errorMessage = null;
    _notify();

    try {
      _classes = await _repository.getClasses();
    } on TeacherFailure catch (failure) {
      _classes = null;
      _errorMessage = TeacherHomeStrings.messageFor(failure.kind);
    } catch (_) {
      _classes = null;
      _errorMessage = TeacherHomeStrings.messageFor(
        TeacherFailureKind.unexpected,
      );
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
