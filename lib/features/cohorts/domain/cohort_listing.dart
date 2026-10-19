import 'cohort.dart';

/// A cohort list read row by row (Issue #445): the rows that parsed, and a
/// report of the ones that did not.
///
/// One malformed row no longer fails the whole list. It is left out of
/// [cohorts] and named in [skipped], so a caller that needs a particular
/// cohort can still tell "not listed" from "listed, but unreadable" — see
/// [mayHideAny].
class CohortListing {
  const CohortListing({this.cohorts = const [], this.skipped = const []});

  /// Every row that matched the `Cohort` contract, in the order received.
  final List<Cohort> cohorts;

  /// Every row that did not, in the order received.
  final List<SkippedCohort> skipped;

  /// Whether a cohort with any of [ids] may be among the [skipped] rows.
  ///
  /// True when a skipped row carries one of [ids], or when a skipped row's id
  /// could not be read and one of [ids] is missing from [cohorts] — it might
  /// be that row. A caller showing the student's own cohort treats true as a
  /// server failure rather than "not enrolled": fail closed.
  bool mayHideAny(Iterable<int> ids) {
    if (skipped.isEmpty) return false;
    final wanted = ids.toSet();
    if (skipped.any((row) => row.id != null && wanted.contains(row.id))) {
      return true;
    }
    if (!skipped.any((row) => row.id == null)) return false;
    final listed = {for (final cohort in cohorts) cohort.id};
    return !listed.containsAll(wanted);
  }

  /// A failure detail naming the skipped rows: each id (when readable) and
  /// the field that failed. Never a value from the response.
  String describeSkipped() => [
    for (final row in skipped) '${row.id ?? 'unknown id'}: ${row.reason}',
  ].join('; ');
}

/// One cohort row left out of a [CohortListing].
class SkippedCohort {
  const SkippedCohort({required this.id, required this.reason});

  /// The row's `id`, or null when the id itself was missing or not a number.
  final int? id;

  /// The failing field and the type that arrived — for example
  /// `cohort.teacher: expected an object, got Null`. It names fields and
  /// types only, never a value, so it carries no personal data.
  final String reason;
}
