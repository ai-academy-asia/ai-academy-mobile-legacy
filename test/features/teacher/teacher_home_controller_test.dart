import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_class.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../cohorts/fake_cohort_repository.dart';
import 'fake_teacher_home_repository.dart';

void main() {
  // Tuesday 6 October 2026, inside every sample cohort's dates.
  DateTime tuesday() => DateTime(2026, 10, 6, 9);

  TeacherClass classOn(
    List<String> days, {
    int id = 1,
    String start = '18:00',
  }) => TeacherClass(
    cohort: sampleCohort(
      id: id,
      meetingDays: days,
      startTime: start,
      startDate: '2026-09-01',
      endDate: '2026-12-20',
    ),
    track: 'adult',
  );

  test('todaysClasses keeps only the classes meeting today, earliest '
      'first', () async {
    final repository = FakeTeacherHomeRepository(
      classes: [
        classOn(['tue'], id: 1, start: '18:00'),
        classOn(['wed'], id: 2, start: '09:00'),
        classOn(['tue', 'thu'], id: 3, start: '14:00'),
        classOn(['tue'], id: 4, start: '14:30'),
      ],
    );
    final controller = TeacherHomeController(
      repository: repository,
      clock: tuesday,
    );

    await controller.load();

    expect([for (final c in controller.todaysClasses) c.cohort.id], [3, 4, 1]);
    expect(controller.classes, hasLength(4));
    expect(controller.isEmpty, isFalse);
    expect(controller.errorMessage, isNull);
  });

  test('a class whose dates do not cover today is not today\'s', () async {
    final ended = TeacherClass(
      cohort: sampleCohort(
        meetingDays: ['tue'],
        startDate: '2026-01-01',
        endDate: '2026-03-01',
      ),
    );
    final controller = TeacherHomeController(
      repository: FakeTeacherHomeRepository(classes: [ended]),
      clock: tuesday,
    );

    await controller.load();

    expect(controller.todaysClasses, isEmpty);
    expect(controller.isEmpty, isTrue);
  });

  test('no classes at all is empty, not an error', () async {
    final controller = TeacherHomeController(
      repository: FakeTeacherHomeRepository(),
      clock: tuesday,
    );

    expect(controller.isEmpty, isFalse, reason: 'nothing has loaded yet');
    await controller.load();

    expect(controller.isEmpty, isTrue);
    expect(controller.errorMessage, isNull);
  });

  test('each failure kind has its fixed message', () async {
    final expected = {
      TeacherFailureKind.sessionExpired: HomeStrings.sessionExpired,
      TeacherFailureKind.network: HomeStrings.networkError,
      TeacherFailureKind.server: HomeStrings.serverError,
      TeacherFailureKind.rejected: HomeStrings.unexpectedError,
      TeacherFailureKind.unexpected: HomeStrings.unexpectedError,
    };
    for (final MapEntry(:key, :value) in expected.entries) {
      final controller = TeacherHomeController(
        repository: FakeTeacherHomeRepository(failure: TeacherFailure(key)),
        clock: tuesday,
      );

      await controller.load();

      expect(controller.errorMessage, value, reason: key.name);
      expect(controller.classes, isNull);
      expect(controller.isEmpty, isFalse);
    }
  });

  test(
    'a retry after a failure clears the error and shows the classes',
    () async {
      final repository = FakeTeacherHomeRepository(
        failure: const TeacherFailure(TeacherFailureKind.network),
        classes: [
          classOn(['tue']),
        ],
      );
      final controller = TeacherHomeController(
        repository: repository,
        clock: tuesday,
      );

      await controller.load();
      expect(controller.errorMessage, isNotNull);

      repository.failure = null;
      await controller.load();

      expect(controller.errorMessage, isNull);
      expect(controller.todaysClasses, hasLength(1));
      expect(repository.callCount, 2);
    },
  );

  test('a load while one is in flight joins it', () async {
    final repository = FakeTeacherHomeRepository(hold: true);
    final controller = TeacherHomeController(
      repository: repository,
      clock: tuesday,
    );

    final first = controller.load();
    final second = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(controller.loading, isTrue);
    repository.release();
    await Future.wait([first, second]);

    expect(repository.callCount, 1);
    expect(controller.loading, isFalse);
  });
}
