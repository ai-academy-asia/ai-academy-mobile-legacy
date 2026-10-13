import 'package:flutter/material.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/track_badge.dart';
import '../../domain/teacher_class.dart';
import '../teacher_home_strings.dart';

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
    required this.teacherClass,
    super.key,
    this.timeLabel,
    this.footer,
    this.showDetails = true,
  });

  final TeacherClass teacherClass;

  /// The time beside the clock. Null shows the cohort's
  /// `start_time`-`end_time`.
  final String? timeLabel;

  /// Drawn under the room and time, inside the card.
  final Widget? footer;

  /// Whether to draw the room and time. The Gradebook's class card
  /// (`dungiin-huudas`, Issue #233) ends at the course title.
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    final cohort = teacherClass.cohort;
    final track = teacherClass.track;
    final title = cohort.course.title.preferred ?? cohort.course.slug;
    final room = cohort.classroom?.name;

    final palette = context.palette;
    final students = CardCapsule(
      label: TeacherHomeStrings.students(cohort.enrolledCount),
      outline: palette.successOutline,
      fill: palette.successFill,
      ink: palette.successInk,
      horizontalPadding: 15,
    );
    return Container(
      // 24 inside the card's edge on every side, the 1pt outline included.
      padding: const EdgeInsets.fromLTRB(15, 23, 15, 23),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The badge left and the count right on one line, at least the
          // badge's 32 tall; when a larger text size leaves no room for
          // both, the count wraps under the badge (Issue #351). At the
          // default size this is the one 32-tall row it always was.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: trackBadgeHeight),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: track == null
                    ? WrapAlignment.end
                    : WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                // A lone count is centred in the 32, as the row centred it.
                runAlignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [if (track != null) TrackBadge(track), students],
              ),
            ),
          ),
          const SizedBox(height: _badgeToCaption),
          Text(
            cohort.name,
            style: _captionStyle.copyWith(color: palette.textSecondary),
          ),
          Text(title, style: _titleStyle.copyWith(color: palette.teacherTitle)),
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
                  ),
                _Detail(
                  icon: AppIcons.clock,
                  label:
                      timeLabel ??
                      '${_clock(cohort.startTime)}-${_clock(cohort.endTime)}',
                  semanticsLabel: TeacherHomeStrings.time,
                ),
              ],
            ),
          ],
          ?footer,
        ],
      ),
    );
  }
}

/// A blue icon and bold label — the room and the time.
class _Detail extends StatelessWidget {
  const _Detail({
    required this.icon,
    required this.label,
    required this.semanticsLabel,
  });

  final IconData icon;
  final String label;
  final String semanticsLabel;

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
              style: _detailStyle.copyWith(color: context.palette.accentText),
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
