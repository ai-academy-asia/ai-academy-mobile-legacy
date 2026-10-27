import '../../../core/locale/app_format.dart';
import '../../../core/locale/l10n.dart';
import '../../home/presentation/home_strings.dart';
import '../domain/teacher_failure.dart';
import '../domain/teacher_session.dart';
import 'teacher_home_strings.dart';

/// Every word on Teacher Schedule, its session sheets and the "Багш нар"
/// screen (Issue #231), read off the four references, in the selected
/// language since Issue #547 (L17). The Mongolian is unchanged; the English
/// is approved copy, not Figma wording. "Teacher" stays English in both, as
/// the references draw it under a Mongolian name.
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
  static String get pickDate => L10n.current.teacherSchedulePickDate;

  /// Accessibility label for the header's bell, the student Home's own. It
  /// opens the shared Notification Center (Issue #246).
  static String get notifications => HomeStrings.notifications;

  /// No session in the week. Not drawn by the reference — Teacher Home's
  /// wording for the same state.
  static String get empty => TeacherHomeStrings.empty;

  /// No session on the selected day, in the large-text day list (Issue
  /// #357). The week grid keeps [empty].
  static String get emptyDay => L10n.current.teacherScheduleEmptyDay;

  /// Accessibility labels for the day list's previous- and next-day
  /// controls (Issue #357).
  static String get previousDay => L10n.current.teacherSchedulePreviousDay;
  static String get nextDay => L10n.current.teacherScheduleNextDay;

  /// A finished session in the day list (Issue #357) — said in words, not
  /// only by the muted card.
  static String get finished => L10n.current.teacherScheduleFinished;

  /// The upcoming session sheet's actions.
  static String get changeTime => L10n.current.teacherScheduleChangeTime;

  /// Opens attendance registration (Issue #374) — live only on the
  /// session's date in Ulaanbaatar, drawn disabled any other day.
  static String get registerAttendance =>
      L10n.current.teacherScheduleTakeAttendance;

  /// Under the held session's "14 / 24".
  static String get attendedCaption =>
      L10n.current.teacherScheduleAttendedCaption;

  // --- "Багш нар" -----------------------------------------------------------

  static String get teachersTitle => L10n.current.teacherRequestTeachersTitle;

  /// The line under each teacher's name.
  static const String teacherRole = 'Teacher';

  static String get requestSend => L10n.current.teacherRequestSend;
  static String get requestPending => L10n.current.teacherRequestPending;
  static String get requestRejected => L10n.current.teacherRequestDeclined;

  // --- The request's sheets (Issue #372) -----------------------------------
  //
  // UI only: nothing in the app opens them until a request contract exists.

  /// The acknowledgement once a request is confirmed sent, and the button
  /// that closes it — passed to `TeacherConfirmationCard` as its
  /// `dismissLabel`.
  static String get requestSentTitle => L10n.current.teacherRequestSentTitle;
  static String get requestSentDismiss =>
      L10n.current.teacherConfirmationDismiss;

  /// The receiving teacher's two answers.
  static String get requestDecline => L10n.current.teacherRequestDecline;
  static String get requestAccept => L10n.current.teacherRequestAccept;

  /// What "Багш нар" shows when the backend does not serve the request
  /// endpoints (Issue #449): a refusal with no documented error code — what a
  /// backend without these routes answers. Not drawn by the reference —
  /// PRODUCT DECISION on the final wording.
  static String get requestsUnavailable =>
      L10n.current.teacherRequestsUnavailable;

  // --- Sending a request (Issue #449) ---------------------------------------
  //
  // The app's own copy — no frame draws these — for the backend's documented
  // codes (`docs/schedule_change_api_v1.md`). PRODUCT DECISION on the final
  // wording; each says only what its code documents.

  /// "Багш нар" with no row: no other teacher is free at the session's time
  /// (the contract's eligible list: active teachers not teaching then).
  static String get requestsEmpty => L10n.current.teacherRequestsEmpty;

  /// `409 recipient_busy`: the teacher teaches at that time.
  static String get requestRecipientBusy =>
      L10n.current.teacherRequestRecipientBusy;

  /// `409 request_pending`: the session already has a pending request.
  static String get requestAlreadyPending =>
      L10n.current.teacherRequestAlreadyPending;

  /// `409 session_already_covered`: another teacher has accepted it.
  static String get requestSessionCovered =>
      L10n.current.teacherRequestSessionCovered;

  /// `409 session_started`: the session's start time has passed.
  static String get requestSessionStarted =>
      L10n.current.teacherRequestSessionStarted;

  /// `404 session_not_found`.
  static String get requestSessionNotFound =>
      L10n.current.teacherRequestSessionNotFound;

  /// `404 recipient_not_found`: unknown or deactivated teacher.
  static String get requestRecipientNotFound =>
      L10n.current.teacherRequestRecipientNotFound;

  // --- Answering a request (Issue #453) -------------------------------------
  //
  // The app's own copy — no frame draws these — PRODUCT DECISION on the final
  // wording; each says only what its status or code documents.

  /// The card's title when the request's session names neither its course
  /// nor its cohort — also a covered session's (Issue #455).
  static String get incomingUntitled => L10n.current.teacherSessionUntitled;

  // --- Covered sessions (Issue #455) ----------------------------------------

  /// A session the signed-in teacher covers for someone else.
  static String get covering => L10n.current.teacherSessionCovering;

  /// An own session another teacher covers, with that teacher's name — or
  /// without it, when the backend holds a blank one (Issue #537).
  static String coveredBy(String name) => name.trim().isEmpty
      ? L10n.current.teacherSessionCovered
      : L10n.current.teacherSessionCoveredBy(name);

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
  static String get incomingAccepted => L10n.current.teacherRequestAccepted;
  static String get incomingRejected => L10n.current.teacherRequestRejected;
  static String get incomingCancelled => L10n.current.teacherRequestCancelled;
  static String get incomingExpired => L10n.current.teacherRequestExpired;

  /// The line for a resolved request's [status]; null while it is pending.
  static String? incomingStatus(String status) => switch (status) {
    'accepted' => incomingAccepted,
    'rejected' => incomingRejected,
    'cancelled' => incomingCancelled,
    'expired' => incomingExpired,
    _ => null,
  };

  /// `409 schedule_conflict`: the recipient teaches at that time.
  static String get requestScheduleConflict =>
      L10n.current.teacherRequestScheduleConflict;

  /// `409 request_already_resolved`.
  static String get requestAlreadyResolved =>
      L10n.current.teacherRequestAlreadyResolved;

  /// `404 request_not_found`: unknown, or the caller is not a party.
  static String get requestNotFound => L10n.current.teacherRequestNotFound;

  /// `403 not_recipient`: only the recipient can answer.
  static String get requestNotRecipient =>
      L10n.current.teacherRequestNotRecipient;

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
