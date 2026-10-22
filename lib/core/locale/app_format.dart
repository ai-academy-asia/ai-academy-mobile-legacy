import 'package:intl/intl.dart';

import 'app_locale_controller.dart';

/// Dates, times and weekday names in the selected language (Issue #505) —
/// only the formats the app draws, read without a `BuildContext`, so a
/// repository can use them as well as a screen.
///
/// The language is [AppLocaleController.instance]'s, the one `L10n.current`
/// and the root `MaterialApp` follow. A value formatted while drawing
/// follows a language change at once (`L10nRebuildScope`); one formatted
/// when data loads keeps its language until it is formatted again.
///
/// **Mongolian** is the app's own hand-written output, unchanged — including
/// where screens disagree (`dd/MM` on Home, `MM/dd` elsewhere). **English**
/// is `intl`'s `en_US` patterns, which need no locale data loaded first. In
/// both, clocks are 24-hour, every value keeps the fields it had (a year only
/// where one was shown), and nothing converts time zones: each caller passes
/// the instant it already chose, local or not.
abstract final class AppFormat {
  static bool get _english => AppLocaleController.instance.english;

  /// `intl`'s English, built in — `en` alone needs locale data loaded first.
  static const String _englishLocale = 'en_US';

  // --- Times ----------------------------------------------------------------

  /// `09:05` — 24-hour, two-digit, in both languages.
  static String clock(int hour, int minute) => '${_two(hour)}:${_two(minute)}';

  /// [time]'s hours and minutes as a [clock].
  static String time(DateTime time) => clock(time.hour, time.minute);

  /// An hour on the hour, `07:00`.
  static String hour(int hour) => clock(hour, 0);

  // --- Dates ----------------------------------------------------------------

  /// A day without its year. Mongolian: `08/06` (`MM/dd`), or `06/08`
  /// (`dd/MM`) with [dayFirst] — Home's order. English: `Aug 6` either way.
  static String shortDate(DateTime date, {bool dayFirst = false}) {
    if (_english) return DateFormat.MMMd(_englishLocale).format(date);
    return dayFirst
        ? '${_two(date.day)}/${_two(date.month)}'
        : '${_two(date.month)}/${_two(date.day)}';
  }

  /// A day without its year, the month spelled out. Mongolian:
  /// `11-р сарын 17`. English: `November 17`.
  static String longDate(DateTime date) => _english
      ? DateFormat.MMMMd(_englishLocale).format(date)
      : '${date.month}-р сарын ${date.day}';

  /// A day with its year. Mongolian: `2026/07/21`, the parts joined by
  /// [mongolianSeparator]. English: `Jul 21, 2026`.
  static String dateWithYear(
    DateTime date, {
    required String mongolianSeparator,
  }) {
    if (_english) return DateFormat.yMMMd(_englishLocale).format(date);
    final separator = mongolianSeparator;
    return '${date.year}$separator${_two(date.month)}$separator'
        '${_two(date.day)}';
  }

  /// A month and its year. Mongolian: `Наймдугаар сар, 2026`. English:
  /// `August 2026`.
  static String monthYear(DateTime month) => _english
      ? DateFormat.yMMMM(_englishLocale).format(month)
      : '${_mongolianMonths[month.month - 1]} сар, ${month.year}';

  /// "Today, 14:20" on [now]'s calendar day, otherwise [shortDate] and the
  /// time — `08/06, 14:20`, or `Aug 6, 14:20` in English. "Today" is the
  /// design's own word in both languages (wording is not this formatter's).
  static String todayOrDate(DateTime time, {required DateTime now}) {
    final sameDay =
        time.year == now.year && time.month == now.month && time.day == now.day;
    return sameDay
        ? 'Today, ${AppFormat.time(time)}'
        : '${shortDate(time)}, ${AppFormat.time(time)}';
  }

  /// How long ago [then] was: `7d`, `3h`, `5m` — never under `1m`. The same
  /// short form in both languages.
  static String age(DateTime then, DateTime now) {
    final elapsed = now.difference(then);
    if (elapsed.inDays >= 1) return '${elapsed.inDays}d';
    if (elapsed.inHours >= 1) return '${elapsed.inHours}h';
    final minutes = elapsed.inMinutes;
    return '${minutes < 1 ? 1 : minutes}m';
  }

  // --- Weekdays -------------------------------------------------------------

  /// [weekday] (`DateTime.monday` … `DateTime.sunday`) abbreviated.
  /// Mongolian: `Да`, `Мя`, `Лх`, `Пү`, `Ба`, `Бя`, `Ня`. English: `Mon` …
  /// `Sun`.
  static String weekday(int weekday) => _english
      ? DateFormat.E(_englishLocale).format(_aDay(weekday))
      : _mongolianWeekdays[weekday - 1];

  /// [weekday] as one letter: `M`, `T`, `W`, `T`, `F`, `S`, `S`. The same in
  /// Mongolian, where the Junior calendar's frame draws these Latin letters.
  static String weekdayLetter(int weekday) => _english
      ? DateFormat('EEEEE', _englishLocale).format(_aDay(weekday))
      : _weekdayLetters[weekday - 1];

  /// The seven [weekday]s in order, from [first].
  static List<String> weekdays({required int first}) => [
    for (var i = 0; i < DateTime.daysPerWeek; i++)
      weekday(_nthWeekdayFrom(first, i)),
  ];

  /// The seven [weekdayLetter]s in order, from [first].
  static List<String> weekdayLetters({required int first}) => [
    for (var i = 0; i < DateTime.daysPerWeek; i++)
      weekdayLetter(_nthWeekdayFrom(first, i)),
  ];

  static int _nthWeekdayFrom(int first, int n) =>
      (first - 1 + n) % DateTime.daysPerWeek + 1;

  /// A day that falls on [weekday]: 1 January 2024 was a Monday.
  static DateTime _aDay(int weekday) => DateTime(2024, 1, weekday);

  static String _two(int value) => value.toString().padLeft(2, '0');

  /// Даваа, Мягмар, Лхагва, Пүрэв, Баасан, Бямба, Ням — Monday first, as
  /// `DateTime.weekday` counts. Only `Да` is confirmed by a design; the rest
  /// follow it, the first two letters of each day's name.
  static const List<String> _mongolianWeekdays = [
    'Да',
    'Мя',
    'Лх',
    'Пү',
    'Ба',
    'Бя',
    'Ня',
  ];

  /// Monday first, as `DateTime.weekday` counts.
  static const List<String> _weekdayLetters = [
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  /// The standard Mongolian ordinal month names, as Junior Progress writes
  /// them (the frame draws August, "Наймдугаар").
  static const List<String> _mongolianMonths = [
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
}
