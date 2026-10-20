import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/teacher_session.dart';
import '../teacher_schedule_strings.dart';

/// The `huvaari` reference's grid, in points at its 393pt width.
abstract final class TeacherWeekGridMetrics {
  /// The hour labels' column at the reference's text size; the seven day
  /// columns share the rest. A larger system text size can widen it — see
  /// [timeColumnWidthOf].
  static const double timeColumnWidth = 64;

  /// One hour of the grid.
  static const double hourHeight = 64;

  /// From the strip's bottom edge to the first hour's line.
  static const double topInset = 18;

  /// The reference's span — 07:00 to the line closing 22:00's row. A week
  /// with a session outside it widens the span to fit (see [hourSpan]).
  static const int firstHour = 7;
  static const int lastHour = 23;
}

/// An hour's label, `07:00`.
String hourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';

/// Between an hour label's right edge and the day columns.
const double _hourLabelGap = 10;

/// The hour labels' column for this context's text size: the reference's
/// [TeacherWeekGridMetrics.timeColumnWidth], or wider when the widest label
/// needs it (Issue #355) — so a label stays `HH:mm` on one line rather than
/// wrapping mid-number, and the text size is never capped. At the default
/// size, and to about 1.6×, it is the reference's 64. The week strip above
/// the grid aligns its days with it, so both ask here.
double timeColumnWidthOf(BuildContext context) {
  // Measured as the label is drawn: a `Text` merges its style into the
  // ambient one, which can add letter spacing.
  final style = DefaultTextStyle.of(
    context,
  ).style.merge(_hourStyle.copyWith(color: context.palette.textStrong));
  var widest = 0.0;
  for (var hour = 0; hour < 24; hour++) {
    final painter = TextPainter(
      text: TextSpan(text: hourLabel(hour), style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    widest = math.max(widest, painter.width);
    painter.dispose();
  }
  return math.max(
    TeacherWeekGridMetrics.timeColumnWidth,
    (widest + _hourLabelGap).ceilToDouble(),
  );
}

/// The hours the grid draws, `(first, last)`: the reference's 07:00–23:00
/// widened to whole hours that hold every session of [sessions].
(int, int) hourSpan(List<ScheduledSession> sessions) {
  var first = TeacherWeekGridMetrics.firstHour;
  var last = TeacherWeekGridMetrics.lastHour;
  for (final entry in sessions) {
    final session = entry.session;
    first = math.min(first, session.start.$1);
    final endHour = session.end.$1 + (session.end.$2 > 0 ? 1 : 0);
    last = math.max(last, math.min(endHour, 24));
  }
  return (first, last);
}

/// Where one session sits: its day's column, and its lane when sessions on
/// that day overlap — they share the column side by side rather than cover
/// one another.
class SessionPlacement {
  const SessionPlacement({
    required this.entry,
    required this.day,
    required this.top,
    required this.height,
    required this.lane,
    required this.lanes,
  });

  final ScheduledSession entry;

  /// 0 for the week's Sunday … 6 for its Saturday.
  final int day;

  /// From the grid's top edge, and the block's height — both from the
  /// session's real start and end, at [TeacherWeekGridMetrics.hourHeight]
  /// per hour.
  final double top;
  final double height;

  final int lane;
  final int lanes;
}

/// Places the week's [sessions] on a grid whose first line is [firstHour].
/// Sessions outside the week starting [weekStart] are left out.
List<SessionPlacement> placeSessions(
  List<ScheduledSession> sessions, {
  required DateTime weekStart,
  required int firstHour,
}) {
  const perMinute = TeacherWeekGridMetrics.hourHeight / 60;
  final placements = <SessionPlacement>[];

  for (var day = 0; day < DateTime.daysPerWeek; day++) {
    final date = DateTime(weekStart.year, weekStart.month, weekStart.day + day);
    final ofDay =
        sessions.where((e) => isSameDay(e.session.date, date)).toList()
          ..sort((a, b) => a.session.startsAt.compareTo(b.session.startsAt));

    // Overlapping runs share the column: each session takes the first lane
    // free at its start, and a run's lane count is its widest point.
    var run = <(ScheduledSession, int)>[];
    var runEnd = DateTime(0);
    void closeRun() {
      final lanes = run.fold(0, (most, e) => math.max(most, e.$2 + 1));
      for (final (entry, lane) in run) {
        final session = entry.session;
        final startMinutes =
            (session.start.$1 - firstHour) * 60 + session.start.$2;
        final minutes = session.endsAt.difference(session.startsAt).inMinutes;
        placements.add(
          SessionPlacement(
            entry: entry,
            day: day,
            top: TeacherWeekGridMetrics.topInset + startMinutes * perMinute,
            height: math.max(minutes, 15) * perMinute,
            lane: lane,
            lanes: lanes,
          ),
        );
      }
      run = [];
    }

    final laneEnds = <DateTime>[];
    for (final entry in ofDay) {
      final session = entry.session;
      if (run.isNotEmpty && !session.startsAt.isBefore(runEnd)) {
        closeRun();
        laneEnds.clear();
      }
      var lane = laneEnds.indexWhere((end) => !session.startsAt.isBefore(end));
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(session.endsAt);
      } else {
        laneEnds[lane] = session.endsAt;
      }
      run.add((entry, lane));
      if (session.endsAt.isAfter(runEnd)) runEnd = session.endsAt;
    }
    if (run.isNotEmpty) closeRun();
  }
  return placements;
}

/// [day]'s earliest session block on the grid [TeacherWeekGrid] draws for
/// [sessions] — the same [hourSpan] and [placeSessions] geometry, so its
/// [SessionPlacement.top] is where that block really is. Only blocks
/// [where] accepts are candidates; the geometry is still the whole grid's.
/// Null when [day] has no such session in the week starting [weekStart]
/// (Issues #465, #467).
SessionPlacement? firstSessionPlacement(
  List<ScheduledSession> sessions, {
  required DateTime weekStart,
  required DateTime day,
  bool Function(ScheduledSession entry)? where,
}) {
  final (first, _) = hourSpan(sessions);
  SessionPlacement? earliest;
  for (final placement in placeSessions(
    sessions,
    weekStart: weekStart,
    firstHour: first,
  )) {
    if (!isSameDay(placement.entry.session.date, day)) continue;
    if (where != null && !where(placement.entry)) continue;
    if (earliest == null || placement.top < earliest.top) earliest = placement;
  }
  return earliest;
}

/// The top edge, from the grid's own top, of [firstSessionPlacement]'s
/// block; null when there is none.
double? firstSessionTop(
  List<ScheduledSession> sessions, {
  required DateTime weekStart,
  required DateTime day,
  bool Function(ScheduledSession entry)? where,
}) => firstSessionPlacement(
  sessions,
  weekStart: weekStart,
  day: day,
  where: where,
)?.top;

/// The hourly week grid under the strip: hour labels down the left, seven
/// day columns, and a block per session (Issue #231).
///
/// A session not yet over is the reference's bright blue block; one whose
/// end has passed is the light block. Each block names the course and its
/// time, and a tap hands its session to [onSessionTap].
class TeacherWeekGrid extends StatelessWidget {
  const TeacherWeekGrid({
    required this.weekStart,
    required this.sessions,
    required this.now,
    required this.onSessionTap,
    super.key,
  });

  final DateTime weekStart;
  final List<ScheduledSession> sessions;
  final DateTime now;
  final ValueChanged<ScheduledSession> onSessionTap;

  @override
  Widget build(BuildContext context) {
    final (first, last) = hourSpan(sessions);
    final placements = placeSessions(
      sessions,
      weekStart: weekStart,
      firstHour: first,
    );
    final height =
        TeacherWeekGridMetrics.topInset +
        (last - first) * TeacherWeekGridMetrics.hourHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final timeColumn = timeColumnWidthOf(context);
        final dayWidth = (width - timeColumn) / DateTime.daysPerWeek;

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPainter(
                    hours: last - first,
                    timeColumn: timeColumn,
                    dayWidth: dayWidth,
                    // The grid's hairlines are rules (proposal §12).
                    line: context.palette.divider,
                  ),
                ),
              ),
              for (var hour = first; hour < last; hour++)
                Positioned(
                  left: 0,
                  width: timeColumn - _hourLabelGap,
                  top:
                      TeacherWeekGridMetrics.topInset +
                      (hour - first) * TeacherWeekGridMetrics.hourHeight +
                      8,
                  child: Text(
                    hourLabel(hour),
                    textAlign: TextAlign.right,
                    // The column is as wide as the widest label, so one line
                    // always fits; this only guards against a mid-number
                    // break.
                    maxLines: 1,
                    style: _hourStyle.copyWith(
                      color: context.palette.textStrong,
                    ),
                  ),
                ),
              for (final placement in placements)
                Positioned(
                  left:
                      timeColumn +
                      placement.day * dayWidth +
                      placement.lane * dayWidth / placement.lanes +
                      1,
                  width: dayWidth / placement.lanes - 3,
                  top: placement.top,
                  height: placement.height,
                  child: SessionBlock(
                    entry: placement.entry,
                    held: placement.entry.session.isOverAt(now),
                    onTap: () => onSessionTap(placement.entry),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One session on the grid: the course title at the top, its time at the
/// bottom — bright blue while it is still ahead or under way, light once
/// it is over.
class SessionBlock extends StatelessWidget {
  const SessionBlock({
    required this.entry,
    required this.held,
    required this.onTap,
    super.key,
  });

  final ScheduledSession entry;
  final bool held;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A covered or covering session (Issue #455) leads with its label —
    // "Орлон заах" or "Орлон заагдсан · {name}" — above the title; an
    // ordinary one draws exactly as before.
    final label = TeacherScheduleStrings.assignmentLabel(entry);
    final title = blockText(entry);
    final session = entry.session;
    final palette = context.palette;
    // A session block is the band's blue (`accent`) with `onPrimary` ink; a
    // held one is `scheduleHeld` with `scheduleHeldInk`.
    final ink = held ? palette.scheduleHeldInk : palette.onPrimary;
    final style = _blockStyle.copyWith(color: ink);

    return Semantics(
      button: true,
      label: [
        ?label,
        TeacherScheduleStrings.sessionTitle(entry),
        '${session.startLabel}-${session.endLabel}',
      ].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: held ? palette.scheduleHeld : palette.accent,
            borderRadius: held ? null : BorderRadius.circular(4),
          ),
          padding: _blockPadding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fit = _BlockFit.measure(
                context,
                style: style,
                start: session.startLabel,
                end: session.endLabel,
                space: constraints.biggest,
              );
              // Too small for any legible text: the block alone, still
              // tappable and still read out in full (Issue #355).
              if (!fit.showTime && fit.titleLines == 0) {
                return const SizedBox.expand();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: fit.titleLines == 0
                        ? const SizedBox.shrink()
                        : ClipRect(
                            child: Text(
                              title,
                              style: style,
                              softWrap: true,
                              maxLines: fit.titleLines,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                  ),
                  if (fit.showTime)
                    Text(
                      '${session.startLabel}\n-${session.endLabel}',
                      style: style,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// What a [SessionBlock] writes above its time: the title, led by the
/// session's assignment label on its own line when it has one (Issue #455).
String blockText(ScheduledSession entry) {
  final title = TeacherScheduleStrings.sessionTitle(entry);
  final label = TeacherScheduleStrings.assignmentLabel(entry);
  return label == null ? title : '$label\n$title';
}

/// Inside a session block, around its text.
const EdgeInsets _blockPadding = EdgeInsets.fromLTRB(4, 5, 4, 6);

/// Whether every session of the week can present its time or its title
/// legibly in the block the grid would give it, at this context's text size
/// and a grid [width] wide (Issue #357) — laid out exactly as
/// [TeacherWeekGrid] lays it out: its real duration, its lane, its title.
///
/// A block is legible when its time fits (see [_BlockFit]), or when at
/// least one whole title line fits *and* the title's first word fits that
/// line — so its first line is a word, not a fragment like "Х…". The
/// schedule screen reads this, above the default text size, to decide
/// between the week grid and a single day's list.
bool weekBlocksLegible(
  BuildContext context, {
  required List<ScheduledSession> sessions,
  required DateTime weekStart,
  required double width,
}) {
  if (sessions.isEmpty) return true;
  final (first, _) = hourSpan(sessions);
  final dayWidth = (width - timeColumnWidthOf(context)) / DateTime.daysPerWeek;
  final style = _blockStyle.copyWith(color: context.palette.onPrimary);
  final drawn = DefaultTextStyle.of(context).style.merge(style);
  for (final placement in placeSessions(
    sessions,
    weekStart: weekStart,
    firstHour: first,
  )) {
    final space = Size(
      dayWidth / placement.lanes - 3 - _blockPadding.horizontal,
      placement.height - _blockPadding.vertical,
    );
    final session = placement.entry.session;
    final fit = _BlockFit.measure(
      context,
      style: style,
      start: session.startLabel,
      end: session.endLabel,
      space: space,
    );
    if (fit.showTime) continue;
    final title = blockText(placement.entry);
    final firstWord = title.trim().split(RegExp(r'\s+')).first;
    final painter = TextPainter(
      text: TextSpan(text: firstWord, style: drawn),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final wordFits = painter.width <= space.width;
    painter.dispose();
    if (fit.titleLines > 0 && wordFits) continue;
    return false;
  }
  return true;
}

/// What a session block can show legibly in [space] (Issue #355), measured
/// with the block's own style at the user's text size — never a guess from
/// the session's duration.
///
/// The time comes first, as the block always drew it: it shows only when
/// each of its two lines, `09:00` and `-10:00`, fits the width on one line
/// and both fit the height — so a time is never broken mid-number. The title
/// takes whole lines of what is left, ending in an ellipsis when it is cut.
/// When neither fits, the block shows no text.
class _BlockFit {
  const _BlockFit({required this.showTime, required this.titleLines});

  factory _BlockFit.measure(
    BuildContext context, {
    required TextStyle style,
    required String start,
    required String end,
    required Size space,
  }) {
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    // Measured as the block's `Text` draws it: merged into the ambient
    // style, which can add letter spacing.
    final drawn = DefaultTextStyle.of(context).style.merge(style);
    (double, double) measure(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: drawn),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final size = (painter.width, painter.preferredLineHeight);
      painter.dispose();
      return size;
    }

    final (startWidth, line) = measure(start);
    final (endWidth, _) = measure('-$end');
    final showTime =
        startWidth <= space.width &&
        endWidth <= space.width &&
        2 * line <= space.height;
    final left = space.height - (showTime ? 2 * line : 0);
    return _BlockFit(
      showTime: showTime,
      titleLines: math.max(0, (left / line + 1e-6).floor()),
    );
  }

  final bool showTime;
  final int titleLines;
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.hours,
    required this.timeColumn,
    required this.dayWidth,
    required this.line,
  });

  final int hours;

  /// The hour labels' column — see [timeColumnWidthOf].
  final double timeColumn;
  final double dayWidth;

  /// The hairlines' colour — passed in: a painter has no context.
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1;

    for (var i = 0; i <= hours; i++) {
      final y =
          TeacherWeekGridMetrics.topInset +
          i * TeacherWeekGridMetrics.hourHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final columns = <double>[
      0.5,
      for (var d = 0; d <= DateTime.daysPerWeek; d++) timeColumn + d * dayWidth,
    ];
    for (final x in columns) {
      final at = math.min(x, size.width - 0.5);
      canvas.drawLine(Offset(at, 0), Offset(at, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.hours != hours ||
      old.timeColumn != timeColumn ||
      old.dayWidth != dayWidth ||
      old.line != line;
}

/// The hour labels: a dense-grid exception to the type scale
/// (`DESIGN_SYSTEM.md` §3), sized to the grid's hour rows.
final TextStyle _hourStyle = AppTypography.supporting.copyWith(
  fontSize: 12,
  height: 17 / 12,
  fontWeight: FontWeight.w400,
);

/// A session block's course title: a dense-grid exception to the type scale
/// (`DESIGN_SYSTEM.md` §3), sized to the block.
final TextStyle _blockStyle = AppTypography.bodyStrong.copyWith(
  fontSize: 11,
  height: 14 / 11,
);
