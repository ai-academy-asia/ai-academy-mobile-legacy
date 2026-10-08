import '../../course_learning/domain/course_certificate.dart';

/// One enrolled cohort's certificate card on the Certificate screen (Issue
/// #155): which cohort and course, the course's §2.9 certificate, and — for
/// one not yet issued — how far through the course the student is.
class CertificateEntry {
  const CertificateEntry({
    required this.cohortId,
    required this.cohortName,
    required this.courseTitle,
    required this.courseSlug,
    required this.certificate,
    this.progressPercent,
  });

  final int cohortId;

  /// The cohort instance's own name — the caption over the title, e.g.
  /// "Cohort 01", as Home's program card draws it.
  final String cohortName;

  /// The programme the cohort teaches — the card's title.
  final String courseTitle;

  /// The key both `/me/courses/{course_slug}/…` calls and "Continue
  /// learning" use.
  final String courseSlug;

  final CourseCertificate certificate;

  /// 0–100, for a certificate not yet issued: the learning path's
  /// `progress.percent`, or `/me/cohorts`' `progress_pct` when that call
  /// fails. Null when neither answered — the card then draws no bar rather
  /// than a made-up figure.
  final int? progressPercent;
}
