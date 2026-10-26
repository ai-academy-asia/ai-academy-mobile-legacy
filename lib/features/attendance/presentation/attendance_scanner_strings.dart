import '../../../core/locale/l10n.dart';
import '../../home/presentation/home_strings.dart';
import '../domain/attendance_check_in.dart';
import '../domain/attendance_failure.dart';
import 'qr_scan_view.dart';

/// Every word on the attendance scanner. The hint and the window label are
/// the Figma reference's; the result, error and camera messages are not
/// drawn by any reference (`PRODUCT DECISION` on their final wording,
/// Issue #384).
///
/// In the selected language (Issue #531): every line reads a `scanner*` ARB
/// key; the shared errors and the camera retry read the common keys through
/// [HomeStrings]. The refusal and camera messages are text the controller
/// stores when they happen, so they keep their language until the next scan
/// or retry; everything else switches at once.
abstract final class AttendanceScannerStrings {
  static String get hint => L10n.current.scannerHint;

  /// Read out for the scan window, which draws no text.
  static String get window => L10n.current.scannerWindow;

  static String get checkingIn => L10n.current.scannerCheckingIn;
  static String get rescan => L10n.current.scannerRescan;
  static String get done => L10n.current.scannerDone;
  static String get retryCamera => HomeStrings.retry;

  // --- The server's record (never a generic success) ---

  /// The headline for the status the server returned. A status the app does
  /// not know is shown as returned.
  static String resultTitle(String status) => switch (status) {
    'present' => L10n.current.scannerResultPresent,
    'late' => L10n.current.scannerResultLate,
    'absent' => L10n.current.scannerResultAbsent,
    'excused' => L10n.current.scannerResultExcused,
    _ => L10n.current.scannerResultOther(status),
  };

  /// What else the student should know: a repeat says the record is the
  /// earlier one; a teacher's absent/excused points them to the teacher.
  static String? resultBody(AttendanceCheckIn result) =>
      switch (result.status) {
        'absent' || 'excused' => L10n.current.scannerTeacherRecorded,
        _ when !result.firstCheckIn => L10n.current.scannerAlreadyCheckedIn,
        _ => null,
      };

  // --- Why a check-in did not go through ---

  static String failureMessage(AttendanceFailure failure) =>
      switch (failure.code) {
        'invalid_token' => L10n.current.scannerInvalidToken,
        'token_required' => L10n.current.scannerTokenRequired,
        'not_enrolled' => L10n.current.scannerNotEnrolled,
        _ => switch (failure.kind) {
          AttendanceFailureKind.sessionExpired => HomeStrings.sessionExpired,
          AttendanceFailureKind.network => HomeStrings.networkError,
          AttendanceFailureKind.server => HomeStrings.serverError,
          AttendanceFailureKind.rejected ||
          AttendanceFailureKind.unexpected => HomeStrings.unexpectedError,
        },
      };

  // --- The camera ---

  static String unavailableMessage(QrScanUnavailable reason) =>
      switch (reason) {
        QrScanUnavailable.permissionDenied => L10n.current.scannerCameraDenied,
        QrScanUnavailable.unsupported => L10n.current.scannerCameraUnsupported,
        QrScanUnavailable.failed => L10n.current.scannerCameraFailed,
      };
}
