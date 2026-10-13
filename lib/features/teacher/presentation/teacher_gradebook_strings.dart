import '../domain/teacher_failure.dart';
import 'teacher_home_strings.dart';
import 'teacher_schedule_strings.dart';

/// Every word on Teacher Programs — formerly the Gradebook (Issues #233,
/// #390) — read off the updated Figma frames (`Sign in - 33/34/35/40/41/42`,
/// `Contract(2)`, `Close(1)`) and carried through verbatim, mixed languages
/// included. Lines no frame draws are marked `PRODUCT DECISION`.
abstract final class TeacherGradebookStrings {
  /// The tab and screen title (Issue #390) — formerly "Дүнгийн хуудас".
  static const String title = 'Хөтөлбөрүүд';

  /// No class to list. Not drawn by the reference — Teacher Home's wording.
  static const String empty = TeacherHomeStrings.empty;

  // --- Program card --------------------------------------------------------

  static const String totalStudents = 'Нийт сурагч';
  static const String details = 'Дэлгэрэнгүй';

  // --- Cohort action sheet --------------------------------------------------

  static const String announce = 'Зар тараах';
  static const String studentsInfo = 'Сурагчдын мэдээлэл';

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
  static const String announceUnavailable =
      'Багш зар тараах боломж одоогоор серверт нээгдээгүй байна. Зар '
      'илгээгдэхгүй.';

  // --- Student list (`Sign in - 34`) ----------------------------------------

  static const String studentsHeading = 'Сурагчид';

  /// No student enrolled. Not drawn by the reference.
  static const String noStudents = 'Энэ ангид бүртгэлтэй сурагч алга.';

  /// A count badge: "9+" past nine, as the reference draws it.
  static String badge(int count) => count > 9 ? '9+' : '$count';

  /// Read out for a row's badge.
  static String pendingLabel(int count) =>
      '$count даалгавар дүгнэгдэхийг хүлээж байна';

  // --- Student detail (`Sign in - 35/40/41/42`) ----------------------------

  static const String attendance = 'Хичээлийн ирц';
  static const String examScore = 'Шалгалтын дүн';

  /// A figure no confirmed endpoint supplies (BACKEND GAP).
  static const String noFigure = '—';

  /// The assignment selector's caption. The frames say "Modules N", but no
  /// field ties an assignment to its module (BACKEND GAP, Issue #390): the
  /// assignment's place in the class's list is shown instead.
  static String assignmentCaption(int number) => 'Даалгавар $number';

  /// The class has no assignment yet. Not drawn by the reference.
  static const String noAssignments = 'Энэ ангид даалгавар алга.';

  /// The selected assignment has no submission from this student.
  static const String notSubmitted = 'Энэ даалгаврыг илгээгээгүй байна.';

  /// A submission with no note. Not drawn by the reference.
  static const String noNote = 'Тайлбар бичээгүй.';

  static const String roleStudent = 'Student';
  static const String roleTeacher = TeacherScheduleStrings.teacherRole;

  /// The reply composer's label and button, as the frames draw them.
  static const String replyLabel = 'Тайлбар';
  static const String submit = 'Submit';

  /// Read out for the reply's edit control.
  static const String editReply = 'Хариултыг засах';

  /// The score a review must carry when the assignment has a maximum — no
  /// frame draws it (PRODUCT DECISION), but the review is refused without it.
  static String scoreLabel(num max) => 'Оноо (0–${_number(max)})';
  static String scoreInvalid(num max) =>
      '0-ээс ${_number(max)} хүртэлх оноо оруулна уу';

  /// Why a reply was not saved.
  static String replyFailed(TeacherFailure failure) => switch (failure.code) {
    'feedback_required' => 'Хариултаа бичнэ үү.',
    'feedback_too_long' => 'Хариулт 5000 тэмдэгтээс хэтэрсэн байна.',
    'invalid_score' => 'Оноо буруу байна.',
    'submission_not_found' => 'Энэ илгээлт олдсонгүй.',
    _ => TeacherHomeStrings.messageFor(failure.kind),
  };

  /// "Today, 14:20" on [now]'s calendar day, "08/06, 14:20" otherwise — the
  /// same rule Course Learning's feedback timestamps follow.
  static String timestamp(DateTime local, {required DateTime now}) {
    String two(int value) => value.toString().padLeft(2, '0');
    final time = '${two(local.hour)}:${two(local.minute)}';
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    return sameDay
        ? 'Today, $time'
        : '${two(local.month)}/${two(local.day)}, $time';
  }

  static String _number(num value) =>
      value == value.roundToDouble() ? '${value.toInt()}' : '$value';
}
