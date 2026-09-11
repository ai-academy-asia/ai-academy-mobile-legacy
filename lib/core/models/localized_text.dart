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
}
