import '../../home/domain/home_dashboard.dart';

/// What a junior student's "Сурлагын явц" (learning progress) screen shows.
///
/// Built from the same confirmed sources as the adult dashboard — see
/// `ApiJuniorProgressRepository` — and reusing its models, so a payment, an
/// attendance summary and a next lesson mean exactly what they mean on adult
/// Home. **Every backend section is nullable, and the screen leaves out what
/// is null** rather than drawing a stand-in value:
///
///  * [contract] — always null today. No endpoint reports whether a student
///    signed an e-contract (BACKEND GAP), so the banner does not draw.
///  * [payment] — `GET /me/ledger`, by the adult dashboard's rule: null when
///    nothing is owed, no due date is set, or the call failed.
///  * [attendance] — `GET /me/attendance` `summary`; null when the call
///    failed.
///  * [examPercent] — always null today. No exam, quiz-result or grade
///    endpoint exists (BACKEND GAP), and none is worked out from assignment
///    or quiz scores.
///  * [nextLesson] — derived from the cohort's confirmed schedule; null when
///    it has none or has ended.
///
/// The calendar is the month on the device clock, today selected, with the
/// cohort's scheduled lesson days marked, and a day with a `present` or
/// `late` session in `GET /me/attendance` `sessions` marked attended instead.
/// **No day is ever marked missed**: no missed/absent status has been
/// confirmed (BACKEND GAP), and calling a past lesson day "missed" because no
/// session is listed would be inventing a rule.
class JuniorProgress {
  const JuniorProgress({
    required this.month,
    required this.selectedDay,
    this.days = const {},
    this.contract,
    this.payment,
    this.attendance,
    this.examPercent,
    this.nextLesson,
  });

  final ContractStatus? contract;
  final PaymentStatus? payment;
  final AttendanceSummary? attendance;
  final int? examPercent;
  final NextLesson? nextLesson;

  /// The calendar's month. Only its year and month are read.
  final DateTime month;

  /// The highlighted day of [month].
  final int selectedDay;

  /// The marked days of [month], by day of the month. A day absent from this
  /// map is drawn neutral.
  final Map<int, JuniorDayStatus> days;
}

/// A calendar day's mark — the three the frame's legend names.
///
/// The backend feeds [lesson] (the cohort schedule) and [attended] (an
/// attended session) — see [JuniorProgress]. [missed] is drawn by the
/// calendar and its legend, and waits on a confirmed missed/absent status.
enum JuniorDayStatus {
  /// "Хичээлтэй өдөр" — a scheduled lesson.
  lesson,

  /// "Хичээлээ тасалсан" — a lesson the student missed.
  missed,

  /// "Хичээлдээ суусан" — a lesson the student attended.
  attended,
}
