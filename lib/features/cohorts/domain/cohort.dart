import '../../../core/models/localized_text.dart';

/// A scheduled cohort, as `GET /cohorts` lists it.
///
/// Nullability mirrors `Course`'s policy: a field is modelled nullable only
/// where the one confirmed response showed it as `null` ([parentCohortId],
/// [scheduleNote]). Everything else is required, and `HttpCohortRepository`
/// fails loudly if a required field is missing on a real response — treat
/// that as a sign this model needs to loosen, not as a bug in the cohort.
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
    required this.classroom,
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
    this.parentCohortId,
    this.scheduleNote,
  });

  final int id;
  final String name;

  /// Duplicates `course.id` — both are confirmed, separate fields on the
  /// wire, so both are kept rather than one being derived from the other.
  final int courseId;

  final CohortCourse course;
  final CohortClassroom classroom;
  final CohortTeacher teacher;

  final int capacity;
  final int enrolledCount;
  final int seatsAvailable;

  /// e.g. "open".
  final String status;

  /// Raw wire strings — e.g. "2026-08-06", "18:00".
  final String startDate;
  final String endDate;
  final String startTime;
  final String endTime;
  final String graduationDate;

  /// e.g. `["mon", "wed"]`. Lowercase three-letter weekday codes, unconfirmed
  /// as a closed set — shown verbatim rather than mapped to display names.
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
