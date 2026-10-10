import 'dart:async';

import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/certificates/domain/certificate_entry.dart';
import 'package:aia_mobile/features/certificates/domain/certificate_list_repository.dart';
import 'package:aia_mobile/features/certificates/presentation/certificate_screen.dart';
import 'package:aia_mobile/features/certificates/presentation/certificate_strings.dart';
import 'package:aia_mobile/features/course_learning/domain/course_certificate.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/certificate_preview.dart';
import 'package:aia_mobile/features/profile/presentation/profile_screen.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../course_learning/fake_course_learning_repository.dart';
import '../profile/fake_current_user_repository.dart';

/// An issued certificate's card. Test values only.
final issuedEntry = CertificateEntry(
  cohortId: 1,
  cohortName: 'Test Cohort A',
  courseTitle: 'Test Course One',
  courseSlug: 'test-course-one',
  certificate: CourseCertificate(
    status: CertificateStatus.issued,
    issued: IssuedCertificate(
      certNumber: 'TEST-0001',
      issuedAt: DateTime(2026, 3, 9, 10),
    ),
  ),
);

/// A card not yet issued. Test values only.
const pendingEntry = CertificateEntry(
  cohortId: 2,
  cohortName: 'Test Cohort B',
  courseTitle: 'Test Course Two',
  courseSlug: 'test-course-two',
  certificate: CourseCertificate(status: CertificateStatus.notEligible),
  progressPercent: 45,
);

/// The Certificate screen (Issue #155): the frame's issued and not-yet
/// states from the server's status, Download through a fresh pre-signed
/// link, and Continue learning into the course.
void main() {
  setUpAll(loadAppFonts);

  late FakeCourseLearningRepository learning;
  late List<Uri> opened;
  late bool openSucceeds;

  setUp(() {
    learning = FakeCourseLearningRepository();
    opened = [];
    openSucceeds = true;
  });

  Future<void> pump(
    WidgetTester tester,
    CertificateListRepository repository,
  ) async {
    useLogicalViewport(tester, const Size(393, 960), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CertificateScreen(
          repository: repository,
          courseLearning: learning,
          openUrl: (url) async {
            opened.add(url);
            return openSucceeds;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder downloadButton() => find.bySemanticsLabel(CertificateStrings.download);

  group('the frame\'s two states, from the server\'s status', () {
    testWidgets('issued: the cohort, course, completed date and Download', (
      tester,
    ) async {
      await pump(tester, _Repo([issuedEntry]));

      expect(find.text(CertificateStrings.title), findsOneWidget);
      expect(find.byType(CertificatePreview), findsOneWidget);
      expect(find.text('Test Cohort A'), findsOneWidget);
      expect(find.text('Test Course One'), findsOneWidget);
      expect(find.text(CertificateStrings.completedDate), findsOneWidget);
      expect(find.text('2026/03/09'), findsOneWidget);
      expect(find.text(CertificateStrings.download), findsOneWidget);
      expect(find.text(CourseLearningStrings.continueLearning), findsNothing);
    });

    testWidgets('not yet issued: progress and Continue learning, no date or '
        'Download', (tester) async {
      await pump(tester, _Repo([pendingEntry]));

      expect(find.text('Test Cohort B'), findsOneWidget);
      expect(find.text('Test Course Two'), findsOneWidget);
      expect(find.text(CourseLearningStrings.percentComplete(45)), findsOne);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.45);
      expect(find.text(CourseLearningStrings.continueLearning), findsOneWidget);
      expect(find.text(CertificateStrings.completedDate), findsNothing);
      expect(find.text(CertificateStrings.download), findsNothing);
    });

    testWidgets('eligible and an unknown status are not drawn as issued', (
      tester,
    ) async {
      for (final status in [
        CertificateStatus.eligible,
        CertificateStatus.unknown,
      ]) {
        await pump(
          tester,
          _Repo([
            CertificateEntry(
              cohortId: 3,
              cohortName: 'C',
              courseTitle: 'T',
              courseSlug: 's',
              certificate: CourseCertificate(status: status),
              progressPercent: 100,
            ),
          ]),
        );

        expect(find.text(CertificateStrings.download), findsNothing);
        expect(
          find.text(CourseLearningStrings.continueLearning),
          findsOneWidget,
          reason: '$status',
        );
      }
    });

    // Real-device report (PR #245): a Junior course at 100% drew Continue
    // learning. The state is the server's `status`, never the percentage:
    // 100% with `issued` is the issued card; 100% with anything else stays
    // the not-yet card.
    testWidgets('issued at 100% is the issued card — Download, no Continue '
        'learning', (tester) async {
      await pump(
        tester,
        _Repo([
          CertificateEntry(
            cohortId: 6,
            cohortName: 'C',
            courseTitle: 'T',
            courseSlug: 's',
            certificate: CourseCertificate(
              status: CertificateStatus.issued,
              issued: IssuedCertificate(
                certNumber: 'TEST-6',
                issuedAt: DateTime(2026, 4, 1, 12),
              ),
            ),
            progressPercent: 100,
          ),
        ]),
      );

      expect(find.text(CertificateStrings.completedDate), findsOneWidget);
      expect(find.text('2026/04/01'), findsOneWidget);
      expect(find.text(CertificateStrings.download), findsOneWidget);
      expect(find.text(CourseLearningStrings.continueLearning), findsNothing);
      expect(find.textContaining('% complete'), findsNothing);
    });

    testWidgets('100% but not issued stays the not-yet card — no Download is '
        'inferred from progress', (tester) async {
      await pump(
        tester,
        _Repo([
          const CertificateEntry(
            cohortId: 7,
            cohortName: 'C',
            courseTitle: 'T',
            courseSlug: 's',
            certificate: CourseCertificate(status: CertificateStatus.eligible),
            progressPercent: 100,
          ),
        ]),
      );

      expect(find.text(CourseLearningStrings.percentComplete(100)), findsOne);
      expect(find.text(CourseLearningStrings.continueLearning), findsOneWidget);
      expect(find.text(CertificateStrings.download), findsNothing);
    });

    testWidgets('no progress figure draws no bar, and keeps the button', (
      tester,
    ) async {
      await pump(
        tester,
        _Repo([
          CertificateEntry(
            cohortId: 4,
            cohortName: 'C',
            courseTitle: 'T',
            courseSlug: 's',
            certificate: CourseCertificate(
              status: CertificateStatus.notEligible,
            ),
          ),
        ]),
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('% complete'), findsNothing);
      expect(find.text(CourseLearningStrings.continueLearning), findsOneWidget);
    });

    testWidgets('an issued certificate with no date draws no date row', (
      tester,
    ) async {
      await pump(
        tester,
        _Repo([
          CertificateEntry(
            cohortId: 5,
            cohortName: 'C',
            courseTitle: 'T',
            courseSlug: 's',
            certificate: CourseCertificate(
              status: CertificateStatus.issued,
              issued: IssuedCertificate(certNumber: 'TEST-5'),
            ),
          ),
        ]),
      );

      expect(find.text(CertificateStrings.completedDate), findsNothing);
      expect(find.text(CertificateStrings.download), findsOneWidget);
    });

    testWidgets('one card per course, both states together', (tester) async {
      await pump(tester, _Repo([issuedEntry, pendingEntry]));

      expect(find.byType(CertificatePreview), findsNWidgets(2));
      expect(find.text(CertificateStrings.download), findsOneWidget);
      expect(find.text(CourseLearningStrings.continueLearning), findsOneWidget);
    });
  });

  group('download', () {
    testWidgets('fetches a fresh link for the certificate and opens it', (
      tester,
    ) async {
      await pump(tester, _Repo([issuedEntry]));

      await tester.tap(downloadButton());
      await tester.pumpAndSettle();

      expect(learning.certificateDownloadCalls, ['TEST-0001']);
      expect(opened, [
        Uri.parse('https://files.example.test/cert/TEST-0001.pdf'),
      ]);
      expect(find.byType(SnackBar), findsNothing);
    });

    group('unavailable (Issue #296)', () {
      CertificateEntry issued({String? certNumber, bool? hasFile}) =>
          CertificateEntry(
            cohortId: 9,
            cohortName: 'C',
            courseTitle: 'T',
            courseSlug: 's',
            certificate: CourseCertificate(
              status: CertificateStatus.issued,
              issued: certNumber == null
                  ? null
                  : IssuedCertificate(certNumber: certNumber),
              hasFile: hasFile,
            ),
          );

      Color labelColour(WidgetTester tester) => tester
          .widget<Text>(find.text(CertificateStrings.download))
          .style!
          .color!;

      for (final (name, entry) in [
        ('has_file: false', issued(certNumber: 'TEST-9', hasFile: false)),
        ('no cert_number', issued()),
      ]) {
        testWidgets('$name: Download is drawn disabled and asks for nothing', (
          tester,
        ) async {
          await pump(tester, _Repo([entry]));

          expect(labelColour(tester), AppPalette.light.disabledInk);
          expect(
            tester.getSemantics(downloadButton()),
            matchesSemantics(isButton: true, hasEnabledState: true),
          );

          await tester.tap(downloadButton(), warnIfMissed: false);
          await tester.pumpAndSettle();

          expect(learning.certificateDownloadCalls, isEmpty);
          expect(opened, isEmpty);
          expect(find.byType(SnackBar), findsNothing);
        });
      }

      testWidgets('has_file: true stays available', (tester) async {
        await pump(
          tester,
          _Repo([issued(certNumber: 'TEST-0001', hasFile: true)]),
        );

        expect(labelColour(tester), AppPalette.light.textPrimary);
        await tester.tap(downloadButton());
        await tester.pumpAndSettle();

        expect(learning.certificateDownloadCalls, ['TEST-0001']);
      });
    });

    testWidgets('is busy while the link is fetched, and a second tap does '
        'nothing', (tester) async {
      learning.holdCertificateDownload = true;
      await pump(tester, _Repo([issuedEntry]));

      await tester.tap(downloadButton());
      await tester.pump();
      expect(
        find.descendant(
          of: downloadButton(),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      await tester.tap(downloadButton(), warnIfMissed: false);
      await tester.pump();

      learning.releaseCertificateDownload();
      await tester.pumpAndSettle();
      expect(learning.certificateDownloadCalls, ['TEST-0001']);
      expect(opened, hasLength(1));
      expect(find.text(CertificateStrings.download), findsOneWidget);
    });

    testWidgets('a failed request opens nothing and says why', (tester) async {
      learning.certificateDownloadFailure = const CourseLearningFailure(
        CourseLearningFailureKind.network,
      );
      await pump(tester, _Repo([issuedEntry]));

      await tester.tap(downloadButton());
      await tester.pumpAndSettle();

      expect(opened, isEmpty);
      expect(
        find.text(
          CourseLearningStrings.messageFor(CourseLearningFailureKind.network),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a link the OS will not open says so', (tester) async {
      openSucceeds = false;
      await pump(tester, _Repo([issuedEntry]));

      await tester.tap(downloadButton());
      await tester.pumpAndSettle();

      expect(find.text(CourseLearningStrings.unexpectedError), findsOneWidget);
    });
  });

  group('continue learning', () {
    testWidgets('opens the course\'s Module List', (tester) async {
      await pump(tester, _Repo([pendingEntry]));

      await tester.tap(find.text(CourseLearningStrings.continueLearning));
      await tester.pumpAndSettle();

      final screen = tester.widget<CourseModuleListScreen>(
        find.byType(CourseModuleListScreen),
      );
      expect(screen.courseSlug, 'test-course-two');
      expect(learning.calls, ['test-course-two']);
    });
  });

  group('loading, failure and empty', () {
    testWidgets('a spinner while the list loads', (tester) async {
      final repository = _Repo([issuedEntry], hold: true);
      useLogicalViewport(tester, const Size(393, 960), padding: iPhonePadding);
      await tester.pumpWidget(
        MaterialApp(
          home: CertificateScreen(
            repository: repository,
            courseLearning: learning,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repository.release();
      await tester.pumpAndSettle();
      expect(find.text('Test Cohort A'), findsOneWidget);
    });

    testWidgets('a failure says why, and retry loads again', (tester) async {
      final repository = _Repo(
        [issuedEntry],
        failure: const CourseLearningFailure(CourseLearningFailureKind.server),
      );
      await pump(tester, repository);

      expect(
        find.text(
          CourseLearningStrings.messageFor(CourseLearningFailureKind.server),
        ),
        findsOneWidget,
      );
      expect(find.byType(CertificatePreview), findsNothing);

      repository.failure = null;
      await tester.tap(find.text(CertificateStrings.retry));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(find.text('Test Cohort A'), findsOneWidget);
    });

    testWidgets('enrolled in nothing says so', (tester) async {
      await pump(tester, _Repo([]));

      expect(find.text(CertificateStrings.empty), findsOneWidget);
      expect(find.byType(CertificatePreview), findsNothing);
    });
  });

  testWidgets('the Adult Profile\'s Certificate row opens it, and back '
      'returns to Profile', (tester) async {
    useLogicalViewport(tester, const Size(393, 1219), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: FakeCurrentUserRepository(hold: true),
          certificateRepository: _Repo([issuedEntry]),
          courseLearningRepository: learning,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(ProfileStrings.certificate));
    await tester.pumpAndSettle();

    expect(find.byType(CertificateScreen), findsOneWidget);
    expect(find.text('Test Course One'), findsOneWidget);

    Navigator.of(tester.element(find.byType(CertificateScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(CertificateScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
  });
}

/// A list the tests drive by hand: returns [entries], throws [failure], or
/// — when [hold] is set — waits for [release].
class _Repo implements CertificateListRepository {
  _Repo(this.entries, {this.failure, this.hold = false});

  final List<CertificateEntry> entries;
  CourseLearningFailure? failure;
  final bool hold;

  /// How many times the list was asked for.
  int calls = 0;

  final Completer<void> _gate = Completer<void>();

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<List<CertificateEntry>> getCertificates() async {
    calls++;
    if (hold) await _gate.future;
    if (failure case final failure?) throw failure;
    return entries;
  }
}
