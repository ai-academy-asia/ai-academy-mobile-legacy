import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_palette.dart';
import '../../domain/home_dashboard.dart';
import '../home_strings.dart';
import 'home_badges.dart';
import 'home_pill_button.dart';

// Measured off the Figma Home frames at 1:1. Figma strokes sit inside the
// frame and take no layout space, so every inset below is the reference's
// less the 1pt border the Container here does account for.

/// Space above the badge row and below the progress bar, and above the
/// lesson heading and below the attendance action — 24 from the card's outer
/// edge (and from the divider) in every frame.
const double _sectionPaddingV = 24;

/// Content sits 16 in from the card's outer edge.
const double _paddingH = 16;

/// The badge row, the caption, the progress row: 24 between each group.
const double _groupGap = 24;

/// The track badge row — see [TrackBadge] and [HomeCapsule].
const double _badgeHeight = homeBadgeHeight;

/// The progress row (the taller of its two lines), the gap under it, the bar.
const double _progressRowHeight = 20;
const double _barGap = 8;
const double _barHeight = 8;

/// The lesson heading's row is as tall as the "Live" pill, whether or not the
/// pill is drawn, so the time under it never moves between states.
const double _lessonHeadingHeight = 24;

/// Time to the live prompt, and the last line to the action.
const double _hintGap = 4;
const double _actionGap = 16;

/// The attendance action: 40 tall, not the statistic cards' 36.
const double _actionHeight = 40;

/// The cohort the student is studying in — the dashboard's headline card.
///
/// Two stacked sections inside one rounded surface, split by a full-bleed
/// rule, exactly as the reference draws it: the summary (track badge, status,
/// cohort caption, course name, module progress) over the next lesson and its
/// attendance action. The summary sits on a faint blue wash with the same
/// exported shapes `CohortCard` draws, not redrawn.
///
/// Each part is skipped when its data is absent rather than filled in with a
/// placeholder: no progress means no bar, no scheduled lesson means the whole
/// lower section is left off. See [HomeDashboard] for why a section can be
/// absent at all.
class ProgramCard extends StatelessWidget {
  const ProgramCard({
    required this.program,
    super.key,
    this.live = false,
    this.onRegisterAttendance,
    this.onTap,
  });

  final EnrolledProgram program;

  /// The next lesson is under way. Puts the "Live" badge beside the heading,
  /// adds the prompt line, and turns the attendance action on.
  final bool live;

  /// What the attendance action does. The button only accepts a press while
  /// [live] — there is nothing to register otherwise.
  final VoidCallback? onRegisterAttendance;

  /// Opens the programme's `CourseModuleListScreen`. Null leaves the card
  /// inert, same as `CourseCard.onTap`.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final nextLesson = program.nextLesson;
    final radius = BorderRadius.circular(AppDimens.homeCardRadius);

    return Material(
      color: context.palette.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: context.palette.outline),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Summary(program: program),
                if (nextLesson != null) ...[
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: context.palette.outline,
                  ),
                  _NextLessonSection(
                    lesson: nextLesson,
                    live: live,
                    onRegisterAttendance: onRegisterAttendance,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The card's upper half: badges, the cohort and its course, and progress.
class _Summary extends StatelessWidget {
  const _Summary({required this.program});

  final EnrolledProgram program;

  @override
  Widget build(BuildContext context) {
    final progress = program.progress;

    return Stack(
      children: [
        // The decorative shapes, 1:1 from the top-left: a 12% blue tint with
        // the white blocks cut out of it, which is also what shades the
        // section from near-white at the leading edge to pale blue at the
        // trailing one. Drawn at full strength on the card's white.
        Positioned.fill(
          child: SvgPicture.asset(
            HomeIcons.cardBackground,
            fit: BoxFit.none,
            alignment: Alignment.topLeft,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _paddingH - AppDimens.borderWidth,
            _sectionPaddingV - AppDimens.borderWidth,
            _paddingH - AppDimens.borderWidth,
            _sectionPaddingV,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _badgeHeight,
                child: Row(
                  // The pill hangs from the top of the badge row, as the
                  // reference draws it, not centred on it.
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (program.uiMode case final uiMode?) TrackBadge(uiMode),
                    const Spacer(),
                    _StatusPill(program.status),
                  ],
                ),
              ),
              const SizedBox(height: _groupGap),

              Text(
                program.cohortName,
                style: _captionStyle.copyWith(
                  color: context.palette.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                program.courseTitle,
                style: _titleStyle.copyWith(color: context.palette.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (progress != null) ...[
                const SizedBox(height: _groupGap),
                SizedBox(
                  height: _progressRowHeight,
                  child: Row(
                    children: [
                      // No module count to caption the bar with — only
                      // `Enrollment.progressPct`, a bare percentage — leaves
                      // the percentage alone at the trailing edge, where it
                      // sits when the count is also drawn.
                      Expanded(
                        child:
                            progress.completed != null && progress.total != null
                            ? Text(
                                HomeStrings.modules(
                                  progress.completed!,
                                  progress.total!,
                                ),
                                style: _modulesStyle.copyWith(
                                  color: context.palette.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        HomeStrings.percentComplete(progress.percent),
                        style: _percentStyle.copyWith(
                          color: context.palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: _barGap),
                _ProgressBar(fraction: progress.fraction),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The card's lower half: when the cohort next meets, and the attendance
/// action.
class _NextLessonSection extends StatelessWidget {
  const _NextLessonSection({
    required this.lesson,
    required this.live,
    required this.onRegisterAttendance,
  });

  final NextLesson lesson;
  final bool live;
  final VoidCallback? onRegisterAttendance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The divider above takes its 1pt out of the top inset, the card's
      // border its 1pt out of the bottom one.
      padding: const EdgeInsets.fromLTRB(
        _paddingH - AppDimens.borderWidth,
        _sectionPaddingV - AppDimens.borderWidth,
        _paddingH - AppDimens.borderWidth,
        _sectionPaddingV - AppDimens.borderWidth,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _lessonHeadingHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    HomeStrings.nextLesson,
                    style: _headingStyle.copyWith(
                      color: context.palette.textPrimary,
                    ),
                  ),
                ),
                if (live) const _LiveBadge(),
              ],
            ),
          ),
          Text(
            HomeStrings.lessonWindow(lesson.startsAt, lesson.endsAt),
            style: _lessonTimeStyle.copyWith(color: context.palette.accent),
          ),
          if (live) ...[
            const SizedBox(height: _hintGap),
            Text(
              HomeStrings.liveHint,
              style: _hintStyle.copyWith(color: context.palette.textPrimary),
            ),
          ],
          const SizedBox(height: _actionGap),
          HomePillButton(
            label: HomeStrings.attendanceAction,
            icon: AppIcons.qrCode,
            height: _actionHeight,
            onPressed: live ? onRegisterAttendance : null,
          ),
        ],
      ),
    );
  }
}

/// The module progress bar: 8 tall, fully rounded, filled in the frames'
/// blue on the card's own outline grey — `CohortCard`'s bar.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_barHeight / 2),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: _barHeight,
        backgroundColor: context.palette.outline,
        valueColor: AlwaysStoppedAnimation<Color>(context.palette.accent),
      ),
    );
  }
}

// The track badge itself is the shared [TrackBadge] (Issue #229): labelled
// from the account's `ui_mode` here.

/// The cohort's status as an outlined capsule, with the same colour reading
/// `CohortCard._StatusPill` uses — kept identical so the same cohort does not
/// change colour between the list and the dashboard.
class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color outline, Color fill, Color ink) = switch (status
        .toLowerCase()) {
      'open' || 'active' => (
        context.palette.successOutline,
        context.palette.successFill,
        context.palette.successInk,
      ),
      'finished' => (
        context.palette.infoInk,
        context.palette.infoFill,
        context.palette.infoInk,
      ),
      _ => (
        context.palette.textSecondary,
        context.palette.textSecondary.withValues(alpha: 0.12),
        context.palette.textSecondary,
      ),
    };

    return HomeCapsule(
      label: _capitalize(status),
      outline: outline,
      fill: fill,
      ink: ink,
      horizontalPadding: 15,
    );
  }
}

/// The "Live" capsule beside the next-lesson heading while the lesson runs.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return HomeCapsule(
      label: HomeStrings.live,
      outline: context.palette.infoInk,
      fill: context.palette.infoFill,
      ink: context.palette.accent,
      horizontalPadding: 11,
    );
  }
}

// --- Type, read off the frames -------------------------------------------

/// "Cohort 01" — 12 on an 18 line, `CohortCard`'s caption.
final TextStyle _captionStyle = AppTypography.cardSupporting.copyWith(
  fontSize: 12,
  height: 18 / 12,
);

/// "AI Engineer" — 18 bold on a 26 line, `CohortCard`'s title.
final TextStyle _titleStyle = AppTypography.cardHeading.copyWith(
  fontSize: 18,
  height: 26 / 18,
  fontWeight: FontWeight.w700,
);

/// "Modules 2 of 5 complete".
final TextStyle _modulesStyle = AppTypography.cardSupporting.copyWith(
  fontSize: 12,
  height: 18 / 12,
);

/// "35% complete".
const TextStyle _percentStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w500,
  leadingDistribution: TextLeadingDistribution.even,
);

/// "Дараагийн хичээл:".
const TextStyle _headingStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w700,
  leadingDistribution: TextLeadingDistribution.even,
);

/// "08/04 • 09:00 – 11:00".
const TextStyle _lessonTimeStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w500,
  leadingDistribution: TextLeadingDistribution.even,
);

/// "Хичээл эхлсэн та ирцээ бүртгүүлээрэй".
const TextStyle _hintStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w500,
  leadingDistribution: TextLeadingDistribution.even,
);

/// `"active"` -> `"Active"`. Values are shown verbatim otherwise — status and
/// UI mode have no confirmed closed set, so this only tidies capitalisation.
String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
