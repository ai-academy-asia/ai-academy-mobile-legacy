import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/home_dashboard.dart';
import '../home_strings.dart';

/// "Хичээлийн ирц" — how much of the cohort the student has attended.
///
/// The one filled card on the dashboard, in a flat [AppColors.blue]: the
/// reference uses it to pick attendance out as the figure the student is
/// meant to notice, against the white cards around it. Flat rather than a
/// gradient — the reference's fill reads as one solid colour, not a blend.
///
/// Its action is [AppButtonVariant.outlined] — white fill, dark label — which
/// is what reads as the inverse button on blue without inventing a third
/// button variant for one card.
class AttendanceCard extends StatelessWidget {
  const AttendanceCard({required this.attendance, super.key, this.onDetails});

  final AttendanceSummary attendance;

  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: AppDimens.statIconTile,
              height: AppDimens.statIconTile,
              decoration: BoxDecoration(
                color: AppColors.onPrimary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppDimens.cardRadius),
              ),
              child: const Icon(
                Icons.event_available_outlined,
                size: 20,
                color: AppColors.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            HomeStrings.attendanceLabel,
            style: AppTypography.statLabel.copyWith(
              color: AppColors.onPrimary.withValues(alpha: 0.85),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            HomeStrings.attendanceValue(
              attendance.attended,
              attendance.total,
              attendance.percent,
            ),
            style: AppTypography.statValue.copyWith(color: AppColors.onPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 14),
          AppButton(
            label: HomeStrings.details,
            variant: AppButtonVariant.outlined,
            onPressed: onDetails,
          ),
        ],
      ),
    );
  }
}
