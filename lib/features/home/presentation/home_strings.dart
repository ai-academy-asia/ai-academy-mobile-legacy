import '../../../core/locale/l10n.dart';
import '../../../core/locale/app_format.dart';
import '../domain/home_failure.dart';
import '../../../shared/widgets/track_badge.dart';
import '../../payments/presentation/payment_strings.dart';

/// Every word on the Home dashboard.
///
/// Read off the Figma Home frames. The design mixes languages the way the
/// Profile frame does — the cohort card's progress line is English while
/// everything around it is Mongolian — and that is carried through verbatim
/// rather than translated, the same policy `ProfileStrings` follows.
///
/// In the selected language (Issue #517): the dashboard's Mongolian lines read
/// `home*` ARB keys, besides the shared errors and nav keys. The design's own
/// English (the logo, "Live", the progress lines) and the payment card's
/// lines are still constants.
abstract final class HomeStrings {
  // --- Header ---------------------------------------------------------------

  /// Accessibility label for the header's notification control.
  static String get notifications => L10n.current.homeNotifications;

  /// Accessibility label for the brand lockup in the header — announced in
  /// place of the wordmark artwork, one line as the splash screen reads it.
  static const String logo = 'AI academy Asia';

  // --- Cohort card ----------------------------------------------------------

  static String modules(int completed, int total) =>
      'Modules $completed of $total complete';

  static String percentComplete(int percent) => '$percent% complete';

  static String get nextLesson => L10n.current.homeNextLesson;

  /// The badge beside [nextLesson] while the lesson is under way.
  static const String live = 'Live';

  /// The line the live state adds under the lesson's time.
  static String get liveHint => L10n.current.homeLiveHint;

  static String get attendanceAction => L10n.current.homeAttendanceAction;

  /// `08/04 • 09:00 – 11:00` — day first (`dd/MM`) in Mongolian, as Home has
  /// always written it; `Apr 8 • 09:00 – 11:00` in English ([AppFormat],
  /// Issue #505).
  static String lessonWindow(DateTime startsAt, DateTime endsAt) =>
      '${AppFormat.shortDate(startsAt, dayFirst: true)} • '
      '${AppFormat.time(startsAt)} – ${AppFormat.time(endsAt)}';

  // --- Contract -------------------------------------------------------------

  static String get contractTitle => L10n.current.homeContractTitle;
  static String get contractSupporting => L10n.current.homeContractSupporting;

  // --- Payment --------------------------------------------------------------

  static const String paymentLabel = 'Дараанийн төлөлт';
  static const String paymentOverdue = 'Хугацаа хэтэрсэн';
  static String paymentDueIn(int days) => '$days хоног дутуу';

  /// [PaymentStrings.payAction] — the Payment feature owns the label; the
  /// Home payment card shows the same words (Issue #331).
  static const String payAction = PaymentStrings.payAction;

  // --- Attendance -----------------------------------------------------------

  static String get attendanceLabel => L10n.current.homeAttendanceLabel;

  /// `1/20  · 10%` — two spaces before the dot and one after, as the
  /// reference sets it.
  static String attendanceValue(int attended, int total, int percent) =>
      '$attended/$total  · $percent%';

  /// The action on both statistic cards.
  static String get details => L10n.current.homeDetails;

  /// The Adult attendance screen's legend row for an `absent` session — the
  /// frame's own wording, unlike the Junior frame's "Хичээлээ тасалсан".
  static String get attendanceMissed => L10n.current.homeAttendanceMissed;

  // --- States ---------------------------------------------------------------

  static String get empty => L10n.current.homeEmpty;
  static String get retry => L10n.current.commonRetry;

  static String get sessionExpired => L10n.current.commonSessionExpired;
  static String get networkError => L10n.current.commonNetworkError;
  static String get serverError => L10n.current.commonServerError;
  static String get unexpectedError => L10n.current.commonUnexpectedError;

  /// One fixed string per [HomeFailureKind].
  static String messageFor(HomeFailureKind kind) => switch (kind) {
    HomeFailureKind.sessionExpired => sessionExpired,
    HomeFailureKind.network => networkError,
    HomeFailureKind.server => serverError,
    HomeFailureKind.unexpected => unexpectedError,
  };

  // --- Bottom navigation ----------------------------------------------------
  //
  // In the selected language (Issue #511): Нүүр / Home, Хичээл / Courses,
  // Профайл / Profile.

  static String get navHome => L10n.current.navHome;
  static String get navCourses => L10n.current.navCourses;
  static String get navProfile => L10n.current.navProfile;
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
  /// splash screen shows.
  static const String appIcon = 'assets/images/ai_academy_app_icon.png';

  /// The "AI academy" / "Asia" half: the Figma frame's wordmark as outlined
  /// vector paths, the same export the splash screen draws
  /// (`SplashAssets.wordmark`). The design does not set it in Manrope, so
  /// drawing it as live text could only approximate it (Issue #188).
  static const String wordmark = 'assets/images/splash_wordmark.svg';

  static const String notification = '$_dir/notification.svg';

  /// Phosphor "Files" in the amber of the contract banner, with the back
  /// sheet tinted as the reference's duotone draws it — the same glyph as
  /// Profile's `e_contract.svg`, which is single-colour.
  static const String contract = '$_dir/contract_warning.svg';

  /// The track badge's marks — [TrackBadge.adultGlyph] / [TrackBadge.juniorGlyph]
  /// (Issue #329).
  static const String adult = TrackBadge.adultGlyph;
  static const String junior = TrackBadge.juniorGlyph;
}
