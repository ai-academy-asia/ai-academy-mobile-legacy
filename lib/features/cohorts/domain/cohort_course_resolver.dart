import '../../courses/domain/course.dart';
import 'cohort.dart';

/// Resolves which confirmed [Course] a cohort's own embedded course stub
/// ([CohortCourse]) actually refers to.
///
/// **Why this exists.** `GET /cohorts` embeds its own copy of the course's
/// id/slug/title on each entry, and that copy can drift from the live
/// catalog `GET /courses` returns. Confirmed live, 2026: the one cohort's
/// embedded course is `{id: 6, slug: "summer-bootcamp-2027", title:
/// "Summer Bootcamp"}`, while `GET /courses` has no course with id `6` or
/// that slug at all — its one course is `{id: 4, slug: "summer-bootcamp",
/// title: "Summer Bootcamp"}`. Same title, stale id and slug. That mismatch
/// is what sent Home's and Cohort List's "open Course Detail" tap to a slug
/// `GET /courses/{slug}` correctly 404s on — a real course-catalog gap, not
/// a bug in `HttpCourseRepository` or in Course Detail's own 404 handling,
/// neither of which this function changes.
///
/// **A frontend compatibility fallback, not a new backend contract.** Every
/// field this reads is already-confirmed data from `GET /cohorts` and
/// `GET /courses` — nothing invented, nothing hardcoded. It tries three
/// signals in decreasing order of confidence:
///
///  1. `id` — the strongest signal, and the one that makes this function a
///     no-op once the embedded stub's id is corrected.
///  2. `slug` — same idea, for a partial fix.
///  3. Title (Mongolian, then English) — today's actual match: the one
///     field the drifted stub still agrees with the catalog on.
///
/// Returns null if nothing matches by any of the three. Callers fall back to
/// the cohort's own (possibly stale) slug in that case, which reproduces
/// today's existing, already-correct 404 handling rather than guessing at a
/// course that cannot be identified.
Course? resolveCohortCourse(List<Course> courses, CohortCourse cohortCourse) {
  for (final course in courses) {
    if (course.id == cohortCourse.id) return course;
  }
  for (final course in courses) {
    if (course.slug == cohortCourse.slug) return course;
  }

  final cohortTitle = cohortCourse.title.mn ?? cohortCourse.title.en;
  if (cohortTitle != null && cohortTitle.isNotEmpty) {
    for (final course in courses) {
      final courseTitle = course.title.mn ?? course.title.en;
      if (courseTitle == cohortTitle) return course;
    }
  }

  return null;
}
