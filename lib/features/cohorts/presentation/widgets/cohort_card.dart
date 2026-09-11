import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/cohort.dart';
import '../cohort_list_strings.dart';

/// One cohort in the list. Same visual language as `CourseCard`: a white
/// surface, [AppColors.border] at [AppDimens.borderWidth], and
/// [AppDimens.cardRadius] — no new card style invented for this list.
class CohortCard extends StatelessWidget {
  const CohortCard({required this.cohort, super.key});

  final Cohort cohort;

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
