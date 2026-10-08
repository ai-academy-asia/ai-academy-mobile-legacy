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

  /// The upcoming session sheet's action.
  static const String changeTime = 'Цаг солих';

  /// Under the held session's "14 / 24".
  static const String attendedCaption = 'оюутан ирцэд бүртгэгдсэн';

  // --- "Багш нар" -----------------------------------------------------------

  static const String teachersTitle = 'Багш нар';

  /// The line under each teacher's name.
  static const String teacherRole = 'Teacher';

  static const String requestSend = 'Хүсэлт илгээх';
  static const String requestPending = 'Хүлээгдэж байна';
  static const String requestRejected = 'Татгалзсан';

  /// What "Багш нар" shows in place of its rows: no verified endpoint lists
  /// the teachers or carries a request (BACKEND GAP, Issue #231). Not drawn
  /// by the reference — PRODUCT DECISION on the final wording.
  static const String requestsUnavailable =
      'Багшид цаг солих хүсэлт илгээх боломж удахгүй нэмэгдэнэ';
}
