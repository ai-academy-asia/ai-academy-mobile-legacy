import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';
import 'package:flutter_test/flutter_test.dart';

/// Completion and the check-in node (Issue #202).
void main() {
  JuniorLearningMap mapOf(
    List<JuniorNodeState> states, {
    int? continueModuleId,
    NextLesson? nextLesson,
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
    continueModuleId: continueModuleId,
    nextLesson: nextLesson,
  );

  const done = JuniorNodeState.completed;
  const open = JuniorNodeState.current;
  const locked = JuniorNodeState.locked;

  test('complete only when every module is completed', () {
    expect(mapOf([done, done, done]).isComplete, isTrue);
    expect(mapOf([done, open, locked]).isComplete, isFalse);
    expect(mapOf([done, done, locked]).isComplete, isFalse);
    expect(mapOf(const []).isComplete, isFalse);
  });

  group('check-in node', () {
    test('the server\'s continue module when it is current', () {
      expect(mapOf([done, open, open], continueModuleId: 3).checkInNode?.id, 3);
    });

    test('otherwise the first current module', () {
      expect(mapOf([done, open, open]).checkInNode?.id, 2);
      // A continue module that is not current does not count.
      expect(
        mapOf([done, open, locked], continueModuleId: 1).checkInNode?.id,
        2,
      );
    });

    test('none for a completed program or one with nothing open', () {
      expect(mapOf([done, done]).checkInNode, isNull);
      expect(mapOf([locked, locked]).checkInNode, isNull);
    });
  });

  group('check-in open', () {
    final lesson = NextLesson(
      startsAt: DateTime(2026, 10, 6, 9),
      endsAt: DateTime(2026, 10, 6, 11),
    );

    test('only while the lesson is under way — Adult Home\'s rule', () {
      final map = mapOf([done, open, locked], nextLesson: lesson);
      expect(map.checkInOpenAt(DateTime(2026, 10, 6, 8, 59)), isFalse);
      expect(map.checkInOpenAt(DateTime(2026, 10, 6, 9)), isTrue);
      expect(map.checkInOpenAt(DateTime(2026, 10, 6, 10, 59)), isTrue);
      expect(map.checkInOpenAt(DateTime(2026, 10, 6, 11)), isFalse);
    });

    test('never without a lesson or without a check-in node', () {
      expect(
        mapOf([done, open]).checkInOpenAt(DateTime(2026, 10, 6, 10)),
        isFalse,
      );
      expect(
        mapOf([
          done,
          done,
        ], nextLesson: lesson).checkInOpenAt(DateTime(2026, 10, 6, 10)),
        isFalse,
      );
    });
  });
}
