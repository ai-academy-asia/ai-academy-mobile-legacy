import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_teacher_schedule_repository.dart';
import 'teacher_home_screen_test.dart' show sampleClass, tuesday;

void main() {
  FakeTeacherScheduleRepository repositoryWithWeek() =>
      FakeTeacherScheduleRepository(
        classes: [sampleClass(), sampleClass(id: 3)],
        sessions: {
          2: [
            sampleSession(id: 10, date: '2026-10-06'),
            sampleSession(id: 11, date: '2026-10-13'),
          ],
          3: [
            sampleSession(
              id: 20,
              cohortId: 3,
              date: '2026-10-05',
              start: (9, 0),
            ),
          ],
        },
      );

  test('starts on today, in today\'s Sunday-first week', () {
    final controller = TeacherScheduleController(
      repository: FakeTeacherScheduleRepository(),
      clock: tuesday,
    );
    expect(controller.selectedDay, DateTime(2026, 10, 6));
    expect(controller.weekStart, DateTime(2026, 10, 4));
    expect(controller.weekDays.first, DateTime(2026, 10, 4));
    expect(controller.weekDays.last, DateTime(2026, 10, 10));
  });

  test(
    'loads the week\'s sessions of every running class, earliest first',
    () async {
      final repository = repositoryWithWeek();
      final controller = TeacherScheduleController(
        repository: repository,
        clock: tuesday,
      );

      await controller.load();

      expect(controller.errorMessage, isNull);
      expect([for (final e in controller.sessions!) e.session.id], [20, 10]);
      expect(controller.sessions!.first.teacherClass.cohort.id, 3);
      // One request per class, for the week — `to` a day past it.
      expect(repository.sessionCalls, hasLength(2));
      for (final (_, from, to) in repository.sessionCalls) {
        expect(from, DateTime(2026, 10, 4));
        expect(to, DateTime(2026, 10, 11));
      }
      expect(controller.isEmpty, isFalse);
    },
  );

  test(
    'a day in the same week changes the selection without a fetch',
    () async {
      final repository = repositoryWithWeek();
      final controller = TeacherScheduleController(
        repository: repository,
        clock: tuesday,
      );
      await controller.load();

      controller.selectDay(DateTime(2026, 10, 9));
      await Future<void>.delayed(Duration.zero);

      expect(controller.selectedDay, DateTime(2026, 10, 9));
      expect(repository.sessionCalls, hasLength(2));
      expect(controller.sessions, hasLength(2));
    },
  );

  test('a day in another week loads that week, reusing the classes', () async {
    final repository = repositoryWithWeek();
    final controller = TeacherScheduleController(
      repository: repository,
      clock: tuesday,
    );
    await controller.load();

    controller.selectDay(DateTime(2026, 10, 14));
    expect(controller.sessions, isNull);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(controller.weekStart, DateTime(2026, 10, 11));
    expect([for (final e in controller.sessions!) e.session.id], [11]);
    expect(repository.classCalls, 1);
  });

  test('a class whose dates miss the week is not asked', () async {
    final repository = FakeTeacherScheduleRepository(
      classes: [sampleClass()],
      sessions: {
        2: [sampleSession()],
      },
    );
    final controller = TeacherScheduleController(
      repository: repository,
      // The class runs 2026-09-01 … 2026-12-20.
      clock: () => DateTime(2027, 2, 2),
    );

    await controller.load();

    expect(repository.sessionCalls, isEmpty);
    expect(controller.sessions, isEmpty);
    expect(controller.isEmpty, isTrue);
  });

  test('a failure sets the message and clears the week', () async {
    final repository = repositoryWithWeek()
      ..failure = const TeacherFailure(TeacherFailureKind.network);
    final controller = TeacherScheduleController(
      repository: repository,
      clock: tuesday,
    );

    await controller.load();

    expect(controller.errorMessage, HomeStrings.networkError);
    expect(controller.sessions, isNull);
    expect(controller.isEmpty, isFalse);

    repository.failure = null;
    await controller.load();
    expect(controller.errorMessage, isNull);
    expect(controller.sessions, hasLength(2));
  });

  test('a second load joins the one in flight', () async {
    final repository = repositoryWithWeek()..hold = true;
    final controller = TeacherScheduleController(
      repository: repository,
      clock: tuesday,
    );

    final first = controller.load();
    final second = controller.load();
    expect(controller.loading, isTrue);
    repository.release();
    await Future.wait([first, second]);

    expect(repository.classCalls, 1);
    expect(controller.loading, isFalse);
  });
}
