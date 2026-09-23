import 'package:aia_mobile/features/auth/domain/current_user.dart';
import 'package:aia_mobile/features/auth/domain/current_user_failure.dart';
import 'package:aia_mobile/features/auth/domain/current_user_repository.dart';
import 'package:aia_mobile/features/profile/presentation/profile_controller.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_current_user_repository.dart';

void main() {
  test('starts idle, before load() is ever called', () {
    final controller = ProfileController(repository: FakeCurrentUserRepository());

    expect(controller.loading, isFalse);
    expect(controller.hasLoadedOnce, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.user, isNull);
  });

  test('reports loading while the request is in flight', () async {
    final repository = FakeCurrentUserRepository(hold: true);
    final controller = ProfileController(repository: repository);

    final pending = controller.load();
    await Future<void>.delayed(Duration.zero);

    expect(controller.loading, isTrue);
    expect(controller.hasLoadedOnce, isFalse);

    repository.release();
    await pending;

    expect(controller.loading, isFalse);
    expect(controller.hasLoadedOnce, isTrue);
  });

  test('holds the fetched user on success', () async {
    final controller = ProfileController(repository: FakeCurrentUserRepository());

    await controller.load();

    expect(controller.user?.displayName, 'CRUD TestStudent');
    expect(controller.errorMessage, isNull);
  });

  test('maps each CurrentUserFailureKind to its own message', () async {
    final repository = FakeCurrentUserRepository();
    final controller = ProfileController(repository: repository);

    for (final kind in CurrentUserFailureKind.values) {
      repository.failure = CurrentUserFailure(kind);
      await controller.load();
      expect(controller.errorMessage, ProfileStrings.messageFor(kind), reason: kind.name);
    }
  });

  test('a failure clears any previously loaded user', () async {
    final repository = FakeCurrentUserRepository();
    final controller = ProfileController(repository: repository);
    await controller.load();
    expect(controller.user, isNotNull);

    repository.failure = const CurrentUserFailure(CurrentUserFailureKind.server);
    await controller.load();

    expect(controller.user, isNull);
    expect(controller.errorMessage, isNotNull);
  });

  test('a retry that succeeds clears the previous error', () async {
    final repository = FakeCurrentUserRepository(
      failure: const CurrentUserFailure(CurrentUserFailureKind.network),
    );
    final controller = ProfileController(repository: repository);
    await controller.load();
    expect(controller.errorMessage, isNotNull);

    repository.failure = null;
    await controller.load();

    expect(controller.errorMessage, isNull);
    expect(controller.user?.displayName, 'CRUD TestStudent');
  });

  test('an unrecognised exception still surfaces as a message, not a crash', () async {
    final controller = ProfileController(repository: _ThrowsNonCurrentUserFailure());

    await controller.load();

    expect(controller.errorMessage, ProfileStrings.unexpectedError);
    expect(controller.loading, isFalse);
  });

  test('notifies listeners on every state change', () async {
    final controller = ProfileController(repository: FakeCurrentUserRepository());
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.load();

    expect(notifications, greaterThanOrEqualTo(2));
  });

  test('does not notify after being disposed', () async {
    final repository = FakeCurrentUserRepository(hold: true);
    final controller = ProfileController(repository: repository);

    final pending = controller.load();
    controller.dispose();
    repository.release();

    await pending;
  });
}

/// A repository whose failure is not `CurrentUserFailure` at all, so the
/// controller's catch-all branch — not the typed one — has to handle it.
class _ThrowsNonCurrentUserFailure implements CurrentUserRepository {
  @override
  Future<CurrentUser> getCurrentUser() => throw StateError('boom');
}
