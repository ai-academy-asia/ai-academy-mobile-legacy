import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard_repository.dart';
import 'package:aia_mobile/features/home/domain/home_failure.dart';
import 'package:aia_mobile/features/home/presentation/home_controller.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_home_dashboard_repository.dart';

void main() {
  test('starts idle, before load() is ever called', () {
    final controller = HomeController(
      repository: FakeHomeDashboardRepository(),
    );

    expect(controller.loading, isFalse);
    expect(controller.hasLoadedOnce, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.dashboard, isNull);
    expect(controller.isEmpty, isFalse);
  });

  test('reports loading while the request is in flight', () async {
    final repository = FakeHomeDashboardRepository(hold: true);
    final controller = HomeController(repository: repository);

    final pending = controller.load();
    await Future<void>.delayed(Duration.zero);

    expect(controller.loading, isTrue);
    expect(controller.hasLoadedOnce, isFalse);

    repository.release();
    await pending;

    expect(controller.loading, isFalse);
    expect(controller.hasLoadedOnce, isTrue);
  });

  test('holds the fetched dashboard on success', () async {
    final controller = HomeController(
      repository: FakeHomeDashboardRepository(
        dashboard: HomeDashboard(program: sampleProgram()),
      ),
    );

    await controller.load();

    expect(controller.dashboard?.program?.courseTitle, 'AI Engineer');
    expect(controller.errorMessage, isNull);
    expect(controller.isEmpty, isFalse);
  });

  test('a dashboard with no sections at all reads as empty', () async {
    final controller = HomeController(
      repository: FakeHomeDashboardRepository(),
    );

    await controller.load();

    expect(controller.isEmpty, isTrue);
    expect(controller.errorMessage, isNull);
  });

  test('maps each HomeFailureKind to its own message', () async {
    final repository = FakeHomeDashboardRepository();
    final controller = HomeController(repository: repository);

    for (final kind in HomeFailureKind.values) {
      repository.failure = HomeFailure(kind);
      await controller.load();
      expect(
        controller.errorMessage,
        HomeStrings.messageFor(kind),
        reason: kind.name,
      );
    }
  });

  test('a failure clears any previously loaded dashboard', () async {
    final repository = FakeHomeDashboardRepository(
      dashboard: HomeDashboard(program: sampleProgram()),
    );
    final controller = HomeController(repository: repository);
    await controller.load();
    expect(controller.dashboard, isNotNull);

    repository.failure = const HomeFailure(HomeFailureKind.server);
    await controller.load();

    expect(controller.dashboard, isNull);
    expect(controller.errorMessage, isNotNull);
    // A failed load is not an empty dashboard — the screen shows the error,
    // not "you are enrolled in nothing".
    expect(controller.isEmpty, isFalse);
  });

  test('a retry that succeeds clears the previous error', () async {
    final repository = FakeHomeDashboardRepository(
      failure: const HomeFailure(HomeFailureKind.network),
    );
    final controller = HomeController(repository: repository);
    await controller.load();
    expect(controller.errorMessage, isNotNull);

    repository.failure = null;
    repository.dashboard = HomeDashboard(program: sampleProgram());
    await controller.load();

    expect(controller.errorMessage, isNull);
    expect(controller.dashboard?.program, isNotNull);
  });

  test(
    'an unrecognised exception still surfaces as a message, not a crash',
    () async {
      final controller = HomeController(repository: _ThrowsNonHomeFailure());

      await controller.load();

      expect(controller.errorMessage, HomeStrings.unexpectedError);
      expect(controller.loading, isFalse);
    },
  );

  test('notifies listeners on every state change', () async {
    final controller = HomeController(
      repository: FakeHomeDashboardRepository(),
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.load();

    expect(notifications, greaterThanOrEqualTo(2));
  });

  test('does not notify after being disposed', () async {
    final repository = FakeHomeDashboardRepository(hold: true);
    final controller = HomeController(repository: repository);

    final pending = controller.load();
    controller.dispose();
    repository.release();

    await pending;
  });
}

/// A repository whose failure is not `HomeFailure` at all, so the
/// controller's catch-all branch — not the typed one — has to handle it.
class _ThrowsNonHomeFailure implements HomeDashboardRepository {
  @override
  Future<HomeDashboard> getDashboard() => throw StateError('boom');
}
