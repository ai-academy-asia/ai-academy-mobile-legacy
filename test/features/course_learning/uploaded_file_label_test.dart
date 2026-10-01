import 'package:aia_mobile/features/course_learning/domain/file_size_label.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fileSizeLabel', () {
    test('binary units, one decimal only below 10 of a unit', () {
      expect(fileSizeLabel(0), '0 B');
      expect(fileSizeLabel(1023), '1023 B');
      expect(fileSizeLabel(1024), '1 KB');
      expect(fileSizeLabel(1572864), '1.5 MB');
      expect(fileSizeLabel(10485760), '10 MB');
      expect(fileSizeLabel(12 * 1024 * 1024 + 300000), '12 MB');
    });
  });

  group('CourseLearningStrings.uploadedFileLabel', () {
    test('adds the extension, upper-cased, as the type', () {
      expect(
        CourseLearningStrings.uploadedFileLabel('1 MB', 'report.pdf'),
        '1 MB, PDF',
      );
      expect(
        CourseLearningStrings.uploadedFileLabel('4 KB', 'model.v2.ipynb'),
        '4 KB, IPYNB',
      );
    });

    test('a name with no extension shows the size alone', () {
      expect(CourseLearningStrings.uploadedFileLabel('1 MB', 'notes'), '1 MB');
      expect(CourseLearningStrings.uploadedFileLabel('1 MB', '.env'), '1 MB');
      expect(CourseLearningStrings.uploadedFileLabel('1 MB', 'notes.'), '1 MB');
    });
  });
}
