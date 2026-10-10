import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/domain/home_failure.dart';
import 'package:aia_mobile/features/home/domain/lesson_schedule.dart';
import 'package:aia_mobile/features/junior_home/data/api_junior_progress_repository.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_progress.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/fake_home_dashboard_repository.dart';

/// [ApiJuniorProgressRepository] is a mapper over the adult dashboard: these
/// tests feed it a [HomeDashboard] and check what reaches [JuniorProgress] —
/// and, as much, what does not.
void main() {
  // Monday 10 August 2026, mid-morning.
  final now = DateTime(2026, 8, 10, 9, 30);

  /// Mondays and Wednesdays, with no first or last day.
  const monWed = LessonSchedule(
    weekdays: {DateTime.monday, DateTime.wednesday},
    start: (18, 0),
    end: (20, 0),
    firstDay: null,
    lastDay: null,
  );
  final windowed = LessonSchedule(
    weekdays: const {DateTime.monday, DateTime.wednesday},
    start: (18, 0),
    end: (20, 0),
    firstDay: DateTime(2026, 8, 6),
    lastDay: DateTime(2026, 10, 6),
  );

  ApiJuniorProgressRepository repository(HomeDashboard dashboard) =>
      ApiJuniorProgressRepository(
        dashboard: FakeHomeDashboardRepository(dashboard: dashboard),
        clock: () => now,
      );

  test('enrolled in nothing answers null, not a failure', () async {
    expect(await repository(const HomeDashboard()).getProgress(), isNull);
  });

  test('a dashboard failure propagates as the dashboard\'s own', () async {
    final progress = ApiJuniorProgressRepository(
      dashboard: FakeHomeDashboardRepository(
        failure: const HomeFailure(HomeFailureKind.sessionExpired),
      ),
      clock: () => now,
    );

    await expectLater(
      progress.getProgress(),
      throwsA(
        isA<HomeFailure>().having(
          (f) => f.kind,
          'kind',
          HomeFailureKind.sessionExpired,
        ),
      ),
    );
  });

  test(
    'payment, attendance and next lesson are the dashboard\'s own',
    () async {
      final lesson = sampleLesson(start: DateTime(2026, 8, 10, 18));
      final progress = (await repository(
        HomeDashboard(
          program: sampleProgram(nextLesson: lesson, schedule: windowed),
          stats: const [
            PaymentStat(PaymentStatus.dueIn(5), layout: HomeStatLayout.tile),
            AttendanceStat(
              AttendanceSummary(attended: 3, total: 6, percent: 50),
              layout: HomeStatLayout.tile,
            ),
          ],
        ),
      ).getProgress())!;

      expect(progress.payment!.daysUntilDue, 5);
      expect(progress.attendance!.attended, 3);
      expect(progress.attendance!.total, 6);
      expect(progress.attendance!.percent, 50);
      expect(progress.nextLesson, same(lesson));
    },
  );

  test('an overdue payment stays overdue', () async {
    final progress = (await repository(
      HomeDashboard(
        program: sampleProgram(),
        stats: const [
          PaymentStat(PaymentStatus.overdue(), layout: HomeStatLayout.row),
        ],
      ),
    ).getProgress())!;

    expect(progress.payment!.isOverdue, isTrue);
  });

  test('sections the dashboard left out stay out', () async {
    final progress = (await repository(
      HomeDashboard(program: sampleProgram()),
    ).getProgress())!;

    expect(progress.payment, isNull);
    expect(progress.attendance, isNull);
    expect(progress.nextLesson, isNull);
  });

  test(
    'the dashboard\'s unsigned contract passes through (Issue #300)',
    () async {
      final progress = (await repository(
        HomeDashboard(
          program: sampleProgram(schedule: windowed),
          contract: const ContractStatus(signed: false),
        ),
      ).getProgress())!;

      expect(progress.contract?.signed, isFalse);
    },
  );

  test(
    'no contract without one on the dashboard; no exam figure — ever (BACKEND GAP)',
    () async {
      final progress = (await repository(
        HomeDashboard(
          program: sampleProgram(schedule: windowed),
          stats: const [
            AttendanceStat(
              AttendanceSummary(attended: 0, total: 0, percent: 0),
              layout: HomeStatLayout.row,
            ),
          ],
        ),
      ).getProgress())!;

      expect(progress.contract, isNull);
      expect(progress.examPercent, isNull);
    },
  );

  group('calendar', () {
    test('this month, today selected', () async {
      final progress = (await repository(
        HomeDashboard(program: sampleProgram(schedule: windowed)),
      ).getProgress())!;

      expect(progress.month, DateTime(2026, 8));
      expect(progress.selectedDay, 10);
    });

    test('the cohort\'s lesson days, and lesson days only', () async {
      final progress = (await repository(
        HomeDashboard(program: sampleProgram(schedule: windowed)),
      ).getProgress())!;

      // August 2026 Mondays/Wednesdays from the 6th on.
      expect(progress.days.keys.toSet(), {10, 12, 17, 19, 24, 26, 31});
      // Past lesson days (none attended as far as anyone knows) are still
      // just lesson days: nothing is ever marked missed or attended.
      expect(progress.days.values.toSet(), {JuniorDayStatus.lesson});
    });

    test(
      'an unbounded schedule marks every meeting day of the month',
      () async {
        final progress = (await repository(
          HomeDashboard(program: sampleProgram(schedule: monWed)),
        ).getProgress())!;

        expect(progress.days.keys.toSet(), {3, 5, 10, 12, 17, 19, 24, 26, 31});
      },
    );

    group('attended sessions (GET /me/attendance sessions)', () {
      // Cohort 7 as production sends it: Tue/Thu/Sat, 16 Jun – 9 Jul 2026.
      final cohort7 = LessonSchedule(
        weekdays: const {
          DateTime.tuesday,
          DateTime.thursday,
          DateTime.saturday,
        },
        start: (9, 0),
        end: (12, 0),
        firstDay: DateTime(2026, 6, 16),
        lastDay: DateTime(2026, 7, 9),
      );

      /// The junior test student's 11 sessions — all present or late, so all
      /// attended — as the dashboard passes them on.
      final attendedDates = {
        for (final d in [16, 18, 20, 23, 25, 27, 30]) DateTime(2026, 6, d),
        for (final d in [2, 4, 7, 9]) DateTime(2026, 7, d),
      };

      Future<JuniorProgress> progressAt(DateTime now) async =>
          (await ApiJuniorProgressRepository(
            dashboard: FakeHomeDashboardRepository(
              dashboard: HomeDashboard(
                program: sampleProgram(schedule: cohort7),
                stats: [
                  AttendanceStat(
                    AttendanceSummary(
                      attended: 11,
                      total: 11,
                      percent: 100,
                      attendedDates: attendedDates,
                    ),
                    layout: HomeStatLayout.row,
                  ),
                ],
              ),
            ),
            clock: () => now,
          ).getProgress())!;

      test('seen in October 2026, its calendar still answers June and July '
          '— the months paging reaches', () async {
        final progress = await progressAt(DateTime(2026, 10, 1, 10));
        final calendar = progress.calendar!;

        expect(progress.days, isEmpty);
        expect(calendar.marksIn(DateTime(2026, 6)), {
          for (final d in [16, 18, 20, 23, 25, 27, 30])
            d: JuniorDayStatus.attended,
        });
        expect(calendar.marksIn(DateTime(2026, 7)), {
          for (final d in [2, 4, 7, 9]) d: JuniorDayStatus.attended,
        });
        expect(calendar.marksIn(DateTime(2026, 10)), progress.days);
      });

      test('June 2026: every attended lesson day is marked attended', () async {
        final progress = await progressAt(DateTime(2026, 6, 20, 10));

        expect(progress.days, {
          for (final d in [16, 18, 20, 23, 25, 27, 30])
            d: JuniorDayStatus.attended,
        });
      });

      test('only the shown month\'s sessions are marked', () async {
        final progress = await progressAt(DateTime(2026, 7, 1, 10));

        expect(progress.days, {
          for (final d in [2, 4, 7, 9]) d: JuniorDayStatus.attended,
        });
      });

      test(
        'today, October 2026: the month it opens on has nothing to mark',
        () async {
          final progress = await progressAt(DateTime(2026, 10, 1, 10));

          expect(progress.month, DateTime(2026, 10));
          expect(progress.days, isEmpty);
        },
      );

      test('an attended day wins over its lesson mark; others stay lessons; '
          'with no absent session nothing is marked missed', () async {
        // Only one of August's (Mon/Wed) lesson days has a session reported.
        final progress = (await ApiJuniorProgressRepository(
          dashboard: FakeHomeDashboardRepository(
            dashboard: HomeDashboard(
              program: sampleProgram(schedule: windowed),
              stats: [
                AttendanceStat(
                  AttendanceSummary(
                    attended: 1,
                    total: 3,
                    percent: 33,
                    attendedDates: {DateTime(2026, 8, 12)},
                  ),
                  layout: HomeStatLayout.row,
                ),
              ],
            ),
          ),
          clock: () => now,
        ).getProgress())!;

        expect(progress.days[12], JuniorDayStatus.attended);
        expect(progress.days[10], JuniorDayStatus.lesson);
        expect(progress.days[17], JuniorDayStatus.lesson);
        expect(progress.days.values, isNot(contains(JuniorDayStatus.missed)));
      });

      test(
        'a session on an unscheduled day is still marked attended',
        () async {
          final progress = (await ApiJuniorProgressRepository(
            dashboard: FakeHomeDashboardRepository(
              dashboard: HomeDashboard(
                program: sampleProgram(schedule: windowed),
                stats: [
                  AttendanceStat(
                    AttendanceSummary(
                      attended: 1,
                      total: 1,
                      percent: 100,
                      // A Friday — not a Mon/Wed meeting day.
                      attendedDates: {DateTime(2026, 8, 14)},
                    ),
                    layout: HomeStatLayout.row,
                  ),
                ],
              ),
            ),
            clock: () => now,
          ).getProgress())!;

          expect(progress.days[14], JuniorDayStatus.attended);
        },
      );
    });

    group('missed sessions (GET /me/attendance status "absent")', () {
      // Cohort 7's shape (Tue/Thu/Sat, 16 Jun – 9 Jul 2026), seen in
      // October: 23 June and 2 July absent, 9 July with no session at all.
      final cohort7 = LessonSchedule(
        weekdays: const {
          DateTime.tuesday,
          DateTime.thursday,
          DateTime.saturday,
        },
        start: (9, 0),
        end: (12, 0),
        firstDay: DateTime(2026, 6, 16),
        lastDay: DateTime(2026, 7, 9),
      );

      Future<JuniorProgress> progressWith({
        required Set<DateTime> attendedDates,
        required Set<DateTime> missedDates,
        DateTime? at,
      }) async => (await ApiJuniorProgressRepository(
        dashboard: FakeHomeDashboardRepository(
          dashboard: HomeDashboard(
            program: sampleProgram(schedule: cohort7),
            stats: [
              AttendanceStat(
                AttendanceSummary(
                  attended: attendedDates.length,
                  total: attendedDates.length + missedDates.length,
                  percent: 80,
                  attendedDates: attendedDates,
                  missedDates: missedDates,
                ),
                layout: HomeStatLayout.row,
              ),
            ],
          ),
        ),
        clock: () => at ?? DateTime(2026, 10, 1, 10),
      ).getProgress())!;

      final attendedDates = {
        for (final d in [16, 18, 20, 25, 27, 30]) DateTime(2026, 6, d),
        for (final d in [4, 7]) DateTime(2026, 7, d),
      };
      final missedDates = {DateTime(2026, 6, 23), DateTime(2026, 7, 2)};

      test('an absent session is marked missed in the months paging '
          'reaches', () async {
        final calendar = (await progressWith(
          attendedDates: attendedDates,
          missedDates: missedDates,
        )).calendar!;

        expect(calendar.marksIn(DateTime(2026, 6)), {
          for (final d in [16, 18, 20, 25, 27, 30]) d: JuniorDayStatus.attended,
          23: JuniorDayStatus.missed,
        });
        expect(calendar.marksIn(DateTime(2026, 7))[2], JuniorDayStatus.missed);
      });

      test('the month it opens on carries its missed days too', () async {
        final progress = await progressWith(
          attendedDates: attendedDates,
          missedDates: missedDates,
          at: DateTime(2026, 6, 24, 10),
        );

        expect(progress.month, DateTime(2026, 6));
        expect(progress.days[23], JuniorDayStatus.missed);
      });

      test('a past lesson day with no session stays a lesson day — '
          'missed is never inferred', () async {
        final july = (await progressWith(
          attendedDates: attendedDates,
          missedDates: missedDates,
        )).calendar!.marksIn(DateTime(2026, 7));

        expect(july[9], JuniorDayStatus.lesson);
        expect(
          july.entries
              .where((e) => e.value == JuniorDayStatus.missed)
              .map((e) => e.key),
          [2],
        );
      });

      test('an attended session wins over a missed one on its day', () async {
        final june = (await progressWith(
          attendedDates: {DateTime(2026, 6, 23)},
          missedDates: {DateTime(2026, 6, 23)},
        )).calendar!.marksIn(DateTime(2026, 6));

        expect(june[23], JuniorDayStatus.attended);
      });

      test(
        'an absent session on an unscheduled day is still marked missed',
        () async {
          // A Monday — not a Tue/Thu/Sat meeting day.
          final june = (await progressWith(
            attendedDates: const {},
            missedDates: {DateTime(2026, 6, 22)},
          )).calendar!.marksIn(DateTime(2026, 6));

          expect(june[22], JuniorDayStatus.missed);
        },
      );
    });

    test('no schedule: a calendar with no marks', () async {
      final progress = (await repository(
        HomeDashboard(program: sampleProgram()),
      ).getProgress())!;

      expect(progress.days, isEmpty);
      expect(progress.month, DateTime(2026, 8));
    });
  });
}
