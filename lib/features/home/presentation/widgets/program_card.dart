import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/home_dashboard.dart';
import '../home_strings.dart';

/// The cohort the student is studying in — the dashboard's headline card.
///
/// Two stacked sections inside one rounded surface, split by a full-bleed
/// rule, exactly as the reference draws it: the summary (track badge, status,
/// cohort caption, course name, module progress) over the next lesson and its
/// attendance action. The decorative shapes behind the summary are the same
/// exported asset `CohortCard` uses, at the same low opacity — not redrawn.
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
  });

  final EnrolledProgram program;

  /// The next lesson is under way. Puts the "Live" badge beside the heading,
  /// adds the prompt line, and turns the attendance action on.
  final bool live;

  /// What the attendance action does. The button only accepts a press while
  /// [live] — there is nothing to register otherwise.
  final VoidCallback? onRegisterAttendance;

  @override
  Widget build(BuildContext context) {
    final progress = program.progress;
    final nextLesson = program.nextLesson;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        border: Border.all(
          color: AppColors.border,
          width: AppDimens.borderWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.5,
                    child: SvgPicture.asset(
                      HomeIcons.cardBackground,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppDimens.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (program.level case final level?)
                            _TrackBadge(level)
                          else
                            const SizedBox.shrink(),
                          _StatusPill(program.status),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Text(
                        program.cohortName,
                        style: AppTypography.statLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimens.cardLineGap),
                      Text(
                        program.courseTitle,
                        style: AppTypography.programTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (progress case final progress?) ...[
                        const SizedBox(height: 12),
                        if (progress.completed != null &&
                            progress.total != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  HomeStrings.modules(
                                    progress.completed!,
                                    progress.total!,
                                  ),
                                  style: AppTypography.statLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                HomeStrings.percentComplete(progress.percent),
                                style: AppTypography.catalogSectionValue,
                              ),
                            ],
                          )
                        else
                          // No module count to caption the bar with — only
                          // `Enrollment.progressPct`, a bare percentage. Right
                          // aligned to sit where the percent sits when the
                          // count line is also drawn, rather than left-aligned
                          // and out of place.
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              HomeStrings.percentComplete(progress.percent),
                              style: AppTypography.catalogSectionValue,
                            ),
                          ),
                        const SizedBox(height: 8),
                        _ProgressBar(fraction: progress.fraction),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (nextLesson != null) ...[
              Container(height: AppDimens.borderWidth, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.all(AppDimens.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            HomeStrings.nextLesson,
                            style: AppTypography.cardHeading,
                          ),
                        ),
                        if (live) const _LiveBadge(),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      HomeStrings.lessonWindow(
                        nextLesson.startsAt,
                        nextLesson.endsAt,
                      ),
                      style: AppTypography.cardHeading.copyWith(
                        color: AppColors.blue,
                      ),
                    ),
                    if (live) ...[
                      const SizedBox(height: 6),
                      Text(
                        HomeStrings.liveHint,
                        style: AppTypography.settingsRowLabel,
                      ),
                    ],
                    const SizedBox(height: 14),
                    _AttendanceAction(
                      onPressed: live ? onRegisterAttendance : null,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The module progress bar. A determinate [LinearProgressIndicator] rounded
/// off at both ends, rather than a hand-rolled two-box stack.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: AppDimens.progressBarHeight,
        backgroundColor: AppColors.border,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.blue),
      ),
    );
  }
}

/// The course's track, as the outlined badge in the card's top-left. Same
/// shape `CohortCard` draws, but from the catalog's `level` rather than
/// assuming one — the cohort model carries no level of its own.
class _TrackBadge extends StatelessWidget {
  const _TrackBadge(this.level);

  final String level;

  @override
  Widget build(BuildContext context) {
    final isJunior = level.toLowerCase() == 'junior';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: AppColors.border,
          width: AppDimens.borderWidth,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            isJunior ? HomeIcons.junior : HomeIcons.adult,
            height: 14,
          ),
          const SizedBox(width: 4),
          Text(_capitalize(level), style: AppTypography.catalogTrackLabel),
        ],
      ),
    );
  }
}

/// The cohort's status as an outlined capsule, with the same colour reading
/// `CohortCard._StatusPill` uses — kept identical so the same cohort does not
/// change colour between the list and the dashboard.
class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'open' => AppColors.success,
      'active' => AppColors.success,
      'finished' => AppColors.textSecondary,
      _ => AppColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        // A soft tint behind the outline, not a bare border: the reference
        // draws every pill on Home with a faint fill in its own colour.
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: AppDimens.borderWidth),
      ),
      child: Text(
        _capitalize(status),
        style: AppTypography.catalogStatusLabel.copyWith(color: color),
      ),
    );
  }
}

/// The "Live" capsule beside the next-lesson heading while the lesson runs.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.blue, width: AppDimens.borderWidth),
      ),
      child: Text(
        HomeStrings.live,
        style: AppTypography.catalogStatusLabel.copyWith(color: AppColors.blue),
      ),
    );
  }
}

/// The attendance action.
///
/// Not [AppButton]: that widget draws a label alone, and the reference puts a
/// QR glyph in front of this one. Everything else about it is `AppButton`'s —
/// the same [AppDimens.buttonHeight], the same pill radius, the same blue
/// when live and flat treatment when it cannot be pressed — so the two read
/// as one control, not two button styles.
class _AttendanceAction extends StatelessWidget {
  const _AttendanceAction({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = enabled ? AppColors.onPrimary : AppColors.disabled;

    return Semantics(
      button: true,
      enabled: enabled,
      label: HomeStrings.attendanceAction,
      child: Material(
        color: enabled ? AppColors.blue : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimens.buttonRadius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppDimens.buttonRadius),
          splashColor: enabled ? Colors.white24 : null,
          highlightColor: enabled ? Colors.white10 : null,
          child: Ink(
            height: AppDimens.buttonHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.buttonRadius),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner, size: 18, color: foreground),
                const SizedBox(width: 8),
                Text(
                  HomeStrings.attendanceAction,
                  style: AppTypography.buttonLabel.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `"active"` -> `"Active"`. Values are shown verbatim otherwise — status and
/// level have no confirmed closed set, so this only tidies capitalisation.
String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
