import '../../home/presentation/home_strings.dart';
import '../domain/attendance_check_in.dart';
import '../domain/attendance_failure.dart';
import 'qr_scan_view.dart';

/// Every word on the attendance scanner. The hint and the window label are
/// the Figma reference's; the result, error and camera messages are not
/// drawn by any reference (`PRODUCT DECISION` on their final wording,
/// Issue #384).
abstract final class AttendanceScannerStrings {
  static const String hint = 'QR кодыг хүрээн дотор хөдөлгөөнгүй уншуулна уу.';

  /// Read out for the scan window, which draws no text.
  static const String window = 'QR код уншуулах хүрээ';

  static const String checkingIn = 'Ирц бүртгэж байна…';
  static const String rescan = 'Дахин уншуулах';
  static const String done = 'Ойлголоо';
  static const String retryCamera = HomeStrings.retry;

  // --- The server's record (never a generic success) ---

  /// The headline for the status the server returned.
  static String resultTitle(String status) => switch (status) {
    'present' => 'Ирц бүртгэгдлээ',
    'late' => 'Хоцорсон гэж бүртгэгдлээ',
    'absent' => 'Ирээгүй гэж бүртгэгдсэн байна',
    'excused' => 'Чөлөөтэй гэж бүртгэгдсэн байна',
    _ => 'Ирцийн төлөв: $status',
  };

  /// What else the student should know: a repeat says the record is the
  /// earlier one; a teacher's absent/excused points them to the teacher.
  static String? resultBody(AttendanceCheckIn result) =>
      switch (result.status) {
        'absent' || 'excused' =>
          'Багш таны ирцийг өмнө нь бүртгэсэн байна. Асуух зүйл байвал багшдаа '
              'хандана уу.',
        _ when !result.firstCheckIn =>
          'Та энэ хичээлд өмнө нь бүртгэгдсэн байна.',
        _ => null,
      };

  // --- Why a check-in did not go through ---

  static String failureMessage(AttendanceFailure failure) =>
      switch (failure.code) {
        'invalid_token' =>
          'QR код хүчингүй эсвэл хугацаа нь дууссан байна. Багшийн дэлгэц '
              'дээрх шинэ кодыг уншуулна уу.',
        'token_required' => 'QR код уншигдсангүй. Дахин уншуулна уу.',
        'not_enrolled' => 'Та энэ хичээлд бүртгэлгүй байна.',
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
        QrScanUnavailable.permissionDenied =>
          'Камер ашиглах зөвшөөрөл олгоогүй байна. Утасны тохиргооноос '
              'камерын зөвшөөрлийг идэвхжүүлээд дахин оролдоно уу.',
        QrScanUnavailable.unsupported =>
          'Энэ төхөөрөмж дээр камер ашиглах боломжгүй.',
        QrScanUnavailable.failed => 'Камерыг асаах үед алдаа гарлаа.',
      };
}
