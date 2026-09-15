import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course.dart';
import '../course_catalog_strings.dart';

/// One course in the catalog.
///
/// Same visual language as `ContactManagerCard`: a white surface, the
/// established [AppColors.border] at [AppDimens.borderWidth], and
/// [AppDimens.cardRadius] — the "rounded card with a thin border" the rest of
/// the app already uses, rather than a new card style invented for this list.
///
/// Shows only fields the confirmed `GET /courses` response carries. Two fields
/// on [Course] are deliberately not rendered here:
///
///  * `icon` — the contract confirms the value but not what it *is* (a URL? an
///    icon-font key?), so nothing safe can be drawn from it yet.
///  * `sortOrder` — a hint for how the *list* should be ordered, not something
///    that belongs on one card; this screen renders courses in the order the
///    repository returns them.
class CourseCard extends StatelessWidget {
  const CourseCard({required this.course, super.key, this.onTap});

  final Course course;

  /// What tapping the card does — the catalog opens the cohort list. Null
  /// leaves the card inert.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            border: Border.all(color: AppColors.border, width: AppDimens.borderWidth),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (course.bannerImageUrl != null) ...[
                _Banner(url: course.bannerImageUrl!),
                const SizedBox(height: 12),
              ],

              _Badges(course: course),
              const SizedBox(height: 8),

              Text(
                _preferMongolian(course.title.mn, course.title.en) ?? course.slug,
                style: AppTypography.cardHeading,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (_preferMongolian(course.tagline.mn, course.tagline.en)
                  case final tagline?) ...[
                const SizedBox(height: AppDimens.cardLineGap),
                Text(
                  tagline,
                  style: AppTypography.cardSupporting,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              if (course.targetAudience case final audience?) ...[
                const SizedBox(height: AppDimens.cardLineGap),
                Text(
                  audience,
                  style: AppTypography.cardSupporting,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),
              _MetaRow(course: course),

              const SizedBox(height: 8),
              _PriceRow(course: course),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mongolian first — every other string in the app is — falling back to
/// English, and to null (the caller's problem, not this widget's) only when
/// the API sent neither.
String? _preferMongolian(String? mn, String? en) {
  if (mn != null && mn.isNotEmpty) return mn;
  if (en != null && en.isNotEmpty) return en;
  return null;
}

class _Banner extends StatelessWidget {
  const _Banner({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : const ColoredBox(color: AppColors.surfaceMuted),
          errorBuilder: (context, error, stackTrace) =>
              const ColoredBox(color: AppColors.surfaceMuted),
        ),
      ),
    );
  }
}

/// Category, level, format and status — the four short classifying strings
/// the contract gives, shown verbatim. None has a confirmed closed set of
/// values, so none is translated or mapped to a different label.
class _Badges extends StatelessWidget {
  const _Badges({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final label in [course.category, course.level, course.format, course.status])
          _Badge(label),
      ],
    );
  }
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

/// Duration, age range and dates — the confirmed scheduling fields, wrapped
/// onto as many lines as they need rather than fixed to one.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final duration =
        course.durationLabel ??
        '${course.durationWeeks} ${CourseCatalogStrings.weeksUnit}';
    final age = '${course.ageMin}-${course.ageMax} ${CourseCatalogStrings.ageUnit}';
    final dates = CourseCatalogStrings.dateRange(course.startDate, course.endDate);

    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        Text(duration, style: AppTypography.cardSupporting),
        Text(age, style: AppTypography.cardSupporting),
        Text(dates, style: AppTypography.cardSupporting),
      ],
    );
  }
}

/// The final price, with the pre-discount price struck through beside it when
/// a discount applies. All three numbers come straight off the confirmed
/// `price_amount` / `final_price_amount` / `discount_percent` fields — nothing
/// here is computed independently of what the API sent.
class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final hasDiscount =
        course.discountPercent > 0 && course.finalPriceAmount < course.priceAmount;

    return Row(
      children: [
        Text(
          '${_formatAmount(course.finalPriceAmount)} ${course.currency}',
          style: AppTypography.cardHeading.copyWith(color: AppColors.blue),
        ),
        if (hasDiscount) ...[
          const SizedBox(width: 8),
          Text(
            '${_formatAmount(course.priceAmount)} ${course.currency}',
            style: AppTypography.cardSupporting.copyWith(
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 6),
          _Badge('-${course.discountPercent}%'),
        ],
      ],
    );
  }
}

/// `1200000.0` -> `"1,200,000"`. A thousands separator on the integer part;
/// the API sends whole amounts (currency minor units are not confirmed to be
/// in play here), so any fractional part is dropped rather than displayed as
/// meaningless trailing zeros.
String _formatAmount(double amount) {
  final whole = amount.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return buffer.toString();
}
