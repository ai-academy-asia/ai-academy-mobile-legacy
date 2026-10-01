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
///
/// It also holds which month the calendar shows ([displayedMonth]), which the
/// previous/next arrows page through.
class JuniorProgressController extends ChangeNotifier {
  JuniorProgressController({required this._repository});

  final JuniorProgressRepository _repository;

  bool _disposed = false;
  bool _loading = false;
  bool _hasLoadedOnce = false;
  JuniorProgress? _progress;
  String? _errorMessage;
  DateTime? _displayedMonth;

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

  // --- Calendar month -------------------------------------------------------
  //
  // Paging is local: the progress already carries everything the marks are
  // worked out from ([JuniorProgress.calendar]), so no month asks the API
  // again. Unbounded either way — no rule says where a student may look.

  /// The month the calendar shows: [JuniorProgress.month] (today's) until the
  /// student pages away, and again after every load. Null before a load.
  DateTime? get displayedMonth => _displayedMonth ?? _progress?.month;

  /// [displayedMonth]'s marks: the loaded [JuniorProgress.days] for its own
  /// month, otherwise worked out by [JuniorProgress.calendar] — empty when
  /// there is no calendar source to work them out from.
  Map<int, JuniorDayStatus> get displayedDays {
    final progress = _progress;
    final month = displayedMonth;
    if (progress == null || month == null) return const {};
    if (_sameMonth(month, progress.month)) return progress.days;
    return progress.calendar?.marksIn(month) ?? const {};
  }

  /// Today, selected, only while [displayedMonth] is today's month.
  int? get displayedSelectedDay {
    final progress = _progress;
    final month = displayedMonth;
    if (progress == null || month == null) return null;
    return _sameMonth(month, progress.month) ? progress.selectedDay : null;
  }

  void showPreviousMonth() => _page(-1);

  void showNextMonth() => _page(1);

  void _page(int delta) {
    final month = displayedMonth;
    if (month == null) return;
    // `DateTime` normalises month 0 and 13 into the neighbouring year.
    _displayedMonth = DateTime(month.year, month.month + delta);
    _notify();
  }

  static bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  /// Fetches the progress. Safe to call again — retry.
  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    // Every load — retry included — opens on its own (today's) month.
    _displayedMonth = null;
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
