import 'package:aia_mobile/features/teacher/domain/teacher_submission.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Бүгд keeps every status', () {
    for (final status in ['submitted', 'reviewed', 'draft']) {
      expect(matchesFilter(status, GradebookFilter.all), isTrue);
    }
  });

  test('Хүлээгдэж буй is exactly "submitted"', () {
    expect(matchesFilter('submitted', GradebookFilter.pending), isTrue);
    expect(matchesFilter('reviewed', GradebookFilter.pending), isFalse);
    expect(matchesFilter('draft', GradebookFilter.pending), isFalse);
  });

  test('Дүгнэгдсэн is exactly "reviewed"', () {
    expect(matchesFilter('reviewed', GradebookFilter.graded), isTrue);
    expect(matchesFilter('submitted', GradebookFilter.graded), isFalse);
    expect(matchesFilter('draft', GradebookFilter.graded), isFalse);
  });

  test('a score reads without a trailing .0', () {
    expect(TeacherGradebookStrings.score(85), 'Оноо: 85');
    expect(TeacherGradebookStrings.score(85.0), 'Оноо: 85');
    expect(TeacherGradebookStrings.score(85.5), 'Оноо: 85.5');
  });
}
