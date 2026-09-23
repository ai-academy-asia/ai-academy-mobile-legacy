import 'dart:async';

import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard_repository.dart';
import 'package:aia_mobile/features/home/domain/home_failure.dart';

/// A repository the tests drive by hand. Same shape as the other fakes:
/// either returns [dashboard], throws a chosen [HomeFailure], or — when
/// [hold] is set — waits for [release], which is how the loading state gets
/// observed while the request is still in flight.
class FakeHomeDashboardRepository implements HomeDashboardRepository {
  FakeHomeDashboardRepository({
    this.dashboard = const HomeDashboard(),
    this.failure,
    this.hold = false,
  });

  /// Returned on success.
  HomeDashboard dashboard;

  /// Thrown instead of returning, when set.
  HomeFailure? failure;

  /// When true, [getDashboard] blocks until [release] is called.
  bool hold;

  /// How many times [getDashboard] has been called — so a test can assert a
  /// retry or a pull-to-refresh actually asked again.
  int callCount = 0;

  Completer<void>? _gate;

  /// Lets a held [getDashboard] finish.
  void release() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<HomeDashboard> getDashboard() async {
    callCount++;

    if (hold) {
      _gate = Completer<void>();
      await _gate!.future;
    }

    final failure = this.failure;
    if (failure != null) throw failure;

    return dashboard;
  }
}

/// The cohort card's data, with every field defaulted so a test only states
/// what it is about.
EnrolledProgram sampleProgram({
  int cohortId = 1,
  String cohortName = 'Cohort 01',
  String courseTitle = 'AI Engineer',
  String status = 'active',
  String? uiMode = 'adult',
  ModuleProgress? progress,
  NextLesson? nextLesson,
}) => EnrolledProgram(
  cohortId: cohortId,
  cohortName: cohortName,
  courseTitle: courseTitle,
  status: status,
  uiMode: uiMode,
  progress: progress,
  nextLesson: nextLesson,
);

/// A lesson running from [start] for [hours].
NextLesson sampleLesson({DateTime? start, int hours = 2}) {
  final startsAt = start ?? DateTime(2026, 4, 8, 9);
  return NextLesson(
    startsAt: startsAt,
    endsAt: startsAt.add(Duration(hours: hours)),
  );
}
