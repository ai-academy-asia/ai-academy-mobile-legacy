import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../enrollments/presentation/enrollment_strings.dart';
import '../../domain/cohort.dart';
import '../cohort_list_strings.dart';

/// One cohort in the list. Same visual language as `CourseCard`: a white
/// surface, [AppColors.border] at [AppDimens.borderWidth], and
/// [AppDimens.cardRadius] — no new card style invented for this list.
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
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: AppColors.border, width: AppDimens.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Badge(cohort.status),
          const SizedBox(height: 8),

          Text(cohort.name, style: AppTypography.cardHeading, maxLines: 2),

          if (_preferMongolian(cohort.course.title.mn, cohort.course.title.en)
              case final courseTitle?) ...[
            const SizedBox(height: AppDimens.cardLineGap),
            Text(
              courseTitle,
              style: AppTypography.cardSupporting,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 12),
          _ScheduleRow(cohort: cohort),

          const SizedBox(height: 8),
          Text(
            '${cohort.classroom.centerName} · ${cohort.classroom.name}',
            style: AppTypography.cardSupporting,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            cohort.teacher.name,
            style: AppTypography.cardSupporting,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 8),
          Text(
            '${cohort.seatsAvailable} ${CohortListStrings.seatsAvailableUnit}',
            style: AppTypography.cardHeading.copyWith(color: AppColors.blue),
          ),

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

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: AppTypography.badgeLabel),
    );
  }
}

/// Days, dates and times — the confirmed scheduling fields, wrapped onto as
/// many lines as they need.
class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.cohort});

  final Cohort cohort;

  @override
  Widget build(BuildContext context) {
    final days = cohort.meetingDays.join(', ');
    final dates = CohortListStrings.dateRange(cohort.startDate, cohort.endDate);
    final times = CohortListStrings.timeRange(cohort.startTime, cohort.endTime);

    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        Text(days, style: AppTypography.cardSupporting),
        Text(dates, style: AppTypography.cardSupporting),
        Text(times, style: AppTypography.cardSupporting),
      ],
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
