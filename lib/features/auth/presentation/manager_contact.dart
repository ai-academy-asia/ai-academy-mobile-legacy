/// The official AI Academy Asia contact behind Login's "Менежертэй
/// холбогдоорой" card and a signed-out "Нууц үг сэргээх" (Issue #184), which
/// the student picks between in `ManagerContactSheet` (Issue #186).
///
/// Confirmed by the business for this path, and the same contact the public
/// website gives under "Need help or have questions?". It is the only contact
/// information in the app: add no other number or address without the same
/// confirmation.
abstract final class ManagerContact {
  /// "Утасдах" — [phoneLabel] as a `tel:` link.
  static final Uri phone = Uri(scheme: 'tel', path: '+97675051055');

  /// "Email бичих" — [emailLabel] as a `mailto:` link.
  static final Uri email = Uri(scheme: 'mailto', path: 'info@ai-academy.asia');

  /// The phone number as the sheet shows it, grouped as the business gave it.
  static const String phoneLabel = '+976 7505 1055';

  /// The address as the sheet shows it.
  static const String emailLabel = 'info@ai-academy.asia';
}
