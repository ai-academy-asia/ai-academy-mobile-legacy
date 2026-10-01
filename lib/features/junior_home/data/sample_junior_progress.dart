import '../domain/junior_progress.dart';

/// The Junior "Сурлагын явц" frame's own design state — **not** student data.
///
/// Every value is read off the reference export, because no confirmed
/// endpoint reports any of it (see [JuniorProgress]). The calendar is the
/// real August 2026 — `JuniorProgressCalendar` lays the month out from the
/// date itself — with the frame's marks on the day numbers the frame puts
/// them on.
abstract final class SampleJuniorProgress {
  static final JuniorProgress reference = JuniorProgress(
    contractSigned: false,
    paymentDaysLeft: 3,
    attendedLessons: 1,
    totalLessons: 20,
    attendancePercent: 10,
    examPercent: 0,
    nextLessonStart: DateTime(2026, 8, 8, 9),
    nextLessonEnd: DateTime(2026, 8, 8, 11),
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
  );
}
