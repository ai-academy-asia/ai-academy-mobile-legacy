/// A student's place in a cohort, as `POST /cohorts/{cohort_id}/enroll`
/// returns it.
///
/// The contract names the fields but gives no example values, so nullability
/// cannot be read off a captured response the way `Cohort`'s was. Two fields
/// are nullable because a fresh self-enrollment has, by definition, none:
/// [completedAt] (nothing is completed yet) and [createdByAdminId] (no admin
/// was involved). Everything else is required, and `HttpEnrollmentRepository`
/// fails loudly if a real response disagrees — treat that as a sign this
/// model needs to loosen.
///
/// [status], [createdVia] and the timestamps stay raw wire strings, for the
/// reason `Cohort.status` does: no confirmed value set or format.
class Enrollment {
  const Enrollment({
    required this.id,
    required this.studentId,
    required this.cohortId,
    required this.courseId,
    required this.status,
    required this.progressPct,
    required this.createdAt,
    required this.createdVia,
    this.completedAt,
    this.createdByAdminId,
  });

  final int id;
  final int studentId;
  final int cohortId;
  final int courseId;
  final String status;

  /// Progress through the course, as a percentage. Read from any JSON number —
  /// the contract does not say whether the API sends a whole number or not.
  final double progressPct;

  final String createdAt;
  final String createdVia;
  final String? completedAt;
  final int? createdByAdminId;
}
