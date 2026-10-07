import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_controller.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_junior_home_repository.dart';

void main() {
  JuniorHomeController controllerFor(FakeJuniorHomeRepository repository) =>
      JuniorHomeController(repository: repository);

  test('starts idle, before load() is ever called', () {
    final controller = controllerFor(FakeJuniorHomeRepository());

    expect(controller.loading, isFalse);
    expect(controller.map, isNull);
    expect(controller.errorMessage, isNull);
    // Not "empty" yet — nothing has been fetched.
    expect(controller.hasLoadedOnce, isFalse);
    expect(controller.isEmpty, isFalse);
  });

  test('reports loading while the request is in flight', () async {
    final repository = FakeJuniorHomeRepository(hold: true);
    final controller = controllerFor(repository);

    final pending = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(controller.loading, isTrue);
    expect(controller.isEmpty, isFalse);

    repository.release();
    await pending;
    expect(controller.loading, isFalse);
  });

  test('holds the fetched map on success', () async {
    final repository = FakeJuniorHomeRepository();
    final controller = controllerFor(repository);

    await controller.load();

    expect(controller.map, same(repository.map));
    expect(controller.errorMessage, isNull);
    expect(controller.isEmpty, isFalse);
    expect(repository.calls, 1);
  });

  test('a student enrolled in nothing reads as empty, not failed', () async {
    final controller = controllerFor(FakeJuniorHomeRepository(empty: true));

    await controller.load();

    expect(controller.isEmpty, isTrue);
    expect(controller.map, isNull);
    expect(controller.errorMessage, isNull);
  });

  group('a failed load', () {
    test('turns each failure kind into that kind\'s own copy', () async {
      for (final kind in CourseLearningFailureKind.values) {
        final controller = controllerFor(
          FakeJuniorHomeRepository(failure: CourseLearningFailure(kind)),
        );

        await controller.load();

        expect(
          controller.errorMessage,
          JuniorHomeStrings.messageFor(kind),
          reason: kind.name,
        );
        // A failure is not an empty screen — they read differently.
        expect(controller.isEmpty, isFalse);
      }
    });

    test('stops loading and holds no map', () async {
      final controller = controllerFor(
        FakeJuniorHomeRepository(
          failure: const CourseLearningFailure(
            CourseLearningFailureKind.network,
          ),
        ),
      );

      await controller.load();

      expect(controller.loading, isFalse);
      expect(controller.map, isNull);
    });

    test('a retry clears the message and re-requests', () async {
      final repository = FakeJuniorHomeRepository(
        failure: const CourseLearningFailure(CourseLearningFailureKind.network),
      );
      final controller = controllerFor(repository);
      await controller.load();
      expect(controller.errorMessage, isNotNull);

      repository.failure = null;
      await controller.load();

      expect(controller.errorMessage, isNull);
      expect(controller.map, isNotNull);
      expect(repository.calls, 2);
    });
  });

  test('does not notify after being disposed', () async {
    final repository = FakeJuniorHomeRepository(hold: true);
    final controller = controllerFor(repository);

    final pending = controller.load();
    controller.dispose();
    repository.release();

    // Would throw "used after being disposed" if the guard were missing.
    await pending;
  });

  group('one fetch at a time (Issue #221)', () {
    test('a load made while one is running joins it — one request', () async {
      final repository = FakeJuniorHomeRepository(hold: true);
      final controller = JuniorHomeController(repository: repository);

      final first = controller.load();
      final second = controller.load();
      await Future<void>.delayed(Duration.zero);

      expect(repository.calls, 1);
      expect(identical(first, second), isTrue);

      repository.release();
      await first;
      expect(controller.loading, isFalse);
    });

    test('once it finishes, the next load asks again', () async {
      final repository = FakeJuniorHomeRepository();
      final controller = JuniorHomeController(repository: repository);

      await controller.load();
      await controller.load();

      expect(repository.calls, 2);
    });
  });
}
