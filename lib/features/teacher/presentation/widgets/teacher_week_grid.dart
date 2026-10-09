import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/teacher_session.dart';

/// The `huvaari` reference's grid, in points at its 393pt width.
abstract final class TeacherWeekGridMetrics {
  /// The hour labels' column; the seven day columns share the rest.
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
        final dayWidth =
            (width - TeacherWeekGridMetrics.timeColumnWidth) /
            DateTime.daysPerWeek;

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPainter(
                    hours: last - first,
                    dayWidth: dayWidth,
                    // The grid's hairlines are rules (proposal §12).
                    line: context.palette.divider,
                  ),
                ),
              ),
              for (var hour = first; hour < last; hour++)
                Positioned(
                  left: 0,
                  width: TeacherWeekGridMetrics.timeColumnWidth - 10,
                  top:
                      TeacherWeekGridMetrics.topInset +
                      (hour - first) * TeacherWeekGridMetrics.hourHeight +
                      8,
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    textAlign: TextAlign.right,
                    style: _hourStyle.copyWith(
                      color: context.palette.textStrong,
                    ),
                  ),
                ),
              for (final placement in placements)
                Positioned(
                  left:
                      TeacherWeekGridMetrics.timeColumnWidth +
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
    final course = entry.teacherClass.cohort.course;
    final title = course.title.preferred ?? course.slug;
    final session = entry.session;
    final palette = context.palette;
    // A session block is the band's blue (`accent`) with `onPrimary` ink; a
    // held one is `scheduleHeld` with `scheduleHeldInk`.
    final ink = held ? palette.scheduleHeldInk : palette.onPrimary;
    final style = _blockStyle.copyWith(color: ink);

    return Semantics(
      button: true,
      label: '$title, ${session.startLabel}-${session.endLabel}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: held ? palette.scheduleHeld : palette.accent,
            borderRadius: held ? null : BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.fromLTRB(4, 5, 4, 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The time needs its two lines; a block too short for both
              // keeps the title alone.
              final showTime = constraints.maxHeight >= 48;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRect(
                      child: Text(title, style: style, softWrap: true),
                    ),
                  ),
                  if (showTime)
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

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.hours,
    required this.dayWidth,
    required this.line,
  });

  final int hours;
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
      for (var d = 0; d <= DateTime.daysPerWeek; d++)
        TeacherWeekGridMetrics.timeColumnWidth + d * dayWidth,
    ];
    for (final x in columns) {
      final at = math.min(x, size.width - 0.5);
      canvas.drawLine(Offset(at, 0), Offset(at, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.hours != hours || old.dayWidth != dayWidth || old.line != line;
}

final TextStyle _hourStyle = AppTypography.cardSupporting.copyWith(
  fontSize: 12,
  height: 17 / 12,
  fontWeight: FontWeight.w400,
);

final TextStyle _blockStyle = AppTypography.programTitle.copyWith(
  fontSize: 11,
  height: 14 / 11,
  fontWeight: FontWeight.w700,
);
