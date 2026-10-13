import '../../home/presentation/home_strings.dart';
import 'teacher_home_strings.dart';

/// Every word on Teacher Schedule, its session sheets and the "Багш нар"
/// screen (Issue #231), read off the four references. They mix languages as
/// Teacher Home's does ("Teacher" under a Mongolian name) and are carried
/// through verbatim.
abstract final class TeacherScheduleStrings {
  /// The header's selected date — "11-р сарын 17".
  static String headerDate(DateTime day) => '${day.month}-р сарын ${day.day}';

  /// The strip's weekday row, Sunday first: Ням, Даваа, Мягмар, Лхагва,
  /// Пүрэв, Баасан, Бямба. The reference's own row is a mock-up that
  /// repeats Ня and skips Ба, so the real seven are spelled out here.
  static const List<String> weekdays = [
    'Ня',
    'Да',
    'Мя',
    'Лх',
    'Пү',
    'Ба',
    'Бя',
  ];

  /// Accessibility label for the header's date control.
  static const String pickDate = 'Огноо сонгох';

  /// Accessibility label for the header's bell, the student Home's own. It
  /// opens the shared Notification Center (Issue #246).
  static const String notifications = HomeStrings.notifications;

  /// No session in the week. Not drawn by the reference — Teacher Home's
  /// wording for the same state.
  static const String empty = TeacherHomeStrings.empty;

  /// No session on the selected day, in the large-text day list (Issue
  /// #357). The week grid keeps [empty].
  static const String emptyDay = 'Энэ өдөр хичээл байхгүй байна.';

  /// Accessibility labels for the day list's previous- and next-day
  /// controls (Issue #357).
  static const String previousDay = 'Өмнөх өдөр';
  static const String nextDay = 'Дараагийн өдөр';

  /// A finished session in the day list (Issue #357) — said in words, not
  /// only by the muted card.
  static const String finished = 'Дууссан';

  /// The upcoming session sheet's actions.
  static const String changeTime = 'Цаг солих';

  /// Opens attendance registration (Issue #374) — live only on the
  /// session's date in Ulaanbaatar, drawn disabled any other day.
  static const String registerAttendance = 'Ирц бүртгэх';

  /// Under the held session's "14 / 24".
  static const String attendedCaption = 'оюутан ирцэд бүртгэгдсэн';

  // --- "Багш нар" -----------------------------------------------------------

  static const String teachersTitle = 'Багш нар';

  /// The line under each teacher's name.
  static const String teacherRole = 'Teacher';

  static const String requestSend = 'Хүсэлт илгээх';
  static const String requestPending = 'Хүлээгдэж байна';
  static const String requestRejected = 'Татгалзсан';

  // --- The request's sheets (Issue #372) -----------------------------------
  //
  // UI only: nothing in the app opens them until a request contract exists.

  /// The acknowledgement once a request is confirmed sent.
  static const String requestSentTitle = 'Хүсэлт илгээгдлээ';
  static const String requestSentDismiss = 'Ойлголоо';

  /// The receiving teacher's two answers.
  static const String requestDecline = 'Татгалзах';
  static const String requestAccept = 'Зөвшөөрөх';

  /// What "Багш нар" shows in place of its rows: no verified endpoint lists
  /// the teachers or carries a request (BACKEND GAP, Issue #231). Not drawn
  /// by the reference — PRODUCT DECISION on the final wording.
  static const String requestsUnavailable =
      'Багшид цаг солих хүсэлт илгээх боломж удахгүй нэмэгдэнэ';
}
