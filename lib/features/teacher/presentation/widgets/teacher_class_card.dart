import 'package:flutter/material.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/track_badge.dart';
import '../../domain/teacher_class.dart';
import '../../domain/teacher_session.dart';
import '../teacher_home_strings.dart';
import '../teacher_schedule_strings.dart';

/// One of today's classes on Teacher Home, as the `teacher-homepage`
/// reference draws it (Issue #229): the track badge and the student count
/// on top, the cohort's name over the course title, then the room and the
/// time.
///
/// Every part is a verified field — track from the catalog's `level`, the
/// count from `enrolled_count`, the caption from the cohort's `name`, the
/// title from the course (Mongolian first), the room from `classroom.name`,
/// the time from `start_time`–`end_time`. A part with no data is left out:
/// no badge without a track, no room for an online cohort.
///
/// The reference's "Зар тараах" and "Ирц бүртгэх" actions are not drawn:
/// the first has no teacher endpoint, the second belongs to the attendance
/// task.
///
/// Teacher Schedule's session sheets draw the same card (Issue #231), with
/// the session's own times in [timeLabel] and, for a held session, its
/// attendance summary as [footer].
class TeacherClassCard extends StatelessWidget {
  const TeacherClassCard({
    required TeacherClass this.teacherClass,
    super.key,
    this.timeLabel,
    this.footer,
    this.showDetails = true,
    this.compactDetails = false,
  }) : caption = null,
       title = null,
       room = null;

  /// The same card for a session known only by its brief — an incoming
  /// schedule-change request's (Issue #453): the [caption] (cohort name),
  /// the [title] (course), the [room] and the [timeLabel], each drawn only
  /// when present. The brief carries no track or student count, so the card
  /// draws no track badge and no count capsule — none is invented.
  const TeacherClassCard.brief({
    required String this.title,
    required String this.timeLabel,
    super.key,
    this.caption,
    this.room,
    this.compactDetails = false,
  }) : teacherClass = null,
       footer = null,
       showDetails = true;

  /// The class, for the default card. Null for [TeacherClassCard.brief].
  final TeacherClass? teacherClass;

  /// [TeacherClassCard.brief]'s own parts; null for the default card, which
  /// reads them from [teacherClass].
  final String? caption;
  final String? title;
  final String? room;

  /// The time beside the clock. Null shows the cohort's
  /// `start_time`-`end_time`.
  final String? timeLabel;

  /// Drawn under the room and time, inside the card.
  final Widget? footer;

  /// Whether to draw the room and time. The Gradebook's class card
  /// (`dungiin-huudas`, Issue #233) ends at the course title.
  final bool showDetails;

  /// Sets the room and time a step smaller ([_compactDetailStyle]) so a date
  /// and times share the room's line — the incoming-request sheet
  /// (Issue #372). They still wrap where they do not fit.
  final bool compactDetails;

  @override
  Widget build(BuildContext context) {
    final cohort = teacherClass?.cohort;
    final track = teacherClass?.track;
    final title = cohort != null
        ? cohort.course.title.preferred ?? cohort.course.slug
        : this.title!;
    final caption = cohort != null ? cohort.name : this.caption;
    final room = cohort != null ? cohort.classroom?.name : this.room;
    final detailStyle = compactDetails ? _compactDetailStyle : _detailStyle;

    final palette = context.palette;
    final students = cohort == null
        ? null
        : CardCapsule(
            label: TeacherHomeStrings.students(cohort.enrolledCount),
            outline: palette.successOutline,
            fill: palette.successFill,
            ink: palette.successInk,
            horizontalPadding: 15,
          );
    final radius = BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.outline),
        borderRadius: radius,
      ),
      // The family's pattern behind the content, clipped to the card's
      // corners (Issue #408), as on every program/cohort card.
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            CardPattern(track: track),
            Padding(
              // The card family's inset: 16 at the sides, 24 at the top and
              // bottom, the 1pt outline included (Issue #404).
              padding: programCardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The badge left and the count right — the family's shared row
                  // (Issues #351, #404).
                  CardBadgeRow(track: track, trailing: students),
                  const SizedBox(height: _badgeToCaption),
                  if (caption != null)
                    Text(
                      caption,
                      style: _captionStyle.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  Text(
                    title,
                    style: _titleStyle.copyWith(color: palette.teacherTitle),
                  ),
                  if (showDetails) ...[
                    const SizedBox(height: _titleToDetails),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (room != null && room.isNotEmpty)
                          _Detail(
                            icon: AppIcons.mapPin,
                            label: room,
                            semanticsLabel: TeacherHomeStrings.room,
                            style: detailStyle,
                          ),
                        _Detail(
                          icon: AppIcons.clock,
                          label:
                              timeLabel ??
                              '${_clock(cohort!.startTime)}-${_clock(cohort.endTime)}',
                          semanticsLabel: TeacherHomeStrings.time,
                          style: detailStyle,
                        ),
                      ],
                    ),
                  ],
                  ?footer,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card for a scheduled [entry] (Issue #455): the class card for an own
/// session, or — for a session the teacher covers, which has no class —
/// the brief card from what the session says of itself. [footer] (the held
/// attendance summary) is for own sessions only.
TeacherClassCard scheduledSessionCard(
  ScheduledSession entry, {
  required String timeLabel,
  Widget? footer,
}) {
  final teacherClass = entry.teacherClass;
  if (teacherClass != null) {
    return TeacherClassCard(
      teacherClass: teacherClass,
      timeLabel: timeLabel,
      footer: footer,
    );
  }
  final covering = entry.covering;
  return TeacherClassCard.brief(
    title: TeacherScheduleStrings.sessionTitle(entry),
    // The cohort as the caption only when the title is the course's own.
    caption: covering?.courseTitle == null ? null : covering?.cohortName,
    room: covering?.room,
    timeLabel: timeLabel,
  );
}

/// A covered or covering session's label (Issue #455) — "Орлон заах" or
/// "Орлон заагдсан · {name}" — as a capsule over its card, drawn like the
/// day list's "Дууссан" from existing roles: the outline, the surface and
/// the accent text ink.
class AssignmentCapsule extends StatelessWidget {
  const AssignmentCapsule({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CardCapsule(
      label: label,
      outline: palette.outline,
      fill: palette.surface,
      ink: palette.accentText,
      horizontalPadding: 11,
    );
  }
}

/// A blue icon and bold label — the room and the time.
class _Detail extends StatelessWidget {
  const _Detail({
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    required this.style,
  });

  final IconData icon;
  final String label;
  final String semanticsLabel;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$semanticsLabel: $label',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: context.palette.accentText),
          const SizedBox(width: 4),
          // Wraps within the card rather than running off it: a long room
          // name used to, from 1.3× on a 320-wide phone (Issue #351).
          Flexible(
            child: Text(
              label,
              style: style.copyWith(color: context.palette.accentText),
            ),
          ),
        ],
      ),
    );
  }
}

/// `14:00:00` → `14:00`; anything not in that shape is shown as sent.
String _clock(String wire) {
  final parts = wire.split(':');
  return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : wire;
}

const double _badgeToCaption = 16;
const double _titleToDetails = 8;

/// The cohort's name over the course's, as on every card that names a course.
const TextStyle _captionStyle = AppTypography.caption;

/// The course's name — the same style on every card and page that shows one.
const TextStyle _titleStyle = AppTypography.cardTitle;

/// The room and time lines — values.
const TextStyle _detailStyle = AppTypography.bodyStrong;

/// The room and time a step smaller and untracked — an exception to the
/// type scale (`DESIGN_SYSTEM.md` §3). The incoming-request reference sets
/// "Room 204" and "11-р сарын 17 • 14:00-17:00" on one line, untracked; in
/// Manrope at 16, with the 0.25 tracking the theme's `bodyMedium` lends
/// every text, they measure 353 of the card's 329 — at 15, untracked, 328.
final TextStyle _compactDetailStyle = AppTypography.bodyStrong.copyWith(
  fontSize: 15,
  letterSpacing: 0,
);
