import '../../../core/locale/app_format.dart';
import '../../home/presentation/home_strings.dart';
import '../domain/teacher_failure.dart';
import '../domain/teacher_session.dart';
import 'teacher_home_strings.dart';

/// Every word on Teacher Schedule, its session sheets and the "Багш нар"
/// screen (Issue #231), read off the four references. They mix languages as
/// Teacher Home's does ("Teacher" under a Mongolian name) and are carried
/// through verbatim.
abstract final class TeacherScheduleStrings {
  /// The header's selected date — "11-р сарын 17"; "November 17" in English
  /// ([AppFormat], Issue #505).
  static String headerDate(DateTime day) => AppFormat.longDate(day);

  /// The strip's weekday row, Sunday first: Ням, Даваа, Мягмар, Лхагва,
  /// Пүрэв, Баасан, Бямба — Ня … Бя. The reference's own row is a mock-up
  /// that repeats Ня and skips Ба, so the real seven are used. "Sun" …
  /// "Sat" in English ([AppFormat], Issue #505).
  static List<String> get weekdays =>
      AppFormat.weekdays(first: DateTime.sunday);

  /// Accessibility label for the header's date control.
  static const String pickDate = 'Огноо сонгох';

  /// Accessibility label for the header's bell, the student Home's own. It
  /// opens the shared Notification Center (Issue #246).
  static String get notifications => HomeStrings.notifications;

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

  /// What "Багш нар" shows when the backend does not serve the request
  /// endpoints (Issue #449): a refusal with no documented error code — what a
  /// backend without these routes answers. Not drawn by the reference —
  /// PRODUCT DECISION on the final wording.
  static const String requestsUnavailable =
      'Одоогоор цаг солих хүсэлт илгээх боломжгүй байна. Дараа дахин оролдоно уу.';

  // --- Sending a request (Issue #449) ---------------------------------------
  //
  // The app's own copy — no frame draws these — for the backend's documented
  // codes (`docs/schedule_change_api_v1.md`). PRODUCT DECISION on the final
  // wording; each says only what its code documents.

  /// "Багш нар" with no row: no other teacher is free at the session's time
  /// (the contract's eligible list: active teachers not teaching then).
  static const String requestsEmpty = 'Энэ цагт орлон заах боломжтой багш алга';

  /// `409 recipient_busy`: the teacher teaches at that time.
  static const String requestRecipientBusy =
      'Энэ багш тухайн цагт өөр хичээлтэй байна';

  /// `409 request_pending`: the session already has a pending request.
  static const String requestAlreadyPending =
      'Энэ хичээлд илгээсэн хүсэлт хүлээгдэж байна';

  /// `409 session_already_covered`: another teacher has accepted it.
  static const String requestSessionCovered =
      'Энэ хичээлийг өөр багш орлон заахаар болсон байна';

  /// `409 session_started`: the session's start time has passed.
  static const String requestSessionStarted =
      'Хичээл эхэлсэн тул цаг солих боломжгүй';

  /// `404 session_not_found`.
  static const String requestSessionNotFound = 'Хичээл олдсонгүй';

  /// `404 recipient_not_found`: unknown or deactivated teacher.
  static const String requestRecipientNotFound = 'Багш олдсонгүй';

  // --- Answering a request (Issue #453) -------------------------------------
  //
  // The app's own copy — no frame draws these — PRODUCT DECISION on the final
  // wording; each says only what its status or code documents.

  /// The card's title when the request's session names neither its course
  /// nor its cohort — also a covered session's (Issue #455).
  static const String incomingUntitled = 'Хичээл';

  // --- Covered sessions (Issue #455) ----------------------------------------

  /// A session the signed-in teacher covers for someone else.
  static const String covering = 'Орлон заах';

  /// An own session another teacher covers, with that teacher's name.
  static String coveredBy(String name) => 'Орлон заагдсан · $name';

  /// The line a scheduled [entry] carries on its block, card and sheet:
  /// [covering], [coveredBy], or null for an ordinary session.
  static String? assignmentLabel(ScheduledSession entry) {
    if (entry.isCovering) return covering;
    final coveredByName = entry.coveredBy;
    return coveredByName == null ? null : coveredBy(coveredByName);
  }

  /// A scheduled [entry]'s title, with [incomingUntitled] for a covering
  /// session that names neither course nor cohort.
  static String sessionTitle(ScheduledSession entry) =>
      entry.title ?? incomingUntitled;

  /// Where an incoming request stands once it is no longer `pending`.
  static const String incomingAccepted = 'Хүсэлтийг зөвшөөрсөн';
  static const String incomingRejected = 'Хүсэлтээс татгалзсан';
  static const String incomingCancelled = 'Хүсэлт цуцлагдсан';
  static const String incomingExpired = 'Хүсэлтийн хугацаа дууссан';

  /// The line for a resolved request's [status]; null while it is pending.
  static String? incomingStatus(String status) => switch (status) {
    'accepted' => incomingAccepted,
    'rejected' => incomingRejected,
    'cancelled' => incomingCancelled,
    'expired' => incomingExpired,
    _ => null,
  };

  /// `409 schedule_conflict`: the recipient teaches at that time.
  static const String requestScheduleConflict =
      'Тухайн цагт танд өөр хичээл байгаа тул зөвшөөрөх боломжгүй';

  /// `409 request_already_resolved`.
  static const String requestAlreadyResolved =
      'Хүсэлт аль хэдийн шийдвэрлэгдсэн байна';

  /// `404 request_not_found`: unknown, or the caller is not a party.
  static const String requestNotFound = 'Хүсэлт олдсонгүй';

  /// `403 not_recipient`: only the recipient can answer.
  static const String requestNotRecipient =
      'Энэ хүсэлтэд хариулах эрх танд алга';

  /// The line for a failed read, send or answer: the documented code's own
  /// copy; [requestsUnavailable] for a refusal carrying no code (a backend
  /// without these routes); otherwise the shared line for the failure's
  /// kind.
  static String requestFailure(TeacherFailure failure) =>
      switch (failure.code) {
        'recipient_busy' => requestRecipientBusy,
        'request_pending' => requestAlreadyPending,
        'session_already_covered' => requestSessionCovered,
        'session_started' => requestSessionStarted,
        'session_not_found' => requestSessionNotFound,
        'recipient_not_found' => requestRecipientNotFound,
        'schedule_conflict' => requestScheduleConflict,
        'request_already_resolved' => requestAlreadyResolved,
        'request_not_found' => requestNotFound,
        'not_recipient' => requestNotRecipient,
        null when failure.kind == TeacherFailureKind.rejected =>
          requestsUnavailable,
        _ => TeacherHomeStrings.messageFor(failure.kind),
      };
}
