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

  static const String contractTitle = 'Гэрээ хийгдээгүй байна';

  /// Shared by the contract banner and the payment card: both ask the child
  /// to show the matter to a parent.
  static const String showParent = 'Эцэг эхдээ үзүүлнэ үү 😊';

  // --- Payment card ---------------------------------------------------------

  static const String paymentTitle = 'Дараанийн төлөлт:';
  static String paymentDueIn(int days) => '$days хоног дутуу';
  static const String payAction = 'Төлбөр төлөх';

  // --- Summary --------------------------------------------------------------

  static const String attendance = 'Хичээлийн ирц';
  static const String exam = 'Шалгалтын дүн';
  static String attendanceValue(int attended, int total, int percent) =>
      '$attended/$total · $percent%';
  static String percent(int value) => '$value%';

  // --- Next lesson ----------------------------------------------------------

  static const String nextLesson = 'Дараагийн хичээл:';

  /// "08/08 • 09:00 – 11:00" — month/day, then the lesson's hours.
  static String nextLessonTime(DateTime start, DateTime end) =>
      '${_two(start.month)}/${_two(start.day)} • '
      '${_two(start.hour)}:${_two(start.minute)} – '
      '${_two(end.hour)}:${_two(end.minute)}';

  // --- Calendar -------------------------------------------------------------

  /// "Наймдугаар сар, 2026". The frame draws August only; the other eleven
  /// are the standard Mongolian ordinal month names in the same form.
  static String monthLabel(DateTime month) =>
      '${_months[month.month - 1]} сар, ${month.year}';

  static const List<String> _months = [
    'Нэгдүгээр',
    'Хоёрдугаар',
    'Гуравдугаар',
    'Дөрөвдүгээр',
    'Тавдугаар',
    'Зургаадугаар',
    'Долоодугаар',
    'Наймдугаар',
    'Есдүгээр',
    'Аравдугаар',
    'Арван нэгдүгээр',
    'Арван хоёрдугаар',
  ];

  /// Sunday first, as the frame's header row runs. English letters, as the
  /// frame draws them.
  static const List<String> weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  static const String previousMonth = 'Previous month';
  static const String nextMonth = 'Next month';

  // --- Legend ---------------------------------------------------------------

  static const String legendTitle = 'Тайлбар:';
  static const String legendHint =
      'Та хичээлдээ идэвхттэй суугаад тамгаа цуглуулаарай';
  static const String lessonDay = 'Хичээлтэй өдөр';
  static const String lessonMissed = 'Хичээлээ тасалсан';
  static const String lessonAttended = 'Хичээлдээ суусан';

  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// The screen's exported artwork — the three day marks, each the design's
/// own vector SVG. [lessonDay] and [lessonMissed] are committed unchanged;
/// [lessonAttended] is [lessonDay]'s paths recoloured to the frame's attended
/// mark — a white "A" and a `#F8623F` sparkle, sampled off the design's own
/// artwork — drawn at 16 x 15, because the supplied attended export (a PNG
/// inside an SVG pattern) paints nothing in flutter_svg.
abstract final class JuniorProgressIcons {
  static const String _dir = 'assets/icons';

  static const String lessonDay = '$_dir/junior_lesson_day.svg';
  static const String lessonMissed = '$_dir/junior_lesson_missed.svg';
  static const String lessonAttended = '$_dir/junior_lesson_attended.svg';
}
