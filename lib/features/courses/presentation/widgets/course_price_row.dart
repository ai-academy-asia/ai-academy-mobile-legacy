import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course.dart';
import 'course_badge.dart';

/// The final price, with the pre-discount price struck through beside it when
/// a discount applies. All three numbers come straight off the confirmed
/// `price_amount` / `final_price_amount` / `discount_percent` fields — nothing
/// here is computed independently of what the API sent. Shared by the catalog
/// card and the detail screen.
class CoursePriceRow extends StatelessWidget {
  const CoursePriceRow({required this.course, super.key});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final hasDiscount =
        course.discountPercent > 0 && course.finalPriceAmount < course.priceAmount;

    return Row(
      children: [
        Text(
          '${formatCourseAmount(course.finalPriceAmount)} ${course.currency}',
          style: AppTypography.cardHeading.copyWith(color: AppColors.blue),
        ),
        if (hasDiscount) ...[
          const SizedBox(width: 8),
          Text(
            '${formatCourseAmount(course.priceAmount)} ${course.currency}',
            style: AppTypography.cardSupporting.copyWith(
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 6),
          CourseBadge('-${course.discountPercent}%'),
        ],
      ],
    );
  }
}

/// `1200000.0` -> `"1,200,000"`. A thousands separator on the integer part;
/// the API sends whole amounts (currency minor units are not confirmed to be
/// in play here), so any fractional part is dropped rather than displayed as
/// meaningless trailing zeros.
String formatCourseAmount(double amount) {
  final whole = amount.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return buffer.toString();
}
