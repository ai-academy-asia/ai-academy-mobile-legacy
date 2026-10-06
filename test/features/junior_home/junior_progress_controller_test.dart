import 'package:aia_mobile/features/home/domain/home_failure.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_progress.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_controller.dart';
import 'package:aia_mobile/features/home/domain/lesson_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_junior_progress_repository.dart';

void main() {
  test('loads the progress', () async {
    final controller = JuniorProgressController(
      repository: FakeJuniorProgressRepository(),
    );
    expect(controller.hasLoadedOnce, isFalse);
    expect(controller.isEmpty, isFalse);

    await controller.load();

    expect(controller.progress, isNotNull);
    expect(controller.errorMessage, isNull);
    expect(controller.isEmpty, isFalse);
    expect(controller.loading, isFalse);
  });

  test('is loading while the request is in flight', () async {
    final repository = FakeJuniorProgressRepository(hold: true);
    final controller = JuniorProgressController(repository: repository);

    final load = controller.load();
    expect(controller.loading, isTrue);
    expect(controller.isEmpty, isFalse);

    repository.release();
    await load;
    expect(controller.loading, isFalse);
  });

  test('enrolled in nothing is empty, not an error', () async {
    final controller = JuniorProgressController(
      repository: FakeJuniorProgressRepository(empty: true),
    );

    await controller.load();

    expect(controller.isEmpty, isTrue);
    expect(controller.errorMessage, isNull);
  });

  test('each failure kind gets the dashboard\'s fixed message', () async {
    for (final kind in HomeFailureKind.values) {
      final controller = JuniorProgressController(
        repository: FakeJuniorProgressRepository(failure: HomeFailure(kind)),
      );

      await controller.load();

      expect(controller.errorMessage, HomeStrings.messageFor(kind));
      expect(controller.progress, isNull);
      expect(controller.isEmpty, isFalse);
    }
  });

  test('an unexpected exception still ends in a message', () async {
    final controller = JuniorProgressController(
      repository: _ThrowingRepository(),
    );

    await controller.load();

    expect(controller.errorMessage, HomeStrings.unexpectedError);
  });

  test('a retry clears the previous error and loads', () async {
    final repository = FakeJuniorProgressRepository(
      failure: const HomeFailure(HomeFailureKind.server),
    );
    final controller = JuniorProgressController(repository: repository);
    await controller.load();
    expect(controller.errorMessage, isNotNull);

    repository.failure = null;
    await controller.load();

    expect(controller.errorMessage, isNull);
    expect(controller.progress, isNotNull);
    expect(repository.callCount, 2);
  });

  group('calendar month', () {
    Future<JuniorProgressController> loaded(JuniorProgress progress) async {
      final controller = JuniorProgressController(
        repository: FakeJuniorProgressRepository(progress: progress),
      );
      await controller.load();
      return controller;
    }

    test('opens on the progress\'s own month, today selected', () async {
      final controller = await loaded(juniorTestStudentInOctober());

      expect(controller.displayedMonth, DateTime(2026, 10));
      expect(controller.displayedSelectedDay, 1);
      expect(controller.displayedDays, isEmpty);
    });

    test('pages back to June: its attended days, no selected day', () async {
      final controller = await loaded(juniorTestStudentInOctober());

      for (var i = 0; i < 4; i++) {
        controller.showPreviousMonth();
      }

      expect(controller.displayedMonth, DateTime(2026, 6));
      expect(controller.displayedSelectedDay, isNull);
      expect(controller.displayedDays, {
        for (final d in [16, 18, 20, 23, 25, 27, 30])
          d: JuniorDayStatus.attended,
      });
    });

    test('July shows the rest; back to October shows none again', () async {
      final controller = await loaded(juniorTestStudentInOctober());
      for (var i = 0; i < 3; i++) {
        controller.showPreviousMonth();
      }

      expect(controller.displayedMonth, DateTime(2026, 7));
      expect(controller.displayedDays, {
        for (final d in [2, 4, 7, 9]) d: JuniorDayStatus.attended,
      });

      for (var i = 0; i < 3; i++) {
        controller.showNextMonth();
      }
      expect(controller.displayedMonth, DateTime(2026, 10));
      expect(controller.displayedDays, isEmpty);
      expect(controller.displayedSelectedDay, 1);
    });

    test('pages across a year boundary both ways', () async {
      final controller = await loaded(
        JuniorProgress(month: DateTime(2026, 1), selectedDay: 5),
      );

      controller.showPreviousMonth();
      expect(controller.displayedMonth, DateTime(2025, 12));

      controller.showNextMonth();
      controller.showNextMonth();
      expect(controller.displayedMonth, DateTime(2026, 2));
    });

    test('its own month keeps the loaded marks; others with no calendar '
        'source are unmarked', () async {
      final controller = await loaded(
        JuniorProgress(
          month: DateTime(2026, 8),
          selectedDay: 7,
          days: const {7: JuniorDayStatus.lesson},
        ),
      );

      expect(controller.displayedDays, {7: JuniorDayStatus.lesson});
      controller.showNextMonth();
      expect(controller.displayedDays, isEmpty);
    });

    test('paging notifies listeners', () async {
      final controller = await loaded(juniorTestStudentInOctober());
      var notified = 0;
      controller.addListener(() => notified++);

      controller.showPreviousMonth();
      controller.showNextMonth();

      expect(notified, 2);
    });

    test('a reload opens on its own month again', () async {
      final controller = await loaded(juniorTestStudentInOctober());
      controller.showPreviousMonth();
      expect(controller.displayedMonth, DateTime(2026, 9));

      await controller.load();

      expect(controller.displayedMonth, DateTime(2026, 10));
    });

    test('nothing to page before a load', () {
      final controller = JuniorProgressController(
        repository: FakeJuniorProgressRepository(),
      );

      controller.showPreviousMonth();

      expect(controller.displayedMonth, isNull);
      expect(controller.displayedDays, isEmpty);
    });
  });

  group('first month (Issue #200)', () {
    Future<JuniorProgressController> startingOn(
      DateTime firstDay,
      DateTime today,
    ) async {
      final controller = JuniorProgressController(
        repository: FakeJuniorProgressRepository(
          progress: JuniorProgress(
            month: DateTime(today.year, today.month),
            selectedDay: today.day,
            calendar: JuniorCalendarSource(
              schedule: LessonSchedule(
                weekdays: const {DateTime.tuesday},
                start: (9, 0),
                end: (11, 0),
                firstDay: firstDay,
              ),
            ),
          ),
        ),
      );
      await controller.load();
      return controller;
    }

    test('stops at the cohort start month, across a year', () async {
      // Student A: started August 2023, seen in February 2024.
      final controller = await startingOn(
        DateTime(2023, 8, 14),
        DateTime(2024, 2, 5),
      );

      for (var i = 0; i < 6; i++) {
        expect(controller.canShowPreviousMonth, isTrue);
        controller.showPreviousMonth();
      }
      expect(controller.displayedMonth, DateTime(2023, 8));
      expect(controller.canShowPreviousMonth, isFalse);

      controller.showPreviousMonth();
      controller.showPreviousMonth();
      expect(controller.displayedMonth, DateTime(2023, 8));

      // Forward is unchanged.
      controller.showNextMonth();
      expect(controller.displayedMonth, DateTime(2023, 9));
      expect(controller.canShowPreviousMonth, isTrue);
    });

    test('each student has their own first month', () async {
      // Student B: February 2024. Student C: September 2025.
      final b = await startingOn(DateTime(2024, 2, 1), DateTime(2024, 3, 9));
      b.showPreviousMonth();
      b.showPreviousMonth();
      expect(b.displayedMonth, DateTime(2024, 2));

      final c = await startingOn(DateTime(2025, 9, 20), DateTime(2025, 9, 25));
      expect(c.canShowPreviousMonth, isFalse);
      c.showPreviousMonth();
      expect(c.displayedMonth, DateTime(2025, 9));
    });

    test('a blocked "<" does not notify', () async {
      final controller = await startingOn(
        DateTime(2025, 9, 20),
        DateTime(2025, 9, 25),
      );
      var notified = 0;
      controller.addListener(() => notified++);

      controller.showPreviousMonth();

      expect(notified, 0);
    });

    test('a cohort that has not started yet: "<" is already blocked', () async {
      final controller = await startingOn(
        DateTime(2026, 12, 1),
        DateTime(2026, 10, 6),
      );

      expect(controller.displayedMonth, DateTime(2026, 10));
      expect(controller.canShowPreviousMonth, isFalse);
    });

    test('nothing to page before a load', () {
      final controller = JuniorProgressController(
        repository: FakeJuniorProgressRepository(),
      );
      expect(controller.canShowPreviousMonth, isFalse);
    });
  });
}

class _ThrowingRepository extends FakeJuniorProgressRepository {
  @override
  Future<Never> getProgress() async => throw StateError('boom');
}
