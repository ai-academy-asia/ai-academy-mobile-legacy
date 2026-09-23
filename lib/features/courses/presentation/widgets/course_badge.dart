import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course.dart';

/// One small pill of text — a course's category, level, format, status, or a
/// discount percentage. Used directly for the latter (`CoursePriceRow`); see
/// [CourseBadges] for the classifying four together.
class CourseBadge extends StatelessWidget {
  const CourseBadge(this.label, {super.key});

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

/// Category, level, format and status — the four short classifying strings
/// the contract gives, shown verbatim. None has a confirmed closed set of
/// values, so none is translated or mapped to a different label.
class CourseBadges extends StatelessWidget {
  const CourseBadges({required this.course, super.key});

  final Course course;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final label in [course.category, course.level, course.format, course.status])
          CourseBadge(label),
      ],
    );
  }
}
