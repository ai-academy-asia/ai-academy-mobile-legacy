import '../../../core/locale/l10n.dart';
import '../domain/teacher_attendance.dart';
import 'teacher_schedule_strings.dart';

/// Copy for teacher attendance registration (Issue #374). The screen texts
/// are the references' own; the four status names and the state messages
/// are not drawn by a reference (`PRODUCT DECISION` on their final
/// wording). In the selected language since Issue #551 (L18): the Mongolian
/// is unchanged, the English approved copy. The QR hint stays bilingual, as
/// the reference draws it.
abstract final class TeacherAttendanceStrings {
  // --- QR ("Ирц бүртгэх") ---
  /// Teacher Schedule's own "Ирц бүртгэх" — the action that opens this
  /// screen.
  static String get qrTitle => TeacherScheduleStrings.registerAttendance;
  static const String qrHint =
      'Оюутнууд уг кодыг уншуулна уу · Students scan this code';

  /// Under the live count — the QR reference's own past tense
  /// ("бүртгэгдлээ"), where the held sheet's reads "бүртгэгдсэн".
  static String get qrCountCaption => L10n.current.teacherAttendanceQrCaption;

  static String get manualEntry => L10n.current.teacherAttendanceManualEntry;

  /// `409 session_not_today`.
  static String get qrNotToday => L10n.current.teacherAttendanceQrNotToday;

  /// The token ran out before a fresh one could be fetched.
  static String get qrExpired => L10n.current.teacherAttendanceQrExpired;

  static String get qrLabel => L10n.current.teacherAttendanceQrLabel;

  // --- Manual ("Гар аргаар бүртгэх") ---
  static String get manualTitle => manualEntry;
  static String get studentsHeading => L10n.current.teacherStudentsHeading;
  static String get confirm => L10n.current.teacherAttendanceConfirm;
  static String get noStudents => L10n.current.teacherAttendanceNoStudents;
  static String get saveFailed => L10n.current.teacherAttendanceSaveFailed;
  static String get saving => L10n.current.teacherAttendanceSaving;
  static String failedRows(int count) =>
      L10n.current.teacherAttendanceFailedRows(count);

  // --- Server changes before saving (Issue #378) ---
  static String get conflictTitle =>
      L10n.current.teacherAttendanceConflictTitle;
  static String get conflictBody => L10n.current.teacherAttendanceConflictBody;
  static String conflictServer(AttendanceStatus status, String? method) =>
      L10n.current.teacherAttendanceConflictServer(
        statusLabel(status),
        methodLabel(method),
      );
  static String conflictMine(AttendanceStatus status) =>
      L10n.current.teacherAttendanceConflictMine(statusLabel(status));
  static String keepServer(AttendanceStatus status) =>
      L10n.current.teacherAttendanceKeepServer(statusLabel(status));
  static String applyMine(AttendanceStatus status) =>
      L10n.current.teacherAttendanceApplyMine(statusLabel(status));
  static String conflictsPending(int count) =>
      L10n.current.teacherAttendanceConflictsPending(count);
  static String checkFailed(String reason) =>
      L10n.current.teacherAttendanceCheckFailed(reason);

  /// How a server record was made: the backend's `method`.
  static String methodLabel(String? method) => switch (method) {
    'qr' => 'QR',
    'manual' => L10n.current.teacherAttendanceMethodManual,
    _ => L10n.current.teacherAttendanceMethodNone,
  };

  /// The status picker's heading.
  static String get chooseStatus => L10n.current.teacherAttendanceChooseStatus;

  static String statusLabel(AttendanceStatus status) => switch (status) {
    AttendanceStatus.present => L10n.current.teacherAttendancePresent,
    AttendanceStatus.late => L10n.current.teacherAttendanceLate,
    AttendanceStatus.absent => L10n.current.teacherAttendanceAbsent,
    AttendanceStatus.excused => L10n.current.teacherAttendanceExcused,
  };

  // --- Success ---
  /// The success reference's exact title.
  static String get successTitle => L10n.current.teacherAttendanceSuccessTitle;

  /// The success card's dismiss button — the reference's "Ойлголоо", the
  /// request card's own key, so both follow the language (Issues #547,
  /// #551).
  static String get successDismiss => TeacherScheduleStrings.requestSentDismiss;
}
