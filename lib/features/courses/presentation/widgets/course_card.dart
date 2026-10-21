import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_palette.dart';
import '../../domain/course.dart';
import '../course_catalog_strings.dart';
import 'course_price_row.dart';
import '../../../../core/models/localized_text.dart';

/// One course in the catalog — matches the Figma "Course Catalog" frame's
/// card structure: a track badge and status pill, title and description, a
/// "Who is it for" / "Duration" block, then the price row.
///
/// Same visual language as `ContactManagerCard`: a white surface, the
/// established [AppColors.border] at [AppDimens.borderWidth], and
/// [AppDimens.cardRadius] — the "rounded card with a thin border" the rest of
/// the app already uses, rather than a new card style invented for this list.
///
/// A course whose `status` isn't "open" (e.g. "full") renders its title,
/// section values and price in [AppColors.textSecondary] instead of
/// [AppColors.textPrimary], matching the muted treatment the reference gives
/// a full course — the badge and pill stay legible either way.
///
/// Two fields on [Course] are deliberately not rendered here:
///
///  * `icon` — the contract confirms the value but not what it *is* (a URL? an
///    icon-font key?), so nothing safe can be drawn from it yet.
///  * `sortOrder` — a hint for how the *list* should be ordered, not something
///    that belongs on one card; this screen renders courses in the order the
///    repository returns them.
///
/// `category` and `format` are no longer shown as badges: the reference has
/// no place for them, and neither has a confirmed closed set of values to
/// render meaningfully on its own.
class CourseCard extends StatelessWidget {
  const CourseCard({required this.course, super.key, this.onTap});

  final Course course;

  /// What tapping the card does — the catalog opens the cohort list. Null
  /// leaves the card inert.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isOpen = course.status.toLowerCase() == 'open';
    final contentColor = isOpen
        ? context.palette.textPrimary
        : context.palette.textSecondary;
    final level = course.level;
    // Absent parts are left out (Issue #485): a section with nothing to say
    // is not drawn, and with neither the block and its divider go too.
    final audience = _audience(course);
    final duration = _durationValue(course);

    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            border: Border.all(
              color: context.palette.border,
              width: AppDimens.borderWidth,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (course.bannerImageUrl != null) ...[
                _Banner(url: course.bannerImageUrl!),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  if (level != null && level.trim().isNotEmpty)
                    _TrackBadge(level: level),
                  const Spacer(),
                  _StatusPill(status: course.status),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                preferredText(course.title.mn, course.title.en) ?? course.slug,
                style: AppTypography.catalogTitle.copyWith(color: contentColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (preferredText(course.tagline.mn, course.tagline.en)
                  case final tagline?) ...[
                const SizedBox(height: AppDimens.cardLineGap),
                Text(
                  tagline,
                  style: AppTypography.cardSupporting.copyWith(
                    color: context.palette.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              if (audience != null || duration != null) ...[
                const SizedBox(height: 12),
                _Divider(),
                const SizedBox(height: 12),
                if (audience != null)
                  _Section(
                    label: CourseCatalogStrings.whoIsItFor,
                    value: audience,
                    valueColor: contentColor,
                  ),
                if (audience != null && duration != null)
                  const SizedBox(height: 10),
                if (duration != null)
                  _Section(
                    label: CourseCatalogStrings.durationSectionLabel,
                    value: duration,
                    valueColor: contentColor,
                  ),
              ],

              const SizedBox(height: 12),
              _Divider(),
              const SizedBox(height: 12),

              _PriceRow(course: course, priceColor: contentColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// `"junior"` -> `"Junior"`. Values are shown verbatim otherwise — neither
/// `level` nor `status` has a confirmed closed set, so this only tidies
/// capitalisation, it never maps or translates.
String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

/// The card's "Who is it for" value. Real API copy (`target_audience`) wins
/// when the course sends one; otherwise this composes the same shape from
/// the confirmed `level`/`age_min`/`age_max` fields rather than showing
/// nothing — from whichever of the two parts the course sends, or null when
/// it sends neither (Issue #485).
String? _audience(Course course) {
  if (course.targetAudience case final audience?) return audience;
  final level = course.level?.trim() ?? '';
  final parts = [
    if (level.isNotEmpty) _capitalize(level),
    ?CourseCatalogStrings.ageRangeOf(course.ageMin, course.ageMax),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// The card's "Duration" value: the date range with the length in
/// parentheses, e.g. "2026-06-01 – 2026-06-21 (3 долоо хоног)" — or either
/// part alone, or null when the course sends neither (Issue #485).
String? _durationValue(Course course) {
  final duration = CourseCatalogStrings.durationOf(
    course.durationLabel,
    course.durationWeeks,
  );
  final dates = CourseCatalogStrings.dateRangeOf(
    course.startDate,
    course.endDate,
  );
  return switch ((dates, duration)) {
    (final dates?, final duration?) => '$dates ($duration)',
    (final dates?, null) => dates,
    (null, final duration?) => duration,
    (null, null) => null,
  };
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
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : ColoredBox(color: context.palette.surfaceMuted),
          errorBuilder: (context, error, stackTrace) =>
              ColoredBox(color: context.palette.surfaceMuted),
        ),
      ),
    );
  }
}

/// The outlined pill in the card's top-left: the track's logo
/// (`assets/icons/adult.svg` / `assets/icons/junior.svg`) beside its label.
/// Any `level` other than "adult"/"junior" renders the label alone — there is
/// no third logo asset to guess at.
class _TrackBadge extends StatelessWidget {
  const _TrackBadge({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final asset = switch (level.toLowerCase()) {
      'adult' => 'assets/icons/adult.svg',
      'junior' => 'assets/icons/junior.svg',
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(
          color: context.palette.border,
          width: AppDimens.borderWidth,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (asset != null) ...[
            SvgPicture.asset(asset, height: 14),
            const SizedBox(width: 4),
          ],
          Text(
            _capitalize(level),
            style: AppTypography.catalogTrackLabel.copyWith(
              color: context.palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The filled pill in the card's top-right. Blue for "open", the same dark
/// fill as [AppColors.textPrimary] for anything else — "full" in the
/// reference, but `status` has no confirmed closed set, so every non-open
/// value gets that same treatment rather than one hardcoded for "full" only.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isOpen = status.toLowerCase() == 'open';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOpen ? context.palette.primary : context.palette.textPrimary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _capitalize(status),
        style: AppTypography.catalogStatusLabel.copyWith(
          color: context.palette.onPrimary,
        ),
      ),
    );
  }
}

/// A caption over its value, e.g. "Who is it for" over "Junior · 10-18 нас".
class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.catalogSectionLabel.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.catalogSectionValue.copyWith(color: valueColor),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimens.borderWidth,
      color: context.palette.border,
    );
  }
}

/// The final price, with the pre-discount price struck through and a
/// discount badge beside it when a discount applies, and the card's trailing
/// chevron. All three price numbers come straight off the confirmed
/// `price_amount` / `final_price_amount` / `discount_percent` fields —
/// nothing here is computed independently of what the API sent.
class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.course, required this.priceColor});

  final Course course;
  final Color priceColor;

  @override
  Widget build(BuildContext context) {
    // No price, no amount (Issue #485) — the chevron still says the card
    // opens; whether to say "no price yet" is a PRODUCT DECISION.
    final finalPrice = course.finalPriceAmount;
    final discount = courseDiscount(course);

    return Row(
      children: [
        if (finalPrice != null)
          Text(
            courseAmountLabel(finalPrice, course.currency),
            style: AppTypography.catalogPrice.copyWith(color: priceColor),
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
          _DiscountBadge(percent: percent),
        ],
        const Spacer(),
        Icon(
          AppIcons.caretRight,
          size: AppDimens.caretSize,
          color: context.palette.textSecondary,
        ),
      ],
    );
  }
}

class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(
          color: context.palette.error,
          width: AppDimens.borderWidth,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '-$percent%',
        style: AppTypography.badgeLabel.copyWith(color: context.palette.error),
      ),
    );
  }
}
