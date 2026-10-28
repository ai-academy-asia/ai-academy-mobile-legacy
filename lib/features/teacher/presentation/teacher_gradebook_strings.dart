import '../../../core/locale/app_format.dart';
import '../../../core/locale/l10n.dart';
import '../domain/teacher_failure.dart';
import 'teacher_home_strings.dart';
import 'teacher_schedule_strings.dart';

/// Every word on Teacher Programs — formerly the Gradebook (Issues #233,
/// #390) — read off the updated Figma frames (`Sign in - 33/34/35/40/41/42`,
/// `Contract(2)`, `Close(1)`) and carried through verbatim, mixed languages
/// included. Lines no frame draws are marked `PRODUCT DECISION`. In the
/// selected language since Issue #551 (L19): the Mongolian is unchanged, the
/// English approved copy; the frames' own English ("Student", "Submit", the
/// composer's hint and placeholder) reads the same in both.
abstract final class TeacherGradebookStrings {
  /// The tab and screen title (Issue #390) — formerly "Дүнгийн хуудас" —
  /// the bottom bar's own "Хөтөлбөрүүд" / "Programs" (Issue #511).
  static String get title => L10n.current.navPrograms;

  /// No class to list. Not drawn by the reference — Teacher Home's wording,
  /// and so in the selected language since Issue #547, ahead of the rest of
  /// this screen.
  static String get empty => TeacherHomeStrings.empty;

  // --- Program card --------------------------------------------------------

  static String get totalStudents => L10n.current.teacherProgramsTotalStudents;
  static String get details => L10n.current.teacherProgramsDetails;

  // --- Cohort action sheet --------------------------------------------------

  static String get announce => L10n.current.teacherProgramsAnnounce;
  static String get studentsInfo => L10n.current.teacherProgramsStudentsInfo;

  // --- Announcement composer (`Close(1)`) ----------------------------------

  /// The frame's own hint and placeholder, verbatim — they read like copy
  /// carried over from a rating sheet (`PRODUCT DECISION` on final wording).
  static const String announceHint = 'Provide some details about your score';
  static const String announcePlaceholder = 'What do you like or dislike?';
  static const int announceMaxLength = 100;
  static String counter(int length, int max) => '$length/$max';

  /// Why Submit stays off: the only announcement endpoint is staff-only
  /// (`POST /admin/notifications`, `cohort:manage`) — a teacher account is
  /// refused (BACKEND GAP, Issue #390). PRODUCT DECISION on the wording.
  static String get announceUnavailable =>
      L10n.current.teacherProgramsAnnounceUnavailable;

  // --- Student list (`Sign in - 34`) ----------------------------------------

  static String get studentsHeading => L10n.current.teacherStudentsHeading;

  /// No student enrolled. Not drawn by the reference.
  static String get noStudents => L10n.current.teacherProgramsNoStudents;

  /// A count badge: "9+" past nine, as the reference draws it.
  static String badge(int count) => count > 9 ? '9+' : '$count';

  /// Read out for a row's badge.
  static String pendingLabel(int count) =>
      L10n.current.teacherProgramsPendingLabel(count);

  // --- Student detail (`Sign in - 35/40/41/42`) ----------------------------

  static String get attendance => L10n.current.teacherProgramsAttendance;
  static String get examScore => L10n.current.teacherProgramsExamScore;

  /// A figure no confirmed endpoint supplies (BACKEND GAP).
  static const String noFigure = '—';

  /// The assignment selector's caption: the assignment's place in the
  /// class's list. The frames say "Modules N", but assignments stay one
  /// simple list, not grouped by module (PRODUCT DECISION, Issue #394).
  static String assignmentCaption(int number) =>
      L10n.current.teacherProgramsAssignmentCaption(number);

  /// The class has no assignment yet. Not drawn by the reference.
  static String get noAssignments => L10n.current.teacherProgramsNoAssignments;

  /// The selected assignment has no submission from this student.
  static String get notSubmitted => L10n.current.teacherProgramsNotSubmitted;

  /// A submission with no note. Not drawn by the reference.
  static String get noNote => L10n.current.teacherProgramsNoNote;

  static const String roleStudent = 'Student';
  static const String roleTeacher = TeacherScheduleStrings.teacherRole;

  /// The reply composer's label and button, as the frames draw them.
  static String get replyLabel => L10n.current.teacherProgramsReplyLabel;
  static const String submit = 'Submit';

  /// Read out for the reply's edit control.
  static String get editReply => L10n.current.teacherProgramsEditReply;

  /// The score a review must carry when the assignment has a maximum — no
  /// frame draws it (PRODUCT DECISION), but the review is refused without it.
  static String scoreLabel(num max) =>
      L10n.current.teacherProgramsScoreLabel(_number(max));
  static String scoreInvalid(num max) =>
      L10n.current.teacherProgramsScoreInvalid(_number(max));

  /// Why a reply was not saved.
  static String replyFailed(TeacherFailure failure) => switch (failure.code) {
    'feedback_required' => L10n.current.teacherProgramsFeedbackRequired,
    'feedback_too_long' => L10n.current.teacherProgramsFeedbackTooLong,
    'invalid_score' => L10n.current.teacherProgramsInvalidScore,
    'submission_not_found' => L10n.current.teacherProgramsSubmissionNotFound,
    _ => TeacherHomeStrings.messageFor(failure.kind),
  };

  /// "Today, 14:20" on [now]'s calendar day, "08/06, 14:20" otherwise — the
  /// same rule Course Learning's feedback timestamps follow; "Aug 6, 14:20"
  /// in English ([AppFormat.todayOrDate], Issue #505).
  static String timestamp(DateTime local, {required DateTime now}) =>
      AppFormat.todayOrDate(local, now: now);

  static String _number(num value) =>
      value == value.roundToDouble() ? '${value.toInt()}' : '$value';
}
