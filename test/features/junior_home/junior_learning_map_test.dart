import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';
import 'package:flutter_test/flutter_test.dart';

/// Completion, the check-in node and when check-in is actionable (Issues
/// #202, #410, #417). One node per lesson, in exactly four states.
void main() {
  /// A node's stored state and the server's lock on it.
  JuniorLearningMap mapOf(
    List<(JuniorNodeState, bool)> nodes, {
    int? continueLessonId,
    NextLesson? nextLesson,
    bool? attendanceRecorded,
  }) => JuniorLearningMap(
    progress: const JuniorCourseProgress(title: 'C', percentComplete: 0),
    nodes: [
      for (final (i, (state, locked)) in nodes.indexed)
        JuniorMapNode(id: i + 1, state: state, locked: locked),
    ],
    certificate: const JuniorCertificate(
      track: 'Junior',
      courseName: 'C',
      description: 'D',
    ),
    continueLessonId: continueLessonId,
    nextLesson: nextLesson,
    attendanceRecorded: attendanceRecorded,
  );

  // LESSON_COMPLETED; LOCKED with its class date come (the server leaves
  // it unlocked); LOCKED by the server.
  const done = (JuniorNodeState.completed, false);
  const waiting = (JuniorNodeState.locked, false);
  const locked = (JuniorNodeState.locked, true);

  test('complete only when every lesson is completed', () {
    expect(mapOf([done, done, done]).isComplete, isTrue);
    expect(mapOf([done, waiting, locked]).isComplete, isFalse);
    expect(mapOf([done, done, locked]).isComplete, isFalse);
    expect(mapOf(const []).isComplete, isFalse);
  });

  group('check-in node (the interim association, #202)', () {
    test('the server\'s continue lesson while it is LOCKED and the server '
        'leaves it unlocked', () {
      expect(
        mapOf([done, waiting, waiting], continueLessonId: 3).checkInNode?.id,
        3,
      );
    });

    test('exactly the server\'s — no fallback guessed', () {
      expect(mapOf([done, waiting, waiting]).checkInNode, isNull);
      // A completed continue lesson, or one the server locks, has none.
      expect(
        mapOf([done, waiting, locked], continueLessonId: 1).checkInNode,
        isNull,
      );
      expect(
        mapOf([done, waiting, locked], continueLessonId: 3).checkInNode,
        isNull,
      );
    });

    test('marks a lesson, never changes one: every node keeps its state', () {
      final map = mapOf([done, waiting, waiting, locked], continueLessonId: 3);
      expect(map.checkInNode?.id, 3);
      expect(
        [for (final n in map.nodes) n.state],
        [
          JuniorNodeState.completed,
          JuniorNodeState.locked,
          JuniorNodeState.locked,
          JuniorNodeState.locked,
        ],
      );
    });
  });

  group('check-in open', () {
    final lesson = NextLesson(
      startsAt: DateTime(2026, 10, 6, 9),
      endsAt: DateTime(2026, 10, 6, 11),
    );
    final during = DateTime(2026, 10, 6, 10);

    test('only while the lesson is under way — Adult Home\'s rule', () {
      final map = mapOf(
        [done, waiting, locked],
        continueLessonId: 2,
        nextLesson: lesson,
        attendanceRecorded: false,
      );
      expect(map.checkInOpenAt(DateTime(2026, 10, 6, 8, 59)), isFalse);
      expect(map.checkInOpenAt(DateTime(2026, 10, 6, 9)), isTrue);
      expect(map.checkInOpenAt(DateTime(2026, 10, 6, 10, 59)), isTrue);
      expect(map.checkInOpenAt(DateTime(2026, 10, 6, 11)), isFalse);
      // Another day entirely.
      expect(map.checkInOpenAt(DateTime(2026, 10, 7, 10)), isFalse);
    });

    test('never once attendance is recorded for the day (Issue #410)', () {
      expect(
        mapOf(
          [done, waiting],
          continueLessonId: 2,
          nextLesson: lesson,
          attendanceRecorded: true,
        ).checkInOpenAt(during),
        isFalse,
      );
    });

    test('unknown attendance keeps check-in closed — never offered while it '
        'may already be recorded', () {
      expect(
        mapOf(
          [done, waiting],
          continueLessonId: 2,
          nextLesson: lesson,
        ).checkInOpenAt(during),
        isFalse,
      );
      expect(
        mapOf(
          [done, waiting],
          continueLessonId: 2,
          nextLesson: lesson,
          attendanceRecorded: false,
        ).checkInOpenAt(during),
        isTrue,
      );
    });

    test('never without a lesson or without a check-in node', () {
      expect(
        mapOf([done, waiting], continueLessonId: 2).checkInOpenAt(during),
        isFalse,
      );
      expect(
        mapOf([done, done], nextLesson: lesson).checkInOpenAt(during),
        isFalse,
      );
    });
  });

  group('the look each node is drawn with (Issue #417)', () {
    final lesson = NextLesson(
      startsAt: DateTime(2026, 10, 6, 9),
      endsAt: DateTime(2026, 10, 6, 11),
    );
    final map = mapOf(
      [done, (JuniorNodeState.attendanceCompleted, false), waiting, locked],
      continueLessonId: 3,
      nextLesson: lesson,
      attendanceRecorded: false,
    );

    test('during the class: the check-in node is CHECK_IN_REQUIRED; the '
        'rest keep their own state', () {
      final during = DateTime(2026, 10, 6, 10);
      expect(
        [for (final n in map.nodes) map.displayStateOf(n, during)],
        [
          JuniorNodeState.completed,
          JuniorNodeState.attendanceCompleted,
          JuniorNodeState.checkInRequired,
          JuniorNodeState.locked,
        ],
      );
    });

    test('outside it: the check-in node is LOCKED — no fifth state', () {
      final after = DateTime(2026, 10, 6, 12);
      expect(
        [for (final n in map.nodes) map.displayStateOf(n, after)],
        [
          JuniorNodeState.completed,
          JuniorNodeState.attendanceCompleted,
          JuniorNodeState.locked,
          JuniorNodeState.locked,
        ],
      );
    });

    test('only LESSON_COMPLETED and ATTENDANCE_COMPLETED open a lesson', () {
      expect([for (final n in map.nodes) n.opens], [true, true, false, false]);
    });
  });
}
