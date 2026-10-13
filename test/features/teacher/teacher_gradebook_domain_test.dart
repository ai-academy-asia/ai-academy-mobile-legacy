import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_teacher_gradebook_repository.dart';

/// Teacher Programs' pure rules (Issue #390).
void main() {
  test('pending is exactly "submitted"; reviewed is exactly "reviewed"', () {
    expect(sampleSubmission(status: 'submitted').isPending, isTrue);
    expect(sampleSubmission(status: 'reviewed').isPending, isFalse);
    expect(sampleSubmission(status: 'draft').isPending, isFalse);
    expect(sampleSubmission(status: 'reviewed').isReviewed, isTrue);
  });

  test('timestamps: "Today, HH:mm" on the same day, "MM/dd, HH:mm" else', () {
    final now = DateTime(2026, 10, 13, 20);
    expect(
      TeacherGradebookStrings.timestamp(
        DateTime(2026, 10, 13, 14, 20),
        now: now,
      ),
      'Today, 14:20',
    );
    expect(
      TeacherGradebookStrings.timestamp(DateTime(2026, 8, 6, 9, 5), now: now),
      '08/06, 09:05',
    );
  });

  test('the score field names its range without a trailing .0', () {
    expect(TeacherGradebookStrings.scoreLabel(100), 'Оноо (0–100)');
    expect(TeacherGradebookStrings.scoreLabel(7.5), 'Оноо (0–7.5)');
  });

  test('a refused reply names the backend\'s reason; anything else falls '
      'back to the failure kind', () {
    String message(
      String? code, [
      TeacherFailureKind kind = TeacherFailureKind.rejected,
    ]) => TeacherGradebookStrings.replyFailed(TeacherFailure(kind, code: code));
    expect(message('feedback_required'), 'Хариултаа бичнэ үү.');
    expect(
      message('feedback_too_long'),
      'Хариулт 5000 тэмдэгтээс хэтэрсэн байна.',
    );
    expect(message('invalid_score'), 'Оноо буруу байна.');
    expect(message('submission_not_found'), 'Энэ илгээлт олдсонгүй.');
    expect(
      message(null, TeacherFailureKind.network),
      TeacherHomeStrings.messageFor(TeacherFailureKind.network),
    );
  });

  test('the announcement composer\'s limit and counter', () {
    expect(TeacherGradebookStrings.announceMaxLength, 100);
    expect(TeacherGradebookStrings.counter(0, 100), '0/100');
  });
}
