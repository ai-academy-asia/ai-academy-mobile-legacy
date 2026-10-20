import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_palette.dart';
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
    // A course with no price draws none (Issue #485) — no "0" or
    // placeholder; whether it should say so is a PRODUCT DECISION.
    final finalPrice = course.finalPriceAmount;
    if (finalPrice == null) return const SizedBox.shrink();
    final discount = courseDiscount(course);

    return Row(
      children: [
        Text(
          courseAmountLabel(finalPrice, course.currency),
          style: AppTypography.cardHeading.copyWith(
            color: context.palette.primary,
          ),
        ),
        if (discount case (final price, final percent)) ...[
          const SizedBox(width: 8),
          Text(
            courseAmountLabel(price, course.currency),
            style: AppTypography.cardSupporting
                .copyWith(color: context.palette.textSecondary)
                .copyWith(decoration: TextDecoration.lineThrough),
          ),
          const SizedBox(width: 6),
          CourseBadge('-$percent%'),
        ],
      ],
    );
  }
}

/// The struck-through pre-discount price and the percentage, when a discount
/// applies: both prices and `discount_percent` sent, a positive percentage,
/// and a final price below the list price. Null otherwise — including when
/// any of the three is `null` (Issue #485).
(double, int)? courseDiscount(Course course) {
  final price = course.priceAmount;
  final finalPrice = course.finalPriceAmount;
  final percent = course.discountPercent;
  if (price == null || finalPrice == null || percent == null) return null;
  if (percent <= 0 || finalPrice >= price) return null;
  return (price, percent);
}

/// `"960,000 MNT"`, or the amount alone when the course sends no currency
/// (Issue #485) — none is assumed.
String courseAmountLabel(double amount, String? currency) {
  final code = currency?.trim() ?? '';
  final formatted = formatCourseAmount(amount);
  return code.isEmpty ? formatted : '$formatted $code';
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
