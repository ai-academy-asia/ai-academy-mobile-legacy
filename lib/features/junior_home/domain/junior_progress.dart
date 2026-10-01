/// What a junior student's "Сурлагын явц" (learning progress) screen shows.
///
/// **BACKEND GAP.** No confirmed endpoint reports any of this for a junior
/// student — attendance per day, an exam score, the next payment, the
/// e-contract state — which is the same gap the adult dashboard leaves its
/// payment, attendance and contract sections empty over (see
/// `enrolled_home_dashboard_repository.dart`). Until one is confirmed, the
/// screen renders `SampleJuniorProgress.reference`, the Figma frame's own
/// design state, and nothing here is read from or sent to the API.
///
/// The figures are carried as the design states them rather than derived
/// from one another: the frame draws "1/20 · 10%", and computing the percent
/// from the count would be inventing a rule the design does not state.
class JuniorProgress {
  const JuniorProgress({
    required this.contractSigned,
    required this.paymentDaysLeft,
    required this.attendedLessons,
    required this.totalLessons,
    required this.attendancePercent,
    required this.examPercent,
    required this.nextLessonStart,
    required this.nextLessonEnd,
    required this.month,
    required this.selectedDay,
    required this.days,
  });

  /// False shows the unsigned-contract banner.
  final bool contractSigned;

  /// Days until the next payment is due.
  final int paymentDaysLeft;

  final int attendedLessons;
  final int totalLessons;
  final int attendancePercent;
  final int examPercent;

  final DateTime nextLessonStart;
  final DateTime nextLessonEnd;

  /// The calendar's month. Only its year and month are read.
  final DateTime month;

  /// The highlighted day of [month].
  final int selectedDay;

  /// The marked days of [month], by day of the month. A day absent from this
  /// map is drawn neutral.
  final Map<int, JuniorDayStatus> days;
}

/// A calendar day's mark — the three the frame's legend names.
enum JuniorDayStatus {
  /// "Хичээлтэй өдөр" — a scheduled lesson.
  lesson,

  /// "Хичээлээ тасалсан" — a lesson the student missed.
  missed,

  /// "Хичээлдээ суусан" — a lesson the student attended.
  attended,
}
