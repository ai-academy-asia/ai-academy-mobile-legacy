/// Bilingual text the API sends as `{"en": ..., "mn": ...}` — English and
/// Mongolian, either of which may be absent.
///
/// First seen on `Course.title` and `Course.tagline` (`GET /courses`). Kept
/// here rather than under `features/courses/` because the same shape is
/// expected to recur on cohorts and other student-facing content — a second
/// feature needing it should find it, not duplicate it.
class LocalizedText {
  const LocalizedText({this.en, this.mn});

  final String? en;
  final String? mn;

  /// The selected content language first (Issue #501) — see
  /// [preferredText].
  String? get preferred => preferredText(mn, en);
}

/// Which side of the API's bilingual `{"mn", "en"}` text the app shows
/// (Issue #501). Set by `AppLocaleController` whenever the language changes;
/// Mongolian (false) until then, so everything that never sets it reads as
/// before.
abstract final class ContentLanguage {
  static bool prefersEnglish = false;
}

/// [mn] and [en] as one piece of text, the selected content language first.
///
/// With English selected ([ContentLanguage.prefersEnglish]): [en] when it
/// holds more than whitespace, otherwise the Mongolian-first reading below.
/// With Mongolian (the default): Mongolian first, falling back to English,
/// and to null only when neither is a non-empty string — exactly as before.
String? preferredText(String? mn, String? en) {
  if (ContentLanguage.prefersEnglish && en != null && en.trim().isNotEmpty) {
    return en;
  }
  if (mn != null && mn.isNotEmpty) return mn;
  if (en != null && en.isNotEmpty) return en;
  return null;
}
