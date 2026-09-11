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
///
/// --- Detail fields ---------------------------------------------------------
///
/// `GET /courses/{slug}` (confirmed, unauthenticated) adds eighteen more
/// fields the catalog's list response never sends. A captured Postman
/// response confirms the field set and that the response is the course object
/// itself, with no envelope — the same shape `HttpCourseRepository` already
/// parses it as. That response did not settle every field's type, so two
/// different confidence levels still follow:
///
///  * [attendanceMethod], [capacity], [certTemplateName],
///    [contractTemplateName], [createdAt], [finalProjectType],
///    [googleClassroomUrl], [hasAttendance], [hasCertTemplate],
///    [hasContractTemplate], [hasExam], [hasFinalProject] and [updatedAt] have
///    a confirmed *name* and an assumed *type*, inferred from the field's own
///    name (a `has_x` field is presumed boolean; `capacity` a count; the
///    `_at` fields a timestamp string). All are modelled nullable and parsed
///    permissively — see `HttpCourseRepository`'s "soft" readers — because
///    nothing confirms whether the field is ever absent.
///  * [curriculum], [description], [instructors], [prerequisites] and
///    [whatsIncluded] have a confirmed *name* only — nothing constrains their
///    shape at all (a list of strings? Objects? One block of text?). These
///    stay `Object?`, the raw decoded JSON, rather than a typed shape this
///    codebase would otherwise be asserting on no evidence. `describe_json.dart`
///    renders whichever shape actually arrives.
///
/// A course fetched from the list endpoint carries `null` for every field in
/// this section — the list response never sends them, so there is nothing to
/// fill them with. Only a course returned by `getCourseDetail` has them set.
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
    this.attendanceMethod,
    this.capacity,
    this.certTemplateName,
    this.contractTemplateName,
    this.createdAt,
    this.curriculum,
    this.description,
    this.finalProjectType,
    this.googleClassroomUrl,
    this.hasAttendance,
    this.hasCertTemplate,
    this.hasContractTemplate,
    this.hasExam,
    this.hasFinalProject,
    this.instructors,
    this.prerequisites,
    this.updatedAt,
    this.whatsIncluded,
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

  // --- Detail-only fields, see the class doc above ------------------------

  /// e.g. "in_person" — a guess at the type; unconfirmed.
  final String? attendanceMethod;

  /// Seat count, assumed from the field name; unconfirmed.
  final int? capacity;

  final String? certTemplateName;
  final String? contractTemplateName;

  /// Raw wire string, not parsed — see [startDate]'s reasoning.
  final String? createdAt;

  /// Raw decoded JSON — shape not confirmed. Render with
  /// `describeJsonLines` from `core/utils/describe_json.dart`.
  final Object? curriculum;

  /// Raw decoded JSON — shape not confirmed, and possibly bilingual like
  /// [title]/[tagline]. Render with `preferMongolianText`, falling back to
  /// `describeJsonLines`.
  final Object? description;

  final String? finalProjectType;
  final String? googleClassroomUrl;

  final bool? hasAttendance;
  final bool? hasCertTemplate;
  final bool? hasContractTemplate;
  final bool? hasExam;
  final bool? hasFinalProject;

  /// Raw decoded JSON — shape not confirmed. Render with
  /// `describeJsonLines`.
  final Object? instructors;

  /// Raw decoded JSON — shape not confirmed. Render with
  /// `describeJsonLines`.
  final Object? prerequisites;

  /// Raw wire string, not parsed — see [startDate]'s reasoning.
  final String? updatedAt;

  /// Raw decoded JSON — shape not confirmed. Render with
  /// `describeJsonLines`.
  final Object? whatsIncluded;

  /// Attaches the detail-only fields above to an already-parsed course.
  ///
  /// Exists so `HttpCourseRepository` can read the 22 fields the list and
  /// detail endpoints share exactly once — via the same code both endpoints
  /// already use — and layer the eighteen detail-only fields on top, rather
  /// than repeating the shared 22 a second time for detail responses.
  Course copyWithDetail({
    String? attendanceMethod,
    int? capacity,
    String? certTemplateName,
    String? contractTemplateName,
    String? createdAt,
    Object? curriculum,
    Object? description,
    String? finalProjectType,
    String? googleClassroomUrl,
    bool? hasAttendance,
    bool? hasCertTemplate,
    bool? hasContractTemplate,
    bool? hasExam,
    bool? hasFinalProject,
    Object? instructors,
    Object? prerequisites,
    String? updatedAt,
    Object? whatsIncluded,
  }) => Course(
    id: id,
    slug: slug,
    title: title,
    tagline: tagline,
    category: category,
    level: level,
    format: format,
    status: status,
    ageMin: ageMin,
    ageMax: ageMax,
    durationWeeks: durationWeeks,
    startDate: startDate,
    endDate: endDate,
    priceAmount: priceAmount,
    finalPriceAmount: finalPriceAmount,
    discountPercent: discountPercent,
    currency: currency,
    durationLabel: durationLabel,
    bannerImageUrl: bannerImageUrl,
    icon: icon,
    sortOrder: sortOrder,
    targetAudience: targetAudience,
    attendanceMethod: attendanceMethod,
    capacity: capacity,
    certTemplateName: certTemplateName,
    contractTemplateName: contractTemplateName,
    createdAt: createdAt,
    curriculum: curriculum,
    description: description,
    finalProjectType: finalProjectType,
    googleClassroomUrl: googleClassroomUrl,
    hasAttendance: hasAttendance,
    hasCertTemplate: hasCertTemplate,
    hasContractTemplate: hasContractTemplate,
    hasExam: hasExam,
    hasFinalProject: hasFinalProject,
    instructors: instructors,
    prerequisites: prerequisites,
    updatedAt: updatedAt,
    whatsIncluded: whatsIncluded,
  );
}
