import 'dart:async';

import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/domain/home_failure.dart';
import 'package:aia_mobile/features/home/domain/lesson_schedule.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_progress.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_progress_repository.dart';

/// A repository the tests drive by hand: returns [progress] (null = enrolled
/// in nothing), throws [failure], or — with [hold] — waits for [release], so
/// the loading state can be observed.
class FakeJuniorProgressRepository implements JuniorProgressRepository {
  FakeJuniorProgressRepository({
    JuniorProgress? progress,
    this.empty = false,
    this.failure,
    this.hold = false,
  }) : progress = empty ? null : (progress ?? figmaReferenceProgress());

  JuniorProgress? progress;
  final bool empty;
  HomeFailure? failure;
  bool hold;
  int callCount = 0;

  Completer<void>? _gate;

  void release() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<JuniorProgress?> getProgress() async {
    callCount++;
    if (hold) {
      _gate = Completer<void>();
      await _gate!.future;
    }
    final failure = this.failure;
    if (failure != null) throw failure;
    return progress;
  }
}

/// The Junior Learning Progress frame's own design state — **test data
/// only**, never rendered by the app. Every section filled, so the screen
/// draws everything the frame draws and the screenshot test can compare it
/// against the reference. The attended (1st) and missed (4th) marks exist
/// here only because the frame draws them; the API never produces them (see
/// `JuniorProgress`).
JuniorProgress figmaReferenceProgress({
  ContractStatus? contract = const ContractStatus(signed: false),
  PaymentStatus? payment = const PaymentStatus.dueIn(3),
  AttendanceSummary? attendance = const AttendanceSummary(
    attended: 1,
    total: 20,
    percent: 10,
  ),
  int? examPercent = 0,
  NextLesson? nextLesson,
  bool withNextLesson = true,
}) => JuniorProgress(
  month: DateTime(2026, 8),
  selectedDay: 7,
  days: const {
    1: JuniorDayStatus.attended,
    4: JuniorDayStatus.missed,
    8: JuniorDayStatus.lesson,
    12: JuniorDayStatus.lesson,
    16: JuniorDayStatus.lesson,
    19: JuniorDayStatus.lesson,
    24: JuniorDayStatus.lesson,
    27: JuniorDayStatus.lesson,
  },
  contract: contract,
  payment: payment,
  attendance: attendance,
  examPercent: examPercent,
  nextLesson: withNextLesson
      ? nextLesson ??
            NextLesson(
              startsAt: DateTime(2026, 8, 8, 9),
              endsAt: DateTime(2026, 8, 8, 11),
            )
      : null,
);

/// The junior test student as the API maps them, seen on 1 October 2026:
/// cohort 7 (Tue/Thu/Sat, 16 Jun – 9 Jul 2026) and its 11 attended sessions.
JuniorProgress juniorTestStudentInOctober() {
  final calendar = JuniorCalendarSource(
    schedule: LessonSchedule(
      weekdays: const {DateTime.tuesday, DateTime.thursday, DateTime.saturday},
      start: (9, 0),
      end: (12, 0),
      firstDay: DateTime(2026, 6, 16),
      lastDay: DateTime(2026, 7, 9),
    ),
    attendedDates: {
      for (final d in [16, 18, 20, 23, 25, 27, 30]) DateTime(2026, 6, d),
      for (final d in [2, 4, 7, 9]) DateTime(2026, 7, d),
    },
  );
  final october = DateTime(2026, 10);
  return JuniorProgress(
    month: october,
    selectedDay: 1,
    days: calendar.marksIn(october),
    calendar: calendar,
  );
}
