import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../enrollments/presentation/enrollment_strings.dart';
import '../../domain/cohort.dart';

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
/// state — in flight, enrolled, failed — which `EnrollmentController` owns and
/// the list screen hands in.
class CohortCard extends StatelessWidget {
  const CohortCard({
    required this.cohort,
    super.key,
    this.onEnroll,
    this.enrolling = false,
    this.enrolled = false,
    this.enrollError,
  });

  final Cohort cohort;

  /// What the enroll button does. Null leaves the button off, so the card
  /// reads as a plain summary.
  final VoidCallback? onEnroll;

  /// An enroll request for this cohort is in flight.
  final bool enrolling;

  /// The API has created an enrollment for this cohort. Replaces the button.
  final bool enrolled;

  /// Why the last enroll attempt failed. Shown in red under the button, the
  /// way the login screen shows a field's error under the field.
  final String? enrollError;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: AppColors.border, width: AppDimens.borderWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        child: Stack(
          children: [
            // The reference's decorative shapes, from the exact asset rather
            // than redrawn — kept subtle and behind the content via low
            // opacity, painted before anything else in the stack.
            Positioned.fill(
              child: Opacity(
                opacity: 0.5,
                child: SvgPicture.asset(
                  'assets/icons/cohort_background.svg',
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
                    children: [const _AdultBadge(), _StatusPill(cohort.status)],
                  ),
                  const SizedBox(height: 12),

                  if (_preferMongolian(cohort.course.title.mn, cohort.course.title.en)
                      case final courseTitle?) ...[
                    // A small caption above the bold heading: [cohort.name] is
                    // the specific instance (e.g. "Corporate Leaders 2026-08"),
                    // [courseTitle] the programme it belongs to — matching the
                    // reference's "Cohort 0N" caption over the bold title.
                    Text(
                      cohort.name,
                      style: AppTypography.cardSupporting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimens.cardLineGap),
                    Text(
                      courseTitle,
                      style: AppTypography.cardHeading,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else
                    // No course title to caption: falls back to the single
                    // heading this card always showed, rather than leaving the
                    // card with no bold line at all.
                    Text(cohort.name, style: AppTypography.cardHeading, maxLines: 2),

                  if (enrolled) ...[
                    const SizedBox(height: 12),
                    const _EnrolledLabel(),
                  ] else if (onEnroll != null) ...[
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: AppDimens.borderWidth),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/icons/adult.svg', height: 14),
          const SizedBox(width: 4),
          const Text('Adult', style: AppTypography.catalogTrackLabel),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: AppDimens.borderWidthEmphasis),
      ),
      child: Text(
        _capitalize(status),
        style: AppTypography.catalogStatusLabel.copyWith(color: color),
      ),
    );
  }
}

/// Where the button was, once enrolled: the success green and circled tick a
/// satisfied password requirement uses, held at the button's height so the
/// card does not jump when one replaces the other.
class _EnrolledLabel extends StatelessWidget {
  const _EnrolledLabel();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimens.buttonHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            AppIcons.checkCircle,
            size: AppDimens.requirementIconSize,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Text(
            EnrollmentStrings.enrolled,
            style: AppTypography.buttonLabel.copyWith(color: AppColors.success),
          ),
        ],
      ),
    );
  }
}
