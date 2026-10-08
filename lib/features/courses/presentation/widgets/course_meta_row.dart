import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_palette.dart';
import '../../domain/course.dart';
import '../course_catalog_strings.dart';

/// Duration, age range and dates — the confirmed scheduling fields, wrapped
/// onto as many lines as they need rather than fixed to one. Shared by the
/// catalog card and the detail screen: the same three facts, the same wording
/// — a course does not get a second set of unit labels for its own page.
class CourseMetaRow extends StatelessWidget {
  const CourseMetaRow({required this.course, super.key});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final duration =
        course.durationLabel ??
        '${course.durationWeeks} ${CourseCatalogStrings.weeksUnit}';
    final age = CourseCatalogStrings.ageRange(course.ageMin, course.ageMax);
    final dates = CourseCatalogStrings.dateRange(course.startDate, course.endDate);

    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        Text(
          duration,
          style: AppTypography.cardSupporting.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        Text(
          age,
          style: AppTypography.cardSupporting.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        Text(
          dates,
          style: AppTypography.cardSupporting.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      ],
    );
  }
}
