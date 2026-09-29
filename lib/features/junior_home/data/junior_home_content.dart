/// The two strings on the certificate panel that are design, not data.
///
/// `GET /me/courses/{course_slug}/learning` carries a course title and a
/// certificate *status*; it carries no track name and no caption for the
/// panel. Both of these are drawn on the Figma frame and neither has a field
/// behind it, so they stay here rather than being invented as API data — the
/// same line the contract itself draws around the module icons and the hero
/// illustration, which it says the client owns.
///
/// [track] is safe as a constant because this screen *is* the Junior one: a
/// student in adult mode is shown the adult dashboard instead, so the label
/// is never wrong on the screen that draws it.
abstract final class JuniorHomeContent {
  static const String track = 'Junior';
  static const String certificateDescription =
      'Earn a Certificate of completion';
}
