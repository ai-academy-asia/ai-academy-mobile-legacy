import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_path.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/domain/home_failure.dart';
import 'package:aia_mobile/features/junior_home/data/api_junior_home_repository.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';
import 'package:flutter_test/flutter_test.dart';

import '../course_learning/fake_course_learning_repository.dart';
import '../home/fake_home_dashboard_repository.dart';

/// Junior Home over the two repositories it composes.
///
/// No `MockClient` here: the HTTP layer is `HttpCourseLearningRepository`'s
/// and is already covered by its own suite. What this file is about is the
/// part Issue #100 adds — resolving the slug, and turning one
/// [CourseLearningPath] into a [JuniorLearningMap] without deriving anything
/// the server already decided.
void main() {
  ApiJuniorHomeRepository repositoryFor({
    HomeDashboard? dashboard,
    HomeFailure? dashboardFailure,
    CourseLearningPath? path,
    CourseLearningFailure? learningFailure,
    FakeCourseLearningRepository? learning,
  }) => ApiJuniorHomeRepository(
    dashboardRepository: FakeHomeDashboardRepository(
      dashboard: dashboard ?? HomeDashboard(program: sampleProgram()),
      failure: dashboardFailure,
    ),
    courseLearningRepository:
        learning ??
        FakeCourseLearningRepository(path: path, failure: learningFailure),
  );

  Future<CourseLearningFailure> failureFrom(
    ApiJuniorHomeRepository repository,
  ) async {
    try {
      await repository.getLearningMap();
    } on CourseLearningFailure catch (failure) {
      return failure;
    }
    fail('expected a CourseLearningFailure');
  }

  group('resolving the course', () {
    test('asks the learning API for the enrolled course\'s own slug', () async {
      final learning = FakeCourseLearningRepository();
      await repositoryFor(
        dashboard: HomeDashboard(
          program: sampleProgram(courseSlug: 'summer-bootcamp-2027'),
        ),
        learning: learning,
      ).getLearningMap();

      // Not a hardcoded Junior slug: whatever the student is enrolled in.
      expect(learning.calls, ['summer-bootcamp-2027']);
    });

    test('a student enrolled in nothing is empty, not an error', () async {
      final learning = FakeCourseLearningRepository();
      final map = await repositoryFor(
        dashboard: const HomeDashboard(),
        learning: learning,
      ).getLearningMap();

      expect(map, isNull);
      // And the learning endpoint is never called without a slug.
      expect(learning.calls, isEmpty);
    });

    test('a dashboard failure keeps its meaning', () async {
      for (final (dashboard, expected)
          in <(HomeFailureKind, CourseLearningFailureKind)>[
            (
              HomeFailureKind.sessionExpired,
              CourseLearningFailureKind.sessionExpired,
            ),
            (HomeFailureKind.network, CourseLearningFailureKind.network),
            (HomeFailureKind.server, CourseLearningFailureKind.server),
            (HomeFailureKind.unexpected, CourseLearningFailureKind.unexpected),
          ]) {
        final failure = await failureFrom(
          repositoryFor(dashboardFailure: HomeFailure(dashboard)),
        );
        expect(failure.kind, expected, reason: dashboard.name);
      }
    });

    test('a learning-API failure passes straight through', () async {
      final failure = await failureFrom(
        repositoryFor(
          learningFailure: const CourseLearningFailure(
            CourseLearningFailureKind.notEnrolled,
          ),
        ),
      );

      expect(failure.kind, CourseLearningFailureKind.notEnrolled);
    });
  });

  group('mapping the learning path', () {
    JuniorLearningMap mapOf(CourseLearningPath path) => juniorMapFrom(path);

    test('shows the server\'s percent, and never derives one', () async {
      // One of two modules complete — a module-based figure would be 50.
      final map = mapOf(
        samplePath(
          percentComplete: 30,
          modules: [
            sampleModule(id: 1, order: 1, completed: true),
            sampleModule(id: 2, order: 2),
          ],
        ),
      );

      expect(map.progress.percentComplete, 30);
    });

    test('takes the course title for the card', () {
      final map = mapOf(samplePath(courseTitle: 'AI BootCamp'));

      expect(map.progress.title, 'AI BootCamp');
      // The same field fills the certificate panel's course line.
      expect(map.certificate.courseName, 'AI BootCamp');
    });

    test('keeps the course slug, so a node can open the course (#174)', () {
      expect(
        mapOf(samplePath(courseSlug: 'junior-ai')).courseSlug,
        'junior-ai',
      );
    });

    test('maps completed and locked straight off the server', () {
      final map = mapOf(
        samplePath(
          modules: [
            sampleModule(id: 1, order: 1, completed: true),
            sampleModule(id: 2, order: 2, locked: true),
            sampleModule(id: 3, order: 3),
          ],
        ),
      );

      expect(map.nodes.map((n) => n.state), [
        JuniorNodeState.completed,
        JuniorNodeState.locked,
        // Neither flag set: open and unfinished.
        JuniorNodeState.current,
      ]);
    });

    test('completed wins over locked, so a node is never both', () {
      final map = mapOf(
        samplePath(
          modules: [
            sampleModule(id: 1, order: 1, completed: true, locked: true),
          ],
        ),
      );

      expect(map.nodes.single.state, JuniorNodeState.completed);
    });

    test('orders nodes by module.order, not by array position', () {
      final map = mapOf(
        samplePath(
          modules: [
            sampleModule(id: 30, order: 3),
            sampleModule(id: 10, order: 1),
            sampleModule(id: 20, order: 2),
          ],
        ),
      );

      expect(map.nodes.map((n) => n.id), [10, 20, 30]);
    });

    test('carries the server-selected continue target whole', () {
      final map = mapOf(
        samplePath(continueModuleId: 31, continueLessonId: 204),
      );

      expect(map.continueModuleId, 31);
      expect(map.continueLessonId, 204);
    });

    test('no continue target when the server selected none', () {
      final map = mapOf(samplePath());

      expect(map.continueModuleId, isNull);
      expect(map.continueLessonId, isNull);
    });

    test('maps each certificate status the contract lists', () {
      const cases = {
        'not_eligible': JuniorCertificateStatus.notEligible,
        'eligible': JuniorCertificateStatus.eligible,
        'issued': JuniorCertificateStatus.issued,
      };
      for (final entry in cases.entries) {
        final map = mapOf(samplePath(certificateStatus: entry.key));
        expect(map.certificate.status, entry.value, reason: entry.key);
      }
    });

    test('an absent or unknown status is null, not a guessed state', () {
      expect(mapOf(samplePath()).certificate.status, isNull);
      expect(
        mapOf(samplePath(certificateStatus: 'revoked')).certificate.status,
        isNull,
      );
    });

    test('keeps the design\'s own certificate copy', () {
      final map = mapOf(samplePath());

      expect(map.certificate.track, 'Junior');
      expect(map.certificate.description, 'Earn a Certificate of completion');
    });

    test('a course with no modules maps to no nodes', () {
      final map = mapOf(samplePath(modules: []));

      expect(map.nodes, isEmpty);
      expect(map.progress.title, isNotEmpty);
    });
  });

  test('carries the dashboard\'s next lesson for the check-in node '
      '(Issue #202)', () async {
    final lesson = NextLesson(
      startsAt: DateTime(2026, 10, 6, 9),
      endsAt: DateTime(2026, 10, 6, 11),
    );
    final map = await repositoryFor(
      dashboard: HomeDashboard(program: sampleProgram(nextLesson: lesson)),
    ).getLearningMap();

    expect(map?.nextLesson, same(lesson));
  });

  test('each node carries its module\'s id and title — what a tap opens '
      '(Issue #204)', () {
    final path = samplePath(courseSlug: 'junior');
    final modules = path.modules.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final map = juniorMapFrom(path);

    expect([for (final n in map.nodes) n.id], [for (final m in modules) m.id]);
    expect(
      [for (final n in map.nodes) n.title],
      [for (final m in modules) m.title],
    );
  });
}
