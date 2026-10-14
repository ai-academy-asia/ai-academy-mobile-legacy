import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';
import 'package:flutter_test/flutter_test.dart';

/// Completion, the check-in node and when check-in is actionable (Issues
/// #202, #410). One node per lesson.
void main() {
  JuniorLearningMap mapOf(
    List<JuniorNodeState> states, {
    int? continueLessonId,
    NextLesson? nextLesson,
    bool? attendanceRecorded,
  }) => JuniorLearningMap(
    progress: const JuniorCourseProgress(title: 'C', percentComplete: 0),
    nodes: [
      for (final (i, state) in states.indexed)
        JuniorMapNode(id: i + 1, state: state),
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

  const done = JuniorNodeState.completed;
  const open = JuniorNodeState.current;
  const locked = JuniorNodeState.locked;

  test('complete only when every lesson is completed', () {
    expect(mapOf([done, done, done]).isComplete, isTrue);
    expect(mapOf([done, open, locked]).isComplete, isFalse);
    expect(mapOf([done, done, locked]).isComplete, isFalse);
    expect(mapOf(const []).isComplete, isFalse);
  });

  group('check-in node', () {
    test('the server\'s continue lesson when it is open', () {
      expect(mapOf([done, open, open], continueLessonId: 3).checkInNode?.id, 3);
    });

    test('otherwise the first open lesson', () {
      expect(mapOf([done, open, open]).checkInNode?.id, 2);
      // A continue lesson that is not open does not count.
      expect(
        mapOf([done, open, locked], continueLessonId: 1).checkInNode?.id,
        2,
      );
      expect(
        mapOf([done, open, locked], continueLessonId: 3).checkInNode?.id,
        2,
      );
    });

    test('none for a completed program or one with nothing open', () {
      expect(mapOf([done, done]).checkInNode, isNull);
      expect(mapOf([locked, locked]).checkInNode, isNull);
    });

    test('marks a lesson, it never changes one: every node keeps the state '
        'the server gave it', () {
      final map = mapOf([done, open, open, locked], continueLessonId: 3);
      expect(map.checkInNode?.id, 3);
      expect([for (final n in map.nodes) n.state], [done, open, open, locked]);
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
        [done, open, locked],
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
          [done, open],
          nextLesson: lesson,
          attendanceRecorded: true,
        ).checkInOpenAt(during),
        isFalse,
      );
    });

    test('unknown attendance keeps check-in closed — never offered while it '
        'may already be recorded', () {
      expect(
        mapOf([done, open], nextLesson: lesson).checkInOpenAt(during),
        isFalse,
      );
      expect(
        mapOf(
          [done, open],
          nextLesson: lesson,
          attendanceRecorded: false,
        ).checkInOpenAt(during),
        isTrue,
      );
    });

    test('never without a lesson or without a check-in node', () {
      expect(mapOf([done, open]).checkInOpenAt(during), isFalse);
      expect(
        mapOf([done, done], nextLesson: lesson).checkInOpenAt(during),
        isFalse,
      );
    });
  });
}
