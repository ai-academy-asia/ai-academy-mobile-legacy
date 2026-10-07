import 'package:flutter/foundation.dart';

import '../domain/teacher_class.dart';
import '../domain/teacher_failure.dart';
import '../domain/teacher_schedule_repository.dart';
import '../domain/teacher_session.dart';
import 'teacher_home_strings.dart';

/// Loads Teacher Schedule's week (Issue #231).
///
/// Same shape as `TeacherHomeController`: a plain [ChangeNotifier], a
/// `_disposed` guard, one fixed string per [TeacherFailureKind] and a
/// single-flight [load].
///
/// A week is the teacher's classes (`/teachers/{id}/schedule`) plus each
/// class's real sessions in that week (`/teacher/cohorts/{id}/sessions`).
/// Only cohorts whose `start_date`…`end_date` reach into the week are asked,
/// so a week costs one request per running class, not one per session.
/// Choosing a day in another week loads that week, reusing the classes.
class TeacherScheduleController extends ChangeNotifier {
  TeacherScheduleController({
    required this._repository,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _selectedDay = dateOnly(_clock());
  }

  final TeacherScheduleRepository _repository;

  /// Decides which day is "today" and which sessions are over. Injected in
  /// tests.
  final DateTime Function() _clock;

  late DateTime _selectedDay;
  bool _disposed = false;
  bool _loading = false;
  bool _hasLoadedOnce = false;
  String? _errorMessage;

  /// The classes, kept across week changes; [load] reads them again.
  List<TeacherClass>? _classes;
  bool _classesStale = true;

  /// The sessions of [_loadedWeek], earliest first.
  List<ScheduledSession>? _sessions;
  DateTime? _loadedWeek;

  DateTime now() => _clock();

  /// The day the header names and the strip circles. Today at first.
  DateTime get selectedDay => _selectedDay;

  /// The Sunday starting the week on screen.
  DateTime get weekStart => weekStartOf(_selectedDay);

  /// The week's seven days, Sunday first.
  List<DateTime> get weekDays => [
    for (var i = 0; i < DateTime.daysPerWeek; i++)
      DateTime(weekStart.year, weekStart.month, weekStart.day + i),
  ];

  bool get loading => _loading;

  /// True once a fetch has *completed*, successfully or not.
  bool get hasLoadedOnce => _hasLoadedOnce;

  /// The week on screen's sessions. Null until that week has loaded, and
  /// again after its fetch failed.
  List<ScheduledSession>? get sessions =>
      _loadedWeek == weekStart ? _sessions : null;

  /// Set only when the most recent fetch failed. Cleared as soon as another
  /// fetch starts.
  String? get errorMessage => _errorMessage;

  /// True once the week on screen has loaded and holds no session.
  bool get isEmpty =>
      !_loading && _errorMessage == null && (sessions?.isEmpty ?? false);

  Future<void>? _inFlight;

  /// Fetches the classes and the week on screen. Safe to call again — retry
  /// and pull to refresh. A call made while a fetch is running joins it.
  Future<void> load() {
    _classesStale = true;
    return _loadWeek();
  }

  /// Makes [day] the selected day. A day in another week loads that week.
  void selectDay(DateTime day) {
    final next = dateOnly(day);
    if (next == _selectedDay) return;
    _selectedDay = next;
    _notify();
    if (_loadedWeek != weekStart) _loadWeek();
  }

  Future<void> _loadWeek() =>
      _inFlight ??= _fetch().whenComplete(() => _inFlight = null);

  Future<void> _fetch() async {
    _loading = true;
    _errorMessage = null;
    _notify();

    try {
      // A day chosen in another week while this ran is fetched before
      // finishing, so a stale week never lands on screen.
      DateTime week;
      List<ScheduledSession> sessions;
      do {
        week = weekStart;
        if (_classesStale || _classes == null) {
          _classes = await _repository.getClasses();
          _classesStale = false;
        }
        sessions = await _sessionsOfWeek(_classes!, week);
      } while (week != weekStart);
      _sessions = sessions;
      _loadedWeek = week;
    } on TeacherFailure catch (failure) {
      _failed(failure.kind);
    } catch (_) {
      _failed(TeacherFailureKind.unexpected);
    } finally {
      _loading = false;
      _hasLoadedOnce = true;
      _notify();
    }
  }

  void _failed(TeacherFailureKind kind) {
    _sessions = null;
    _loadedWeek = null;
    _errorMessage = TeacherHomeStrings.messageFor(kind);
  }

  Future<List<ScheduledSession>> _sessionsOfWeek(
    List<TeacherClass> classes,
    DateTime week,
  ) async {
    final lastDay = DateTime(week.year, week.month, week.day + 6);
    final running = [
      for (final teacherClass in classes)
        if (_runsDuring(teacherClass, week, lastDay)) teacherClass,
    ];

    final perClass = await Future.wait([
      for (final teacherClass in running)
        _repository.getSessions(
          cohortId: teacherClass.cohort.id,
          from: week,
          // Whether `to` is inclusive is not confirmed: ask one day past the
          // week and keep only the week's own days below.
          to: lastDay.add(const Duration(days: 1)),
        ),
    ]);

    final sessions = <ScheduledSession>[
      for (final (index, list) in perClass.indexed)
        for (final session in list)
          if (!session.date.isBefore(week) && !session.date.isAfter(lastDay))
            ScheduledSession(session: session, teacherClass: running[index]),
    ];
    sessions.sort((a, b) => a.session.startsAt.compareTo(b.session.startsAt));
    return sessions;
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

/// Whether the class's `start_date`…`end_date` window reaches into
/// [first]…[last]. An end that does not parse leaves that side open, as
/// `LessonSchedule` treats it.
bool _runsDuring(TeacherClass teacherClass, DateTime first, DateTime last) {
  final starts = DateTime.tryParse(teacherClass.cohort.startDate);
  final ends = DateTime.tryParse(teacherClass.cohort.endDate);
  if (starts != null && dateOnly(starts).isAfter(last)) return false;
  if (ends != null && dateOnly(ends).isBefore(first)) return false;
  return true;
}
