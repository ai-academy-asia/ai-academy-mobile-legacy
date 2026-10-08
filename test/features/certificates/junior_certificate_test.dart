import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/certificates/domain/certificate_entry.dart';
import 'package:aia_mobile/features/certificates/domain/certificate_list_repository.dart';
import 'package:aia_mobile/features/certificates/presentation/certificate_screen.dart';
import 'package:aia_mobile/features/certificates/presentation/certificate_strings.dart';
import 'package:aia_mobile/features/course_learning/domain/course_certificate.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/junior_home/data/api_junior_home_repository.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_profile_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_profile_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../course_learning/fake_course_learning_repository.dart';
import '../profile/fake_current_user_repository.dart';

/// A Junior student's issued certificate. Test values only.
final _juniorIssued = CertificateEntry(
  cohortId: 11,
  cohortName: 'Test Junior Cohort',
  courseTitle: 'Test Junior Course',
  courseSlug: 'test-junior-course',
  certificate: CourseCertificate(
    status: CertificateStatus.issued,
    issued: IssuedCertificate(
      certNumber: 'TEST-J-0001',
      issuedAt: DateTime(2026, 5, 2, 9),
    ),
  ),
);

/// A Junior student's course not yet certified. Test values only.
const _juniorPending = CertificateEntry(
  cohortId: 12,
  cohortName: 'Test Junior Cohort 2',
  courseTitle: 'Test Junior Course 2',
  courseSlug: 'test-junior-course-2',
  certificate: CourseCertificate(status: CertificateStatus.notEligible),
  progressPercent: 60,
);

/// Certificate for a Junior student (Issue #155): the Junior Profile's
/// Certificate row opens the same Certificate screen on the same student
/// endpoints, and its "Continue learning" opens the course screen Junior
/// Home's own course card opens.
void main() {
  setUpAll(loadAppFonts);

  late FakeCourseLearningRepository learning;

  setUp(() => learning = FakeCourseLearningRepository());

  Future<void> openFromJuniorProfile(
    WidgetTester tester,
    List<CertificateEntry> entries,
  ) async {
    useLogicalViewport(tester, const Size(393, 1400), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: JuniorProfileScreen(
          repository: FakeCurrentUserRepository(),
          certificateRepository: _Entries(entries),
          courseLearningRepository: learning,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(JuniorProfileStrings.certificate));
    await tester.tap(find.text(JuniorProfileStrings.certificate));
    await tester.pumpAndSettle();
  }

  testWidgets('the Junior Profile\'s Certificate row opens the Certificate '
      'screen, and back returns to the Junior Profile', (tester) async {
    await openFromJuniorProfile(tester, [_juniorIssued]);

    expect(find.byType(CertificateScreen), findsOneWidget);
    expect(find.text(CertificateStrings.title), findsOneWidget);

    Navigator.of(tester.element(find.byType(CertificateScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(CertificateScreen), findsNothing);
    expect(find.byType(JuniorProfileScreen), findsOneWidget);
  });

  testWidgets('issued: the Junior course, its date and Download — which asks '
      'for that certificate\'s link', (tester) async {
    await openFromJuniorProfile(tester, [_juniorIssued]);

    expect(find.text('Test Junior Cohort'), findsOneWidget);
    expect(find.text('Test Junior Course'), findsOneWidget);
    expect(find.text('2026/05/02'), findsOneWidget);
    expect(find.text(CertificateStrings.download), findsOneWidget);
    expect(find.text(CourseLearningStrings.continueLearning), findsNothing);

    // The link is requested for the Junior certificate's own number. What
    // opening it does is covered with an injected opener in
    // certificate_screen_test.dart; here the real `url_launcher` has no
    // platform behind it, so only the request is checked.
    await tester.tap(find.bySemanticsLabel(CertificateStrings.download));
    await tester.pump();
    await tester.pump();
    expect(learning.certificateDownloadCalls, ['TEST-J-0001']);
  });

  testWidgets('not yet issued: progress, and Continue learning opens the '
      'course screen Junior Home\'s course card opens', (tester) async {
    await openFromJuniorProfile(tester, [_juniorPending]);

    expect(find.text('Test Junior Course 2'), findsOneWidget);
    expect(find.text(CourseLearningStrings.percentComplete(60)), findsOne);
    expect(find.text(CertificateStrings.download), findsNothing);

    await tester.tap(find.text(CourseLearningStrings.continueLearning));
    await tester.pumpAndSettle();

    final screen = tester.widget<CourseModuleListScreen>(
      find.byType(CourseModuleListScreen),
    );
    expect(screen.courseSlug, 'test-junior-course-2');
    expect(learning.calls, ['test-junior-course-2']);

    Navigator.of(tester.element(find.byType(CourseModuleListScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(CertificateScreen), findsOneWidget);
  });

  group('Junior map and Certificate read the same status', () {
    // Junior Home reads `certificate.status` off the learning path; the
    // Certificate screen reads §2.9's `status`. Same contract values, so a
    // Junior student never sees the map and the screen disagree.
    for (final (wire, map, screen) in [
      (
        'not_eligible',
        JuniorCertificateStatus.notEligible,
        CertificateStatus.notEligible,
      ),
      (
        'eligible',
        JuniorCertificateStatus.eligible,
        CertificateStatus.eligible,
      ),
      ('issued', JuniorCertificateStatus.issued, CertificateStatus.issued),
    ]) {
      test(wire, () {
        final junior = juniorMapFrom(samplePath(certificateStatus: wire));

        expect(junior.certificate.status, map);
        expect(CertificateStatus.fromApi(wire), screen);
        expect(map.name, screen.name);
      });
    }

    test('neither reads an unknown status as issued', () {
      final junior = juniorMapFrom(samplePath(certificateStatus: 'revoked'));

      expect(junior.certificate.status, isNull);
      expect(CertificateStatus.fromApi('revoked'), CertificateStatus.unknown);
    });
  });
}

class _Entries implements CertificateListRepository {
  _Entries(this.entries);

  final List<CertificateEntry> entries;

  @override
  Future<List<CertificateEntry>> getCertificates() async => entries;
}
