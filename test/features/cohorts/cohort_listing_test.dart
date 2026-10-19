import 'package:aia_mobile/features/cohorts/domain/cohort_listing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_cohort_repository.dart';

/// The fail-closed rule Home and Certificates apply to the student's own
/// cohorts (Issue #445).
void main() {
  const teacher = 'cohort.teacher: expected an object, got Null';

  group('mayHideAny', () {
    test('nothing skipped hides nothing, listed or not', () {
      final listing = CohortListing(cohorts: [sampleCohort(id: 1)]);
      expect(listing.mayHideAny([1, 99]), isFalse);
    });

    test('a skipped row with one of the ids hides it', () {
      final listing = CohortListing(
        cohorts: [sampleCohort(id: 1)],
        skipped: const [SkippedCohort(id: 2, reason: teacher)],
      );
      expect(listing.mayHideAny([2]), isTrue);
      expect(listing.mayHideAny([1, 2]), isTrue);
    });

    test('a skipped row with another id hides none of the ids', () {
      final listing = CohortListing(
        cohorts: [sampleCohort(id: 1)],
        skipped: const [SkippedCohort(id: 2, reason: teacher)],
      );
      expect(listing.mayHideAny([1]), isFalse);
      // Not listed at all — a cohort `GET /cohorts` does not carry — is not
      // the skipped row's doing.
      expect(listing.mayHideAny([99]), isFalse);
    });

    test('a row with an unreadable id may hide any id not listed', () {
      final listing = CohortListing(
        cohorts: [sampleCohort(id: 1)],
        skipped: const [SkippedCohort(id: null, reason: 'cohort.id')],
      );
      expect(listing.mayHideAny([1]), isFalse);
      expect(listing.mayHideAny([99]), isTrue);
      expect(listing.mayHideAny([1, 99]), isTrue);
    });

    test('no ids: nothing to hide', () {
      const listing = CohortListing(
        skipped: [SkippedCohort(id: null, reason: 'cohort.id')],
      );
      expect(listing.mayHideAny(const []), isFalse);
    });
  });

  test('describeSkipped names each row by id and reason', () {
    const listing = CohortListing(
      skipped: [
        SkippedCohort(id: 2, reason: teacher),
        SkippedCohort(id: null, reason: 'cohort.id'),
      ],
    );
    expect(listing.describeSkipped(), '2: $teacher; unknown id: cohort.id');
  });
}
