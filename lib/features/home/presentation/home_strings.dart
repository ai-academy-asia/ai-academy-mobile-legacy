import '../domain/home_failure.dart';

/// Every word on the Home dashboard.
///
/// Read off the Figma Home frames. The design mixes languages the way the
/// Profile frame does — the cohort card's progress line is English while
/// everything around it is Mongolian — and that is carried through verbatim
/// rather than translated, the same policy `ProfileStrings` follows.
abstract final class HomeStrings {
  // --- Header ---------------------------------------------------------------

  /// Accessibility label for the header's notification control.
  static const String notifications = 'Мэдэгдэл';

  /// Accessibility label for the brand lockup in the header.
  static const String logo = 'AI academy Asia';

  /// The wordmark's two lines, beside the icon mark — matches
  /// `SplashStrings.wordmarkLine1`/`wordmarkLine2` verbatim (same brand mark,
  /// kept as its own local copy rather than a cross-feature import, the same
  /// way `NoteTab`'s sample student identity duplicates `ProfileStrings.name`
  /// instead of importing it).
  static const String wordmarkLine1 = 'AI academy';
  static const String wordmarkLine2 = 'Asia';

  // --- Cohort card ----------------------------------------------------------

  static String modules(int completed, int total) =>
      'Modules $completed of $total complete';

  static String percentComplete(int percent) => '$percent% complete';

  static const String nextLesson = 'Дараагийн хичээл:';

  /// The badge beside [nextLesson] while the lesson is under way.
  static const String live = 'Live';

  /// The line the live state adds under the lesson's time.
  static const String liveHint = 'Хичээл эхлсэн та ирцээ бүртгүүлээрэй';

  static const String attendanceAction = 'Ирц бүртгүүлэх';

  /// `08/04 • 09:00 – 11:00`. Built by hand rather than with `intl`, which the
  /// app does not depend on: the format is fixed, so a package for it would be
  /// a dependency for one line.
  static String lessonWindow(DateTime startsAt, DateTime endsAt) =>
      '${_two(startsAt.day)}/${_two(startsAt.month)} • '
      '${_clock(startsAt)} – ${_clock(endsAt)}';

  // --- Contract -------------------------------------------------------------

  static const String contractTitle = 'Та гэрээ хийгдээгүй байна';
  static const String contractSupporting = 'Гэрээгээ хийгээрэй';

  // --- Payment --------------------------------------------------------------

  static const String paymentLabel = 'Дараанийн төлөлт';
  static const String paymentOverdue = 'Хугацаа хэтэрсэн';
  static String paymentDueIn(int days) => '$days хоног дутуу';
  static const String payAction = 'Төлбөр төлөх';

  // --- Attendance -----------------------------------------------------------

  static const String attendanceLabel = 'Хичээлийн ирц';

  /// `1/20  · 10%` — two spaces before the dot and one after, as the
  /// reference sets it.
  static String attendanceValue(int attended, int total, int percent) =>
      '$attended/$total  · $percent%';

  /// The action on both statistic cards.
  static const String details = 'Дэлгэрэнгүй';

  /// The Adult attendance screen's legend row for an `absent` session — the
  /// frame's own wording, unlike the Junior frame's "Хичээлээ тасалсан".
  static const String attendanceMissed = 'Хичээлдээ суугаагүй';

  // --- States ---------------------------------------------------------------

  static const String empty = 'Та одоогоор ямар нэг ангид бүртгүүлээгүй байна';
  static const String retry = 'Дахин оролдох';

  static const String sessionExpired =
      'Нэвтрэх хугацаа дууссан. Дахин нэвтэрнэ үү';
  static const String networkError =
      'Сүлжээнд холбогдож чадсангүй. Дахин оролдоно уу';
  static const String serverError =
      'Серверт алдаа гарлаа. Түр хүлээгээд дахин оролдоно уу';
  static const String unexpectedError = 'Алдаа гарлаа. Дахин оролдоно уу';

  /// One fixed string per [HomeFailureKind].
  static String messageFor(HomeFailureKind kind) => switch (kind) {
    HomeFailureKind.sessionExpired => sessionExpired,
    HomeFailureKind.network => networkError,
    HomeFailureKind.server => serverError,
    HomeFailureKind.unexpected => unexpectedError,
  };

  // --- Bottom navigation ----------------------------------------------------

  static const String navHome = 'Нүүр';
  static const String navCourses = 'Хичээл';
  static const String navProfile = 'Профайл';

  static String _clock(DateTime time) =>
      '${_two(time.hour)}:${_two(time.minute)}';

  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// The dashboard's own icons, exported from the design.
///
/// Same arrangement as `ProfileIcons`: SVG paths as constants, so a renamed
/// export is a one-line change. The single-colour glyphs — the caret, the
/// tab bar, money, calendar and QR code — come from the Phosphor font via
/// `AppIcons`; these are the ones drawn as artwork.
abstract final class HomeIcons {
  static const String _dir = 'assets/icons';

  /// The icon half of the header's brand lockup — the same bundled mark the
  /// splash screen shows. The "AI academy" / "Asia" wordmark beside it is
  /// drawn as text ([AppTypography.homeLogoWordmark]), not read off an image;
  /// see `HomeHeader`'s own doc comment.
  static const String appIcon = 'assets/images/ai_academy_app_icon.png';

  static const String notification = '$_dir/notification.svg';

  /// Phosphor "Files" in the amber of the contract banner, with the back
  /// sheet tinted as the reference's duotone draws it — the same glyph as
  /// Profile's `e_contract.svg`, which is single-colour.
  static const String contract = '$_dir/contract_warning.svg';

  /// The Home tab's selected glyph: Phosphor "House" filled, in the frames'
  /// blue. The font only carries the outline weight.
  static const String navHomeSelected = '$_dir/nav_home_selected.svg';
  static const String adult = '$_dir/adult.svg';
  static const String junior = '$_dir/junior.svg';

  /// The decorative shapes behind the cohort card's summary: the cohort
  /// list card's own export, unchanged but for a 208-tall viewBox. The paths
  /// already run well below that card's 148, and Home's summary is 208 tall,
  /// so the same pattern shows further down rather than being scaled up.
  static const String cardBackground = '$_dir/program_card_background.svg';
}
