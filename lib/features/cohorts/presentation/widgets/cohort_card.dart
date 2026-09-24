import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../enrollments/presentation/enrollment_strings.dart';
import '../../domain/cohort.dart';
import '../cohort_list_strings.dart';

/// How strongly the card's background pattern shows through.
const double _patternOpacity = 0.8;

/// The card's shortest height, border included: Figma's "148 Hug" for a card
/// with no progress. A minimum, not a fixed height — a card with progress or
/// an enroll button is already taller than this and keeps its own size.
const double _minHeight = 148;

/// Space above the badge row and below the last line, measured from the card's
/// outer edge. Figma strokes sit inside the frame and take no layout space, so
/// the padding below is this minus [AppDimens.borderWidth] — the border here
/// does — which puts the content exactly where Figma's 329-wide, 24-inset
/// frame does.
const double _verticalPadding = 24;

/// The Adult badge's height and its icon's side, from Figma.
const double _badgeHeight = 32;
const double _badgeIconSize = 19.92;

/// The status pill's height, from Figma.
const double _pillHeight = 24;

/// The badge row to the caption: 24 in Figma.
const double _rowToCaptionGap = 24;

/// Figma's caption (12 on an 18 line) and title (18 bold on a 26 line). Only
/// the size and line height are set here; colour and family come from the
/// shared styles the rest of the app uses.
final TextStyle _captionStyle = AppTypography.cardSupporting.copyWith(
  fontSize: 12,
  height: 18 / 12,
);
final TextStyle _titleStyle = AppTypography.cardHeading.copyWith(
  fontSize: 18,
  height: 26 / 18,
  fontWeight: FontWeight.w700,
);

/// One cohort in the list — matches the Figma "Course Catalog" (cohorts)
/// frame's card: an Adult badge and a status pill on top, the cohort's
/// caption and title, then the enroll action. Same visual language as
/// `CourseCard`: a white surface, [AppColors.border] at [AppDimens.borderWidth],
/// and [AppDimens.cardRadius] — no new card style invented for this list.
///
/// The schedule/classroom/teacher/seats fields `Cohort` carries are no longer
/// shown here — the reference has no place for them. They still exist on the
/// model; nothing about `Cohort`, its repository, or the enrollment flow
/// changed, only what this one card chooses to render.
///
/// The enroll action sits under the summary as the same full-width [AppButton]
/// every other screen's primary action uses. The card only draws the action's
/// state — in flight, failed — which `EnrollmentController` owns and the list
/// screen hands in. Once enrolled the button simply goes; the card draws no
/// "enrolled" row in its place, so an enrolled cohort's card is the compact
/// summary alone.
class CohortCard extends StatelessWidget {
  const CohortCard({
    required this.cohort,
    super.key,
    this.onEnroll,
    this.enrolling = false,
    this.enrolled = false,
    this.enrollError,
    this.progressPct,
    this.onTap,
  });

  final Cohort cohort;

  /// Opens the cohort's course in `CourseModuleListScreen`. Null leaves the
  /// card inert, same as [onEnroll].
  final VoidCallback? onTap;

  /// How far through the course the student is, as `GET /me/cohorts` reports
  /// it. Null draws no progress row at all — a missing figure is not 0%, and
  /// every card without one looks exactly as it did before this existed.
  final double? progressPct;

  /// What the enroll button does. Null leaves the button off, so the card
  /// reads as a plain summary.
  final VoidCallback? onEnroll;

  /// An enroll request for this cohort is in flight.
  final bool enrolling;

  /// The API has created an enrollment for this cohort. Removes the button.
  final bool enrolled;

  /// Why the last enroll attempt failed. Shown in red under the button, the
  /// way the login screen shows a field's error under the field.
  final String? enrollError;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        child: Container(
          constraints: const BoxConstraints(minHeight: _minHeight),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            border: Border.all(
              color: AppColors.border,
              width: AppDimens.borderWidth,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            child: Stack(
              children: [
                // The reference's decorative shapes, from the exact asset rather
                // than redrawn — kept subtle and behind the content via low
                // opacity, painted before anything else in the stack. The asset
                // is already a 12% tint, so this only lifts it to a faint blue
                // wash; Home's program card keeps its own 0.5.
                Positioned.fill(
                  child: Opacity(
                    opacity: _patternOpacity,
                    child: SvgPicture.asset(
                      'assets/icons/cohort_background.svg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.cardPadding - AppDimens.borderWidth,
                    vertical: _verticalPadding - AppDimens.borderWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _AdultBadge(),
                          _StatusPill(cohort.status),
                        ],
                      ),
                      const SizedBox(height: _rowToCaptionGap),

                      if (_preferMongolian(
                            cohort.course.title.mn,
                            cohort.course.title.en,
                          )
                          case final courseTitle?) ...[
                        // A small caption above the bold heading: [cohort.name] is
                        // the specific instance (e.g. "Corporate Leaders 2026-08"),
                        // [courseTitle] the programme it belongs to — matching the
                        // reference's "Cohort 0N" caption over the bold title.
                        Text(
                          cohort.name,
                          style: _captionStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // The caption's and title's line boxes sit flush in Figma.
                        Text(
                          courseTitle,
                          style: _titleStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else
                        // No course title to caption: falls back to the single
                        // heading this card always showed, rather than leaving the
                        // card with no bold line at all.
                        Text(cohort.name, style: _titleStyle, maxLines: 2),

                      if (progressPct case final progressPct?) ...[
                        const SizedBox(height: 12),
                        _Progress(
                          percent: progressPct.round().clamp(0, 100).toInt(),
                        ),
                      ],

                      if (!enrolled && onEnroll != null) ...[
                        const SizedBox(height: 12),
                        AppButton(
                          label: EnrollmentStrings.enroll,
                          loading: enrolling,
                          onPressed: onEnroll,
                        ),
                      ],

                      if (enrollError case final message?) ...[
                        const SizedBox(height: 8),
                        Text(message, style: AppTypography.fieldError),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The percentage and its bar — the same treatment Home's program card gives
/// the same figure: the value right-aligned above a rounded determinate bar.
class _Progress extends StatelessWidget {
  const _Progress({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            CohortListStrings.percentComplete(percent),
            style: AppTypography.catalogSectionValue,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: AppDimens.progressBarHeight,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.blue),
          ),
        ),
      ],
    );
  }
}

/// Mongolian first — every other string in the app is — falling back to
/// English, and to null only when the API sent neither. Matches
/// `course_card.dart`'s helper; not shared, since neither file currently
/// depends on the other.
String? _preferMongolian(String? mn, String? en) {
  if (mn != null && mn.isNotEmpty) return mn;
  if (en != null && en.isNotEmpty) return en;
  return null;
}

/// `"open"` -> `"Open"`. Values are shown verbatim otherwise — `status` has
/// no confirmed closed set, so this only tidies capitalisation, it never
/// maps or translates.
String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

/// The track badge in the card's top-left. `Cohort`/`CohortCourse` carry no
/// level field the way `features/courses`' `Course` does, so this renders the
/// one logo the reference shows on every card rather than branching on data
/// that does not exist on this model.
class _AdultBadge extends StatelessWidget {
  const _AdultBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      // Figma: 88.92 x 32, its icon 19.92 square. The height is fixed and the
      // content centred in it; the width falls out of the padding below and
      // the 16pt label, the right padding set so it lands on 88.92.
      height: _badgeHeight,
      padding: const EdgeInsets.only(left: 4, right: 11.6),
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
            'assets/icons/adult.svg',
            width: _badgeIconSize,
            height: _badgeIconSize,
          ),
          const SizedBox(width: 9),
          Text(
            'Adult',
            style: AppTypography.catalogTrackLabel.copyWith(
              fontSize: 16,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// The cohort's status, as an outlined capsule in the top-right corner —
/// matching the reference's status pill. Only "open" is a confirmed value of
/// [Cohort.status]; "active" and "finished" are the reference's other two
/// pills, given the same deliberate-colour treatment ([AppColors.blue] for an
/// in-progress cohort, [AppColors.textSecondary] for a past one) on the same
/// unconfirmed-value basis "open" already was. Any other value falls back to
/// that same neutral outline rather than a guessed colour.
class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'open' => AppColors.success,
      'active' => AppColors.blue,
      'finished' => AppColors.textSecondary,
      _ => AppColors.textSecondary,
    };

    return Container(
      // Figma: 24 high, its text 12 on a 16 line. The width is the label's
      // plus 15 each side and the 1pt border — 83 for "Finished".
      height: _pillHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: AppDimens.borderWidth),
      ),
      child: Text(
        _capitalize(status),
        style: AppTypography.catalogStatusLabel.copyWith(
          color: color,
          fontSize: 12,
          height: 16 / 12,
        ),
      ),
    );
  }
}
