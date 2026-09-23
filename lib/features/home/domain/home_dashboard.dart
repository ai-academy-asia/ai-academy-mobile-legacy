/// Everything the Home dashboard draws, in one value.
///
/// **Every section is nullable and the screen draws each only when its field
/// is set.** That is deliberate. The API has confirmed endpoints for the
/// student's cohorts and their schedule, and none at all for modules,
/// attendance, payments or the e-contract — see
/// `EnrolledHomeDashboardRepository`, which documents exactly which endpoint
/// each missing section is waiting on. Rather than invent those contracts, or
/// ship the reference's sample numbers ("2 of 5", "1/20", "3 хоног") as
/// constants pretending to be data, the sections they feed simply do not draw
/// until a repository can fill them. Every one of them is built, styled and
/// tested, and will appear unchanged the day a source exists.
class HomeDashboard {
  const HomeDashboard({
    this.program,
    this.contract,
    this.payment,
    this.attendance,
  });

  /// The cohort the student is studying in, with its progress and next lesson.
  final EnrolledProgram? program;

  /// Whether the student's e-contract is signed. Null when unknown.
  final ContractStatus? contract;

  /// What the student owes next. Null when unknown.
  final PaymentStatus? payment;

  /// How much of the cohort the student has attended. Null when unknown.
  final AttendanceSummary? attendance;

  /// True when there is nothing at all to show — the student is enrolled in
  /// no cohort and no other section has a source.
  bool get isEmpty =>
      program == null &&
      contract == null &&
      payment == null &&
      attendance == null;
}

/// The cohort the student is currently studying in.
class EnrolledProgram {
  const EnrolledProgram({
    required this.cohortId,
    required this.cohortName,
    required this.courseTitle,
    required this.courseSlug,
    required this.status,
    this.uiMode,
    this.progress,
    this.nextLesson,
  });

  final int cohortId;

  /// The cohort instance's own name — the caption over the title, e.g.
  /// "Cohort 01".
  final String cohortName;

  /// The programme the cohort teaches, e.g. "AI Engineer".
  final String courseTitle;

  /// The programme's `Course.slug`, read off `cohort.course.slug` — what the
  /// card's tap opens `CourseDetailScreen` with, the same `GET
  /// /courses/{slug}` key the catalog already uses.
  final String courseSlug;

  /// Raw wire value, e.g. "active". Drawn as the status pill, capitalised but
  /// never translated — `Cohort.status` has no confirmed closed set.
  final String status;

  /// The signed-in user's `profile.ui_mode` from `GET /auth/me` — e.g.
  /// "kids". Drawn as the track badge, capitalised but never mapped to a
  /// fixed set: the API confirms only one value. Null when `/auth/me` did not
  /// answer, which leaves the badge off rather than guessing.
  final String? uiMode;

  final ModuleProgress? progress;
  final NextLesson? nextLesson;
}

/// How far through the course the student is.
///
/// [percent] is the only field every source can fill: it is also the shape
/// `Enrollment.progressPct` — the one progress figure the API confirms — sends,
/// with no module count behind it. [completed]/[total] are set only when a
/// source reports an actual count (a modules endpoint, if one is ever added);
/// until then they stay null rather than being guessed at from a percentage,
/// and the screen leaves the "Modules X of Y" line off while still drawing the
/// percentage and the bar from [percent]. See `EnrolledHomeDashboardRepository`.
class ModuleProgress {
  const ModuleProgress({required this.percent, this.completed, this.total});

  /// 0–100.
  final int percent;

  final int? completed;
  final int? total;

  /// 0.0–1.0, clamped — what fills the progress bar.
  double get fraction => (percent / 100).clamp(0.0, 1.0);
}

/// When the cohort next meets.
class NextLesson {
  const NextLesson({required this.startsAt, required this.endsAt});

  final DateTime startsAt;
  final DateTime endsAt;

  /// True while the lesson is under way — what turns the attendance action on
  /// and puts the "Live" badge beside the heading. Read against an injected
  /// clock rather than [DateTime.now] so the state is testable.
  bool isLiveAt(DateTime now) =>
      !now.isBefore(startsAt) && now.isBefore(endsAt);
}

/// Whether the student has signed their e-contract.
class ContractStatus {
  const ContractStatus({required this.signed});

  final bool signed;
}

/// What the student owes next.
class PaymentStatus {
  /// The instalment's due date has passed.
  const PaymentStatus.overdue() : daysUntilDue = null;

  /// The instalment falls due in [days].
  const PaymentStatus.dueIn(int days) : daysUntilDue = days;

  /// Days left before the next instalment is due, or null when it is already
  /// late.
  final int? daysUntilDue;

  bool get isOverdue => daysUntilDue == null;
}

/// How many of the cohort's lessons the student has attended.
class AttendanceSummary {
  const AttendanceSummary({required this.attended, required this.total});

  final int attended;
  final int total;

  int get percent => total <= 0 ? 0 : ((attended / total) * 100).round();
}
