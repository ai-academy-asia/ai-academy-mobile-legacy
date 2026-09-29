import 'dart:async';

import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/junior_home/data/sample_junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_home_repository.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';

/// A Junior Home repository the tests drive by hand.
///
/// Same `hold`/`release` shape as `FakeCourseLearningRepository`, so a
/// controller test can observe the brief `loading` state before the future
/// resolves, and the same `failure` field so the error branch can be driven
/// without a `MockClient`.
class FakeJuniorHomeRepository implements JuniorHomeRepository {
  FakeJuniorHomeRepository({
    JuniorLearningMap? map,
    this.hold = false,
    this.failure,
    this.empty = false,
  }) : map = map ?? sampleJuniorLearningMap();

  /// Returned on success. Defaults to the Figma sample, which is what the
  /// screenshot test wants so its golden does not move.
  JuniorLearningMap map;

  /// When true, [getLearningMap] answers null — the student is enrolled in
  /// nothing.
  bool empty;

  /// When true, [getLearningMap] blocks until [release] is called.
  bool hold;

  /// Thrown instead of returning, to drive the controller's error state.
  CourseLearningFailure? failure;

  /// How many times [getLearningMap] has been called.
  int calls = 0;

  Completer<void>? _gate;

  void release() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<JuniorLearningMap?> getLearningMap() async {
    calls++;

    if (hold) {
      _gate = Completer<void>();
      await _gate!.future;
    }

    if (failure case final failure?) throw failure;

    return empty ? null : map;
  }
}
