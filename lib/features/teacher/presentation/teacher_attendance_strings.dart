import '../domain/teacher_attendance.dart';

/// Copy for teacher attendance registration (Issue #374). The screen texts
/// are the references' own; the four status names and the state messages
/// are not drawn by a reference (`PRODUCT DECISION` on their final
/// wording).
abstract final class TeacherAttendanceStrings {
  // --- QR ("Ирц бүртгэх") ---
  static const String qrTitle = 'Ирц бүртгэх';
  static const String qrHint =
      'Оюутнууд уг кодыг уншуулна уу · Students scan this code';

  /// Under the live count — the QR reference's own past tense
  /// ("бүртгэгдлээ"), where the held sheet's reads "бүртгэгдсэн".
  static const String qrCountCaption = 'оюутан ирцэд бүртгэгдлээ';

  static const String manualEntry = 'Гар аргаар бүртгэх';

  /// No QR is drawn until the backend owner confirms what it encodes
  /// (Issue #374, open question 1).
  static const String qrPending =
      'QR кодоор бүртгэх боломж удахгүй нэмэгдэнэ. Одоогоор гар аргаар '
      'бүртгэнэ үү.';

  /// `409 session_not_today`.
  static const String qrNotToday =
      'QR кодыг зөвхөн хичээлийн өдөр үүсгэх боломжтой.';

  /// The token ran out before a fresh one could be fetched.
  static const String qrExpired = 'QR кодын хугацаа дууссан.';

  static const String qrLabel = 'Ирцийн QR код';

  // --- Manual ("Гар аргаар бүртгэх") ---
  static const String manualTitle = manualEntry;
  static const String studentsHeading = 'Сурагчид';
  static const String confirm = 'Баталгаажуулах';
  static const String noStudents = 'Энэ хичээлд бүртгэлтэй сурагч алга.';
  static const String saveFailed = 'Хадгалагдсангүй';
  static const String saving = 'Хадгалж байна';
  static String failedRows(int count) =>
      '$count сурагчийн ирц хадгалагдсангүй. Дахин оролдоно уу.';

  /// The status picker's heading.
  static const String chooseStatus = 'Ирцийн төлөв';

  static String statusLabel(AttendanceStatus status) => switch (status) {
    AttendanceStatus.present => 'Ирсэн',
    AttendanceStatus.late => 'Хоцорсон',
    AttendanceStatus.absent => 'Ирээгүй',
    AttendanceStatus.excused => 'Чөлөөтэй',
  };

  // --- Success ---
  /// The success reference's exact title.
  static const String successTitle = 'Амжилттай баталгаажлаа';
}
