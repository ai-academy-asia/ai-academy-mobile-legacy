import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/certificates/domain/certificate_entry.dart';
import 'package:aia_mobile/features/certificates/domain/certificate_list_repository.dart';
import 'package:aia_mobile/features/certificates/presentation/certificate_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../course_learning/fake_course_learning_repository.dart';
import 'certificate_screen_test.dart' show issuedEntry, pendingEntry;

/// A deterministic capture of the Certificate screen — an issued card over a
/// not-yet-issued one, as the Figma "Certificate" frame draws them (Issue
/// #155) — at the frame's own 393 x 960, for comparing against its PNG
/// (1179 x 2880, 3x). The cards carry test values, not the frame's.
///
/// Run `flutter test --update-goldens <this file>` to refresh, then compare
/// `test/goldens/certificate.png` against the reference.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('Certificate at the reference frame', (tester) async {
    useLogicalViewport(tester, const Size(393, 960), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: CertificateScreen(
          repository: _Both(),
          courseLearning: FakeCourseLearningRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/certificate.png'),
    );
  });
}

class _Both implements CertificateListRepository {
  @override
  Future<List<CertificateEntry>> getCertificates() async => [
    issuedEntry,
    pendingEntry,
  ];
}
