/// The official AI Academy Asia contact behind Login's "Менежертэй
/// холбогдоорой" card and a signed-out "Нууц үг сэргээх" (Issue #184).
///
/// Confirmed by the business for this path, and the same contact the public
/// website gives under "Need help or have questions?". It is the only contact
/// information in the app: add no other number or address without the same
/// confirmation.
abstract final class ManagerContact {
  /// +976 7505 1055 — tried first.
  static final Uri phone = Uri(scheme: 'tel', path: '+97675051055');

  /// info@ai-academy.asia — opened when no app takes [phone], e.g. a tablet
  /// with no dialer.
  static final Uri email = Uri(scheme: 'mailto', path: 'info@ai-academy.asia');
}
