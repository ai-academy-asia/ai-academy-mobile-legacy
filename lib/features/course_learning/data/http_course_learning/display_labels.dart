part of '../http_course_learning_repository.dart';

/// The badge copy for a `recording` lesson — the one type the design names a
/// badge for ("Live Classroom Recording", the sample's own label). `video`
/// and `reading` have no copy, so their badge is left off rather than
/// invented.
const String _recordingBadgeLabel = 'Live Classroom Recording';

/// Who a note's author is to the student reading it — always themselves, as
/// §2.5's note is the signed-in student's own. The same "Me" the sample and
/// `NoteTab` use.
const String _noteAuthorLabel = 'Me';

/// The label the Mentor Feedback card draws under a `teacher` mentor — the
/// sample's own "Lead Mentor". §2.6 sends the role as an enum and leaves the
/// wording to the client; any other role has no copy, so its label is left
/// empty rather than invented.
const String _teacherRoleLabel = 'Lead Mentor';

/// "Today, 14:20" — the contract's §0 example of what the client formats a
/// timestamp as, and the sample's own label — for a time on [now]'s
/// calendar day; "08/06, 14:20" otherwise, the `MM/dd` the module schedule
/// label already uses.
String _timestampLabel(DateTime local, {required DateTime now}) {
  String two(int value) => value.toString().padLeft(2, '0');
  final time = '${two(local.hour)}:${two(local.minute)}';
  final sameDay =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  return sameDay
      ? 'Today, $time'
      : '${two(local.month)}/${two(local.day)}, $time';
}

/// A lesson's `duration_seconds` as its label (Issue #477): the key is
/// always sent, and `null` when the lesson was authored without one — the
/// backend's `create_lesson` sets none — which is no label at all, `''`,
/// rather than an invented `0:00`. Otherwise [_durationLabel]. A missing key
/// or a non-integer is a server fault, as before.
String _durationLabelOf(Map<String, dynamic> json) {
  if (!json.containsKey('duration_seconds')) {
    throw const CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'lesson.duration_seconds: missing',
    );
  }
  if (json['duration_seconds'] == null) return '';
  return _durationLabel(_requireInt(json, 'lesson.duration_seconds'));
}

/// `duration_seconds` as the lesson row draws it: `M:SS` under an hour,
/// `H:MM:SS` from one up — `0` is `"0:00"`, `1455` is `"24:15"`, `3725` is
/// `"1:02:05"`. The contract sends integers and no pre-formatted label, so
/// the client composes it. A negative duration is a server fault.
String _durationLabel(int seconds) {
  if (seconds < 0) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'lesson.duration_seconds: expected 0 or more, got $seconds',
    );
  }

  String two(int value) => value.toString().padLeft(2, '0');

  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  return hours > 0
      ? '$hours:${two(minutes)}:${two(secs)}'
      : '$minutes:${two(secs)}';
}

/// `{"date": "2026-08-06", "start_time": "09:00"}` into the card's own
/// `"08/06 • Пү • 09:00"`.
///
/// The format is the one the Figma module card draws and the contract quotes
/// back — `MM/dd`, the weekday abbreviated in Mongolian, then the start time.
/// Only `"Да"` (Даваа) is confirmed by the design; the other six follow that
/// one's convention, the first two letters of the Mongolian day name. Kept in
/// `data/` beside the mapping rather than in `CourseLearningStrings` because
/// `scheduleLabel` is a pre-formatted model field, which is where
/// `SampleCourseLearningRepository` already writes its own copy of this label
/// — and because `data/` must not import `presentation/`.
///
/// Absent schedule means a self-paced module, which the contract says sends
/// `null`: the card then draws no date line. An empty string rather than a
/// nullable field, so the widget the Figma pass measured stays untouched.
String _scheduleLabel(Object? schedule) {
  if (schedule == null) return '';
  if (schedule is! Map<String, dynamic>) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail:
          'module.schedule: expected an object or null, got ${schedule.runtimeType}',
    );
  }

  final date = _requireString(schedule, 'module.schedule.date');
  final startTime = _requireString(schedule, 'module.schedule.start_time');

  final DateTime parsed;
  try {
    parsed = DateTime.parse(date);
  } on FormatException {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'module.schedule.date: not a date ("$date")',
    );
  }

  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  // `DateTime.weekday` is 1 = Monday … 7 = Sunday.
  final weekday = _mongolianWeekdays[parsed.weekday - 1];
  // Tolerates `"09:00:00"` as well as the contract's `"09:00"` — the card
  // draws hours and minutes either way.
  final time = startTime.length > 5 ? startTime.substring(0, 5) : startTime;

  return '$month/$day • $weekday • $time';
}

/// Даваа, Мягмар, Лхагва, Пүрэв, Баасан, Бямба, Ням — Monday-first, matching
/// `DateTime.weekday`.
const List<String> _mongolianWeekdays = [
  'Да',
  'Мя',
  'Лх',
  'Пү',
  'Ба',
  'Бя',
  'Ня',
];
