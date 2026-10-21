import '../../../core/models/localized_text.dart';

/// A scheduled cohort, as `GET /cohorts` lists it.
///
/// Nullability mirrors `Course`'s policy: a field is modelled nullable only
/// where a confirmed response showed it as `null` ([parentCohortId],
/// [scheduleNote], and [classroom] — `null` on an online cohort in the
/// production response, see its doc) — plus [capacity], [seatsAvailable] and
/// [graduationDate], which the backend's source shows it sends as `null`
/// (Issue #489). Everything else is required, and a
/// row missing one is rejected loudly — treat that as a sign this model needs
/// to loosen, not as a bug in the cohort.
///
/// A rejected row is rejected alone (Issue #445): `HttpCohortRepository`
/// reads the list row by row, leaves that cohort out and reports it in
/// `CohortListing.skipped`, and the other cohorts still load. Home,
/// Certificates and the Adult Progress tab fail closed when the skipped row
/// may be the student's own cohort — see `CohortListing.mayHideAny` — and
/// the teacher's screens fail on any skipped row, since every class there is
/// the teacher's own (`docs/ai/DATA_AND_API.md` §6).
///
/// [status] stays `String` rather than an enum, same reasoning as
/// `Course.status`: one confirmed value ("open") is not enough to say what
/// the full set is. [startDate], [endDate], [graduationDate], [startTime] and
/// [endTime] stay raw wire strings for the same reason `Course.startDate`
/// does — no confirmed guarantee the format is stable.
class Cohort {
  const Cohort({
    required this.id,
    required this.name,
    required this.courseId,
    required this.course,
    required this.teacher,
    required this.capacity,
    required this.enrolledCount,
    required this.seatsAvailable,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.graduationDate,
    required this.meetingDays,
    this.classroom,
    this.parentCohortId,
    this.scheduleNote,
  });

  final int id;
  final String name;

  /// Duplicates `course.id` — both are confirmed, separate fields on the
  /// wire, so both are kept rather than one being derived from the other.
  final int courseId;

  final CohortCourse course;

  /// Where the cohort meets. `null` for a cohort with no classroom — the
  /// production `GET /cohorts` sends `"classroom": null` for the online
  /// `ai-applied-online` cohort. Nothing in the app draws it yet.
  final CohortClassroom? classroom;

  final CohortTeacher teacher;

  /// `null` for a cohort with no capacity set (Issue #489).
  final int? capacity;
  final int enrolledCount;

  /// `null` exactly when [capacity] is — the backend derives it.
  final int? seatsAvailable;

  /// e.g. "open".
  final String status;

  /// Raw wire strings — e.g. "2026-08-06", "18:00". `''` when the cohort
  /// has none: the backend sends `null` (or `""`) for a date or time not
  /// yet set (Issue #491). Readers treat `''` like any unparseable value.
  final String startDate;
  final String endDate;
  final String startTime;
  final String endTime;

  /// `null` for a cohort with no graduation date — the backend never
  /// requires one (Issue #489).
  final String? graduationDate;

  /// e.g. `["mon", "wed"]`. Lowercase three-letter weekday codes, unconfirmed
  /// as a closed set — shown verbatim rather than mapped to display names.
  /// Empty when none are set — `null` on the wire reads as `[]` (Issue #491).
  final List<String> meetingDays;

  final int? parentCohortId;
  final String? scheduleNote;
}

/// The course a cohort belongs to, as the cohort list embeds it — a smaller
/// projection than `features/courses`' own `Course`, confirmed separately for
/// this endpoint.
class CohortCourse {
  const CohortCourse({required this.id, required this.slug, required this.title});

  final int id;
  final String slug;

  /// Built from the wire's flat `title_en` / `title_mn` fields — not the
  /// nested `{"en", "mn"}` object `Course.title` reads, a genuinely different
  /// shape on this endpoint. [LocalizedText] is reused as the result type
  /// because it already represents "either half may be absent", which suits
  /// two fields neither shown as `null` nor guaranteed to stay that way.
  final LocalizedText title;
}

class CohortClassroom {
  const CohortClassroom({required this.id, required this.name, required this.centerName});

  final int id;
  final String name;
  final String centerName;
}

class CohortTeacher {
  const CohortTeacher({required this.id, required this.name});

  final int id;
  final String name;
}
