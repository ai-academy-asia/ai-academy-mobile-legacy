import '../../../core/locale/app_format.dart';
import '../../../core/locale/l10n.dart';
import '../../home/presentation/home_strings.dart';

/// Every word on the Junior "Сурлагын явц" screen, verbatim from the frame.
///
/// Three lines differ from how the task text spelled them, and the frame's
/// spelling is what ships — `DEVELOPMENT_RULES.md` §6 asks for copy verbatim
/// from the design, and the export is the stated source of truth:
///
/// * [paymentTitle] — the frame reads "Дараа**н**ийн", the same spelling the
///   adult dashboard's `HomeStrings.paymentLabel` already carries; the task
///   text wrote "Дараа**г**ийн".
/// * [legendHint] — the frame reads "идэвх**тт**эй суу**гаа**д"; the task
///   text wrote "идэвхтэй суугааад". Neither is the standard spelling
///   ("идэвхтэй суугаад"), which is flagged for the designer rather than
///   corrected here.
/// * [nextLessonTime] — the frame separates the date and the time with a
///   bullet (•), not the middle dot (·) its attendance badge uses.
abstract final class JuniorProgressStrings {
  // --- Contract banner ------------------------------------------------------

  static String get contractTitle => L10n.current.juniorContractTitle;

  /// Under the contract banner's title: ask the child to show it to a parent.
  /// In the selected language (Issue #519).
  static String get showParent => L10n.current.juniorShowParent;

  /// The payment card's identical line — [showParent]'s own key, since the
  /// payment card is in the selected language too (Issue #529).
  static String get paymentShowParent => L10n.current.juniorShowParent;

  // --- Payment card ---------------------------------------------------------

  // In the selected language (Issue #529).

  /// Its own key rather than `HomeStrings.paymentLabel` and a colon added
  /// here, so each language keeps its own punctuation.
  static String get paymentTitle => L10n.current.juniorPaymentTitle;
  static String paymentDueIn(int days) => L10n.current.paymentDueIn(days);

  /// An overdue payment — a state the Junior frame does not draw, so this is
  /// the adult dashboard's own wording rather than new copy.
  static String get paymentOverdue => HomeStrings.paymentOverdue;
  static String get payAction => L10n.current.paymentPayAction;

  // --- Summary --------------------------------------------------------------

  static String get attendance => L10n.current.homeAttendanceLabel;
  static String get exam => L10n.current.juniorExam;
  static String attendanceValue(int attended, int total, int percent) =>
      '$attended/$total · $percent%';
  static String percent(int value) => '$value%';

  // --- Next lesson ----------------------------------------------------------

  static String get nextLesson => L10n.current.homeNextLesson;

  /// "08/08 • 09:00 – 11:00" — month/day, then the lesson's hours;
  /// "Aug 8 • 09:00 – 11:00" in English ([AppFormat], Issue #505).
  static String nextLessonTime(DateTime start, DateTime end) =>
      '${AppFormat.shortDate(start)} • '
      '${AppFormat.time(start)} – ${AppFormat.time(end)}';

  // --- Calendar -------------------------------------------------------------

  /// "Наймдугаар сар, 2026". The frame draws August only; the other eleven
  /// are the standard Mongolian ordinal month names in the same form.
  /// "August 2026" in English ([AppFormat], Issue #505).
  static String monthLabel(DateTime month) => AppFormat.monthYear(month);

  /// Sunday first, as the frame's header row runs. English letters, as the
  /// frame draws them — in either language ([AppFormat], Issue #505).
  static List<String> get weekdays =>
      AppFormat.weekdayLetters(first: DateTime.sunday);

  static const String previousMonth = 'Previous month';
  static const String nextMonth = 'Next month';

  // --- Legend ---------------------------------------------------------------

  static String get legendTitle => L10n.current.juniorLegendTitle;
  static String get legendHint => L10n.current.juniorLegendHint;
  static String get lessonDay => L10n.current.juniorLessonDay;
  static String get lessonMissed => L10n.current.juniorLessonMissed;
  static String get lessonAttended => L10n.current.juniorLessonAttended;
}

/// The screen's exported artwork — the three day marks. [lessonDay] and
/// [lessonMissed] are the design's own vector SVGs, committed unchanged.
///
/// [lessonAttended] is a **PNG**: the design's attended mark exists only as
/// a raster (its Figma export is a PNG inside an SVG `<pattern>`, which
/// flutter_svg parses but paints nothing for). The PNG is that export
/// rasterised exactly — its 63 x 54 viewBox, rect clip and pattern transform,
/// at 2x — with only the mark's colours changed to the frame's attended
/// palette: `#EEFBFF` front leg and foot, `#D9E4FF` back leg, `#7CA4FF` inner
/// wedge and `#F8623F` sparkle, as seen over the `#2970FF` disc. Swap it for a
/// vector SVG if the design ever exports one.
abstract final class JuniorProgressIcons {
  static const String _dir = 'assets/icons';

  static const String lessonDay = '$_dir/junior_lesson_day.svg';
  static const String lessonMissed = '$_dir/junior_lesson_missed.svg';
  static const String lessonAttended = '$_dir/junior_lesson_attended.png';
}
