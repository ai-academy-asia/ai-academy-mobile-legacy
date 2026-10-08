import 'package:flutter/material.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_palette.dart';
import '../../domain/home_dashboard.dart';
import '../home_strings.dart';
import 'home_pill_button.dart';
import 'home_stat_card.dart';

/// "Хичээлийн ирц" — how much of the cohort the student has attended.
///
/// As a **tile** it is the one filled card on the dashboard: a left-to-right
/// blue gradient with white figures, which the reference uses to pick
/// attendance out as the figure the student is meant to notice. As a **row**
/// it is a white summary like the payment row beside it.
///
/// Either way its action is the white "Дэлгэрэнгүй" pill.
class AttendanceCard extends StatelessWidget {
  const AttendanceCard({
    required this.attendance,
    super.key,
    this.layout = HomeStatLayout.tile,
    this.onDetails,
  });

  final AttendanceSummary attendance;
  final HomeStatLayout layout;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final filled = layout == HomeStatLayout.tile;

    return HomeStatCard(
      layout: layout,
      icon: AppIcons.calendarCheck,
      label: HomeStrings.attendanceLabel,
      value: HomeStrings.attendanceValue(
        attendance.attended,
        attendance.total,
        attendance.percent,
      ),
      gradient: filled
          ? LinearGradient(
              colors: [
                context.palette.attendanceGradientStart,
                context.palette.attendanceGradientEnd,
              ],
            )
          : null,
      iconColor: filled ? context.palette.onPrimary : context.palette.accent,
      labelColor: filled
          ? context.palette.onPrimary
          : context.palette.textStatLabel,
      valueColor: filled ? context.palette.onPrimary : context.palette.accent,
      action: HomePillButton(
        label: HomeStrings.details,
        variant: HomePillVariant.secondary,
        height: statActionHeight,
        onPressed: onDetails,
      ),
    );
  }
}
