import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/junior_home/data/sample_junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';
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

  group('a fresh load (Issue #410)', () {
    JuniorLearningMap withProgress(int percent) {
      final sample = sampleJuniorLearningMap();
      return JuniorLearningMap(
        progress: JuniorCourseProgress(
          title: sample.progress.title,
          percentComplete: percent,
        ),
        nodes: sample.nodes,
        certificate: sample.certificate,
      );
    }

    test('never joins a fetch already running: it queues one after it, so '
        'what changed meanwhile is read', () async {
      final repository = FakeJuniorHomeRepository(hold: true);
      final controller = JuniorHomeController(repository: repository);

      final running = controller.load();
      await Future<void>.delayed(Duration.zero);
      // Back from a lesson, completed meanwhile — while that fetch runs.
      final fresh = controller.load(fresh: true);
      final again = controller.load(fresh: true);
      expect(identical(fresh, again), isTrue);
      expect(repository.calls, 1);

      repository
        ..hold = false
        ..map = withProgress(55);
      repository.release();
      await running;
      await fresh;

      // The running one, then exactly one more — not one per call.
      expect(repository.calls, 2);
      expect(controller.map?.progress.percentComplete, 55);
    });

    test(
      'with nothing running, it is an ordinary load — one request',
      () async {
        final repository = FakeJuniorHomeRepository();
        final controller = JuniorHomeController(repository: repository);

        await controller.load(fresh: true);

        expect(repository.calls, 1);
      },
    );

    test('a queued fetch is dropped once the controller is disposed', () async {
      final repository = FakeJuniorHomeRepository(hold: true);
      final controller = JuniorHomeController(repository: repository);

      final running = controller.load();
      await Future<void>.delayed(Duration.zero);
      final fresh = controller.load(fresh: true);
      controller.dispose();
      repository.release();
      await running;
      await fresh;

      expect(repository.calls, 1);
    });
  });
}
