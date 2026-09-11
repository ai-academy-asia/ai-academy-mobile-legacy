import '../../../core/models/localized_text.dart';

/// A course as the public catalog lists it.
///
/// Read from `GET /courses` (confirmed, unauthenticated). Fields and their
/// nullability are exactly what the one confirmed response demonstrates: a
/// field is modelled as nullable only where that response showed it as `null`
/// (`banner_image_url`, `duration_label`, `icon`, `sort_order`,
/// `target_audience`, and the individual `en`/`mn` keys inside [title] and
/// [tagline]). Everything else is modelled as required.
///
/// **That is a real limitation, not a guarantee.** A field that happened to
/// carry a value in the one example (`age_min`, `discount_percent`, …) could
/// still be nullable on a course the example didn't cover — a summer bootcamp
/// with no age floor, say. `HttpCourseRepository` fails loudly if a required
/// field is missing on a real response, precisely so that gap surfaces as a
/// clear parse error instead of a silent wrong value; treat such a failure as
/// a sign this model needs to loosen, not as a bug in the course.
///
/// [category], [level], [format] and [status] stay `String` rather than enums:
/// the confirmed response shows one value for each ("bootcamp", "junior",
/// "in_person", "open"), which is not enough to say what the closed set of
/// values is, if the set is even closed.
///
/// [startDate] and [endDate] stay the raw wire strings rather than `DateTime`:
/// nothing in the confirmed contract states the date format is guaranteed
/// stable, and parsing them is a decision for the feature that first needs
/// dates as dates, not for this layer.
class Course {
  const Course({
    required this.id,
    required this.slug,
    required this.title,
    required this.tagline,
    required this.category,
    required this.level,
    required this.format,
    required this.status,
    required this.ageMin,
    required this.ageMax,
    required this.durationWeeks,
    required this.startDate,
    required this.endDate,
    required this.priceAmount,
    required this.finalPriceAmount,
    required this.discountPercent,
    required this.currency,
    this.durationLabel,
    this.bannerImageUrl,
    this.icon,
    this.sortOrder,
    this.targetAudience,
  });

  final int id;
  final String slug;
  final LocalizedText title;
  final LocalizedText tagline;

  /// e.g. "bootcamp".
  final String category;

  /// e.g. "junior".
  final String level;

  /// e.g. "in_person".
  final String format;

  /// e.g. "open".
  final String status;

  final int ageMin;
  final int ageMax;
  final int durationWeeks;

  /// Raw ISO-looking date string from the wire, e.g. "2026-06-01".
  final String startDate;

  /// Raw ISO-looking date string from the wire, e.g. "2026-06-21".
  final String endDate;

  final double priceAmount;
  final double finalPriceAmount;
  final int discountPercent;

  /// e.g. "MNT".
  final String currency;

  final String? durationLabel;
  final String? bannerImageUrl;
  final String? icon;
  final int? sortOrder;
  final String? targetAudience;
}
