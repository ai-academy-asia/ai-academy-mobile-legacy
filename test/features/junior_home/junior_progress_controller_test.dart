import 'package:aia_mobile/features/home/domain/home_failure.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_controller.dart';
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
}

class _ThrowingRepository extends FakeJuniorProgressRepository {
  @override
  Future<Never> getProgress() async => throw StateError('boom');
}
