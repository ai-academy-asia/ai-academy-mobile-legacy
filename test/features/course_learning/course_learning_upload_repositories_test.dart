import 'package:aia_mobile/features/course_learning/data/sample_course_learning_repository.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_course_learning_repository.dart';

/// `uploadFile` on the two non-HTTP repositories — the sample the dev preview
/// runs on and the fake the controller/screen tests drive. The HTTP one is
/// covered against the wire in `http_course_learning_repository_test.dart`.
void main() {
  const bytes = <int>[1, 2, 3, 4];

  group('SampleCourseLearningRepository.uploadFile', () {
    test('uploads nothing: fails rather than invent a stored file', () async {
      final repository = SampleCourseLearningRepository();

      await expectLater(
        repository.uploadFile(fileName: 'report.pdf', bytes: bytes),
        throwsA(
          isA<CourseLearningFailure>().having(
            (failure) => failure.kind,
            'kind',
            CourseLearningFailureKind.unexpected,
          ),
        ),
      );
    });
  });

  group('FakeCourseLearningRepository.uploadFile', () {
    test('records each call and answers with a file named after it', () async {
      final repository = FakeCourseLearningRepository();

      final file = await repository.uploadFile(
        fileName: 'slides.pptx',
        bytes: bytes,
      );

      expect(repository.uploadCalls, hasLength(1));
      expect(repository.uploadCalls.single.$1, 'slides.pptx');
      expect(repository.uploadCalls.single.$2, bytes);
      expect(file.fileName, 'slides.pptx');
      expect(file.sizeBytes, bytes.length);
    });

    test('answers with a configured file', () async {
      final configured = sampleUploadedFile(id: 5);
      final repository = FakeCourseLearningRepository(uploadedFile: configured);

      final file = await repository.uploadFile(fileName: 'a.pdf', bytes: bytes);

      expect(file, same(configured));
    });

    test('throws a configured failure, after a hold releases', () async {
      final repository = FakeCourseLearningRepository(
        holdUpload: true,
        uploadFailure: const CourseLearningFailure(
          CourseLearningFailureKind.fileTooLarge,
        ),
      );

      var settled = false;
      final pending = expectLater(
        repository
            .uploadFile(fileName: 'a.zip', bytes: bytes)
            .whenComplete(() => settled = true),
        throwsA(
          isA<CourseLearningFailure>().having(
            (failure) => failure.kind,
            'kind',
            CourseLearningFailureKind.fileTooLarge,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(repository.uploadCalls, hasLength(1));
      expect(settled, isFalse);

      repository.releaseUpload();
      await pending;
      expect(settled, isTrue);
    });
  });
}
