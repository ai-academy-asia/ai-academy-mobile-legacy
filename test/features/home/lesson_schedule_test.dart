import 'package:aia_mobile/features/home/domain/lesson_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

import '../cohorts/fake_cohort_repository.dart';

/// `sampleCohort` meets Mondays and Wednesdays, 18:00–20:00, between
/// 2026-08-06 and 2026-10-06. Every date below is picked against that.
void main() {
  // 2026-08-10 is a Monday; 2026-08-12 the Wednesday after it.
  final monday = DateTime(2026, 8, 10);
  final wednesday = DateTime(2026, 8, 12);

  test('finds today\'s lesson while it is still ahead', () {
    final lesson = nextLessonFor(
      cohort: sampleCohort(),
      now: monday.add(const Duration(hours: 9)),
    );

    expect(lesson?.startsAt, DateTime(2026, 8, 10, 18));
    expect(lesson?.endsAt, DateTime(2026, 8, 10, 20));
  });

  test('keeps the lesson under way as the next one', () {
    final lesson = nextLessonFor(
      cohort: sampleCohort(),
      now: monday.add(const Duration(hours: 19)),
    );

    expect(lesson?.startsAt, DateTime(2026, 8, 10, 18));
    expect(lesson!.isLiveAt(monday.add(const Duration(hours: 19))), isTrue);
  });

  test('moves on to the next meeting day once today\'s has finished', () {
    final lesson = nextLessonFor(
      cohort: sampleCohort(),
      // 20:01 on the Monday — that lesson is over.
      now: monday.add(const Duration(hours: 20, minutes: 1)),
    );

    expect(lesson?.startsAt, DateTime(2026, 8, 12, 18));
  });

  test('skips days the cohort does not meet', () {
    // Tuesday.
    final lesson = nextLessonFor(
      cohort: sampleCohort(),
      now: DateTime(2026, 8, 11, 9),
    );

    expect(lesson?.startsAt, DateTime(2026, 8, 12, 18));
  });

  test('names the opening lesson for a cohort that has not started', () {
    // A Monday well before startDate — that Monday is not a lesson yet.
    final lesson = nextLessonFor(
      cohort: sampleCohort(),
      now: DateTime(2026, 7, 27, 9),
    );

    // 2026-08-06 is the Thursday the cohort opens; its first meeting day is
    // the Monday after it.
    expect(lesson?.startsAt, DateTime(2026, 8, 10, 18));
  });

  test('answers nothing once the cohort has ended', () {
    expect(
      nextLessonFor(cohort: sampleCohort(), now: DateTime(2026, 11, 2, 9)),
      isNull,
    );
  });

  test('answers nothing when the cohort meets on no day', () {
    expect(
      nextLessonFor(
        cohort: sampleCohort(meetingDays: const []),
        now: monday,
      ),
      isNull,
    );
  });

  test('answers nothing when the times are not times', () {
    expect(
      nextLessonFor(
        cohort: sampleCohort(startTime: 'evening', endTime: 'late'),
        now: monday,
      ),
      isNull,
    );
  });

  test('reads spelled-out day names too', () {
    final lesson = nextLessonFor(
      cohort: sampleCohort(meetingDays: const ['Wednesday']),
      now: monday.add(const Duration(hours: 9)),
    );

    expect(lesson?.startsAt, DateTime(2026, 8, 12, 18));
  });

  test('a lesson is not live before it starts or after it ends', () {
    final lesson = nextLessonFor(
      cohort: sampleCohort(),
      now: wednesday.add(const Duration(hours: 9)),
    )!;

    expect(
      lesson.isLiveAt(wednesday.add(const Duration(hours: 17, minutes: 59))),
      isFalse,
    );
    expect(lesson.isLiveAt(wednesday.add(const Duration(hours: 18))), isTrue);
    expect(lesson.isLiveAt(wednesday.add(const Duration(hours: 20))), isFalse);
  });
}
