import 'package:aia_mobile/features/certificates/domain/certificate_entry.dart';
import 'package:aia_mobile/features/certificates/domain/certificate_list_repository.dart';
import 'package:aia_mobile/features/certificates/presentation/certificate_screen.dart';
import 'package:aia_mobile/features/certificates/presentation/certificate_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/back_button_header.dart';
import '../../support/screenshot.dart';
import '../course_learning/fake_course_learning_repository.dart';

/// The Certificate header's back button stays reachable at every width and
/// text size (Issue #325). Before the fix the centred title lay over the
/// button and took its taps: the right edge at 320 wide and 2.5×, all of it
/// at 3.0×; the right edge at 393 wide and 3.0×.
void main() {
  setUpAll(loadAppFonts);

  backButtonHeaderChecks(
    title: CertificateStrings.title,
    // The real screen, with nothing to list — the header is the subject.
    screen: () => CertificateScreen(
      repository: _NoCertificates(),
      courseLearning: FakeCourseLearningRepository(),
    ),
  );
}

class _NoCertificates implements CertificateListRepository {
  @override
  Future<List<CertificateEntry>> getCertificates() async => const [];
}
