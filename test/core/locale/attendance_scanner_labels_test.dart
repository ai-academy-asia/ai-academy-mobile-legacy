import 'dart:async';

import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/attendance/domain/attendance_check_in.dart';
import 'package:aia_mobile/features/attendance/domain/attendance_failure.dart';
import 'package:aia_mobile/features/attendance/presentation/attendance_scanner_screen.dart';
import 'package:aia_mobile/features/attendance/presentation/qr_scan_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/attendance/attendance_scanner_screen_test.dart'
    show FakeScanSource, record, token;
import '../../features/attendance/fake_attendance_repository.dart';
import '../../support/screenshot.dart';

/// Issue #531: the student attendance scanner in the selected language.
/// Mongolian reads exactly as before. A camera seam and a fake repository
/// stand in for the camera and the API — no camera, no production call, no
/// real attendance; the token is a made-up fixture.
void main() {
  setUpAll(loadAppFonts);
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  /// Every key, its Mongolian exactly as the scanner showed it before, and
  /// the approved English.
  const copy = <String, ({String mongolian, String english})>{
    'scannerHint': (
      mongolian: 'QR кодыг хүрээн дотор хөдөлгөөнгүй уншуулна уу.',
      english: 'Hold the QR code still inside the frame.',
    ),
    'scannerWindow': (
      mongolian: 'QR код уншуулах хүрээ',
      english: 'QR code scanning area',
    ),
    'scannerCheckingIn': (
      mongolian: 'Ирц бүртгэж байна…',
      english: 'Checking you in…',
    ),
    'scannerRescan': (mongolian: 'Дахин уншуулах', english: 'Scan again'),
    'scannerDone': (mongolian: 'Ойлголоо', english: 'Got it'),
    'scannerResultPresent': (
      mongolian: 'Ирц бүртгэгдлээ',
      english: 'Attendance recorded',
    ),
    'scannerResultLate': (
      mongolian: 'Хоцорсон гэж бүртгэгдлээ',
      english: 'Recorded as late',
    ),
    'scannerResultAbsent': (
      mongolian: 'Ирээгүй гэж бүртгэгдсэн байна',
      english: 'Recorded as absent',
    ),
    'scannerResultExcused': (
      mongolian: 'Чөлөөтэй гэж бүртгэгдсэн байна',
      english: 'Recorded as excused',
    ),
    'scannerTeacherRecorded': (
      mongolian:
          'Багш таны ирцийг өмнө нь бүртгэсэн байна. Асуух зүйл байвал '
          'багшдаа хандана уу.',
      english:
          'Your teacher has already recorded your attendance. If you have '
          'any questions, please ask your teacher.',
    ),
    'scannerAlreadyCheckedIn': (
      mongolian: 'Та энэ хичээлд өмнө нь бүртгэгдсэн байна.',
      english: 'You were already checked in for this lesson.',
    ),
    'scannerInvalidToken': (
      mongolian:
          'QR код хүчингүй эсвэл хугацаа нь дууссан байна. Багшийн дэлгэц '
          'дээрх шинэ кодыг уншуулна уу.',
      english:
          'This QR code is invalid or has expired. Scan the new code on your '
          "teacher's screen.",
    ),
    'scannerTokenRequired': (
      mongolian: 'QR код уншигдсангүй. Дахин уншуулна уу.',
      english: "The QR code couldn't be read. Please scan it again.",
    ),
    'scannerNotEnrolled': (
      mongolian: 'Та энэ хичээлд бүртгэлгүй байна.',
      english: 'You are not enrolled in this course.',
    ),
    'scannerCameraDenied': (
      mongolian:
          'Камер ашиглах зөвшөөрөл олгоогүй байна. Утасны тохиргооноос '
          'камерын зөвшөөрлийг идэвхжүүлээд дахин оролдоно уу.',
      english:
          "Camera access isn't allowed. Turn on camera access in your "
          "phone's settings, then try again.",
    ),
    'scannerCameraUnsupported': (
      mongolian: 'Энэ төхөөрөмж дээр камер ашиглах боломжгүй.',
      english: "The camera can't be used on this device.",
    ),
    'scannerCameraFailed': (
      mongolian: 'Камерыг асаах үед алдаа гарлаа.',
      english: 'Something went wrong while starting the camera.',
    ),
    // Shared, already localized: the camera retry.
    'commonRetry': (mongolian: 'Дахин оролдох', english: 'Try again.'),
  };

  String text(String key, LocalePreference language) =>
      language == LocalePreference.mongolian
      ? copy[key]!.mongolian
      : copy[key]!.english;
  String en(String key) => text(key, LocalePreference.english);
  String mn(String key) => text(key, LocalePreference.mongolian);

  /// The unknown-status heading, with [status] as the server sent it.
  String other(String status, LocalePreference language) =>
      language == LocalePreference.mongolian
      ? 'Ирцийн төлөв: $status'
      : 'Attendance status: $status';

  /// `resultTitle` for each status the server documents, by key.
  const titles = {
    'present': 'scannerResultPresent',
    'late': 'scannerResultLate',
    'absent': 'scannerResultAbsent',
    'excused': 'scannerResultExcused',
  };

  group('the keys', () {
    for (final language in LocalePreference.values) {
      test(language.name, () {
        final s = L10n.of(language);
        expect(
          {
            'scannerHint': s.scannerHint,
            'scannerWindow': s.scannerWindow,
            'scannerCheckingIn': s.scannerCheckingIn,
            'scannerRescan': s.scannerRescan,
            'scannerDone': s.scannerDone,
            'scannerResultPresent': s.scannerResultPresent,
            'scannerResultLate': s.scannerResultLate,
            'scannerResultAbsent': s.scannerResultAbsent,
            'scannerResultExcused': s.scannerResultExcused,
            'scannerTeacherRecorded': s.scannerTeacherRecorded,
            'scannerAlreadyCheckedIn': s.scannerAlreadyCheckedIn,
            'scannerInvalidToken': s.scannerInvalidToken,
            'scannerTokenRequired': s.scannerTokenRequired,
            'scannerNotEnrolled': s.scannerNotEnrolled,
            'scannerCameraDenied': s.scannerCameraDenied,
            'scannerCameraUnsupported': s.scannerCameraUnsupported,
            'scannerCameraFailed': s.scannerCameraFailed,
            'commonRetry': s.commonRetry,
          },
          {for (final key in copy.keys) key: text(key, language)},
        );
        // The placeholder: the server's status, inserted as sent.
        for (final status in ['remote', 'on_leave', 'Present ', '']) {
          expect(s.scannerResultOther(status), other(status, language));
        }
      });

      test('AttendanceScannerStrings in ${language.name}', () async {
        await locale.setPreference(language);
        expect(AttendanceScannerStrings.hint, text('scannerHint', language));
        expect(
          AttendanceScannerStrings.window,
          text('scannerWindow', language),
        );
        expect(
          AttendanceScannerStrings.checkingIn,
          text('scannerCheckingIn', language),
        );
        expect(
          AttendanceScannerStrings.rescan,
          text('scannerRescan', language),
        );
        expect(AttendanceScannerStrings.done, text('scannerDone', language));
        expect(
          AttendanceScannerStrings.retryCamera,
          text('commonRetry', language),
        );

        // All five headings: the four documented statuses and the fallback.
        for (final MapEntry(key: status, value: key) in titles.entries) {
          expect(
            AttendanceScannerStrings.resultTitle(status),
            text(key, language),
            reason: status,
          );
        }
        expect(
          AttendanceScannerStrings.resultTitle('remote'),
          other('remote', language),
        );

        // Both bodies, and none for a first check-in.
        for (final status in ['absent', 'excused']) {
          expect(
            AttendanceScannerStrings.resultBody(
              record(status, first: false, method: 'manual'),
            ),
            text('scannerTeacherRecorded', language),
          );
        }
        expect(
          AttendanceScannerStrings.resultBody(record('present', first: false)),
          text('scannerAlreadyCheckedIn', language),
        );
        expect(AttendanceScannerStrings.resultBody(record('present')), isNull);

        // The three server refusals and the three camera states.
        for (final (code, key) in [
          ('invalid_token', 'scannerInvalidToken'),
          ('token_required', 'scannerTokenRequired'),
          ('not_enrolled', 'scannerNotEnrolled'),
        ]) {
          expect(
            AttendanceScannerStrings.failureMessage(
              AttendanceFailure(AttendanceFailureKind.rejected, code: code),
            ),
            text(key, language),
            reason: code,
          );
        }
        for (final (reason, key) in [
          (QrScanUnavailable.permissionDenied, 'scannerCameraDenied'),
          (QrScanUnavailable.unsupported, 'scannerCameraUnsupported'),
          (QrScanUnavailable.failed, 'scannerCameraFailed'),
        ]) {
          expect(
            AttendanceScannerStrings.unavailableMessage(reason),
            text(key, language),
            reason: reason.name,
          );
        }
      });
    }
  });

  /// The scanner over a stand-in screen, as the app pushes it, under the
  /// language rebuild scope.
  Future<FakeScanSource> pumpScanner(
    WidgetTester tester,
    FakeAttendanceRepository repository, {
    double width = 393,
  }) async {
    final source = FakeScanSource();
    useLogicalViewport(tester, Size(width, 852), padding: iPhonePadding);
    // A fresh tree: nothing carried over from an earlier pump.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: Text('home')),
        ),
      ),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => AttendanceScannerScreen(
              repository: repository,
              scanView: source.build,
            ),
          ),
        );
    await tester.pumpAndSettle();
    return source;
  }

  FakeAttendanceRepository refusing(String code) => FakeAttendanceRepository()
    ..checkInFailure = AttendanceFailure(
      AttendanceFailureKind.rejected,
      code: code,
    );

  FakeAttendanceRepository returning(AttendanceCheckIn result) =>
      FakeAttendanceRepository()..checkInResult = result;

  group('in English', () {
    setUp(() => locale.setEnglish(true));

    testWidgets('scanning: the hint, and the window read out', (tester) async {
      final semantics = tester.ensureSemantics();
      final source = await pumpScanner(tester, FakeAttendanceRepository());

      expect(source.active, isTrue);
      expect(find.text(en('scannerHint')), findsOneWidget);
      expect(find.text(mn('scannerHint')), findsNothing);
      expect(find.bySemanticsLabel(en('scannerWindow')), findsOneWidget);
      expect(find.bySemanticsLabel(mn('scannerWindow')), findsNothing);
      semantics.dispose();
    });

    testWidgets('checking in: "Checking you in…", sent once', (tester) async {
      final gate = Completer<void>();
      final repository = _HeldRepository(gate, record('present'));
      final source = await pumpScanner(tester, repository);

      source.read(token);
      await tester.pump();
      expect(find.text(en('scannerCheckingIn')), findsOneWidget);
      expect(find.text(en('scannerHint')), findsNothing);
      // Further detections are still ignored.
      source.readAnyway(token);
      await tester.pump();
      expect(repository.checkInCalls, 1);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text(en('scannerResultPresent')), findsOneWidget);
      expect(repository.checkInCalls, 1);
    });

    for (final (name, result, keys) in [
      (
        'a first check-in, present',
        record('present'),
        ['scannerResultPresent'],
      ),
      ('a first check-in, late', record('late'), ['scannerResultLate']),
      (
        'a repeat',
        record('present', first: false),
        ['scannerResultPresent', 'scannerAlreadyCheckedIn'],
      ),
      (
        'a teacher\'s absent',
        record('absent', first: false, method: 'manual'),
        ['scannerResultAbsent', 'scannerTeacherRecorded'],
      ),
      (
        'a teacher\'s excused',
        record('excused', first: false, method: 'manual'),
        ['scannerResultExcused', 'scannerTeacherRecorded'],
      ),
    ]) {
      testWidgets('$name: its heading and body, and Got it', (tester) async {
        final source = await pumpScanner(tester, returning(result));
        source.read(token);
        await tester.pumpAndSettle();

        for (final key in [...keys, 'scannerDone']) {
          expect(find.text(en(key)), findsOneWidget, reason: key);
          expect(find.text(mn(key)), findsNothing, reason: key);
        }
        // Never a generic success for a teacher's record.
        if (result.status != 'present') {
          expect(find.text(en('scannerResultPresent')), findsNothing);
        }
      });
    }

    testWidgets('an unknown status is shown as returned', (tester) async {
      final source = await pumpScanner(
        tester,
        returning(record('remote', first: false)),
      );
      source.read(token);
      await tester.pumpAndSettle();

      expect(
        find.text(other('remote', LocalePreference.english)),
        findsOneWidget,
      );
      expect(
        find.text(other('remote', LocalePreference.mongolian)),
        findsNothing,
      );
    });

    testWidgets('Got it closes the scanner', (tester) async {
      final source = await pumpScanner(tester, returning(record('present')));
      source.read(token);
      await tester.pumpAndSettle();
      await tester.tap(find.text(en('scannerDone')));
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceScannerScreen), findsNothing);
    });

    for (final (code, key) in [
      ('invalid_token', 'scannerInvalidToken'),
      ('token_required', 'scannerTokenRequired'),
      ('not_enrolled', 'scannerNotEnrolled'),
    ]) {
      testWidgets('$code: its message; Scan again scans again', (tester) async {
        final repository = refusing(code);
        final source = await pumpScanner(tester, repository);
        source.read(token);
        await tester.pumpAndSettle();

        expect(find.text(en(key)), findsOneWidget);
        expect(find.text(mn(key)), findsNothing);
        expect(source.active, isFalse);

        repository
          ..checkInFailure = null
          ..checkInResult = record('present');
        await tester.tap(find.text(en('scannerRescan')));
        await tester.pumpAndSettle();
        expect(source.active, isTrue);
        source.read(token);
        await tester.pumpAndSettle();
        expect(repository.checkInCalls, 2);
        expect(find.text(en('scannerResultPresent')), findsOneWidget);
      });
    }

    for (final (reason, key, retry) in [
      (QrScanUnavailable.permissionDenied, 'scannerCameraDenied', true),
      (QrScanUnavailable.unsupported, 'scannerCameraUnsupported', false),
      (QrScanUnavailable.failed, 'scannerCameraFailed', true),
    ]) {
      testWidgets('camera ${reason.name}: its message, '
          '${retry ? 'and Try again. starts a fresh camera' : 'no retry'}', (
        tester,
      ) async {
        final source = await pumpScanner(tester, FakeAttendanceRepository());
        source.fail(reason);
        await tester.pumpAndSettle();

        expect(find.text(en(key)), findsOneWidget);
        expect(find.text(mn(key)), findsNothing);
        expect(source.active, isFalse);
        if (!retry) {
          expect(find.text(en('commonRetry')), findsNothing);
          return;
        }
        final builds = source.builds;
        await tester.tap(find.text(en('commonRetry')));
        await tester.pumpAndSettle();
        expect(source.active, isTrue);
        expect(source.builds, greaterThan(builds));
        expect(find.text(en('scannerHint')), findsOneWidget);
      });
    }

    testWidgets('the token is never shown or kept in the widget tree', (
      tester,
    ) async {
      final source = await pumpScanner(tester, refusing('invalid_token'));
      source.read(token);
      await tester.pumpAndSettle();
      expect(find.text(en('scannerInvalidToken')), findsOneWidget);
      expect(
        tester.binding.rootElement!.toStringDeep().contains(token),
        isFalse,
      );
    });
  });

  group('switching language with the scanner open', () {
    testWidgets('scanning: the hint and the window change at once; the '
        'camera keeps running', (tester) async {
      final semantics = tester.ensureSemantics();
      final source = await pumpScanner(tester, FakeAttendanceRepository());
      final state = tester.state(find.byType(AttendanceScannerScreen));
      final builds = source.builds;
      expect(find.text(mn('scannerHint')), findsOneWidget);

      await locale.setEnglish(true);
      await tester.pump();

      expect(find.text(en('scannerHint')), findsOneWidget);
      expect(find.bySemanticsLabel(en('scannerWindow')), findsOneWidget);
      expect(tester.state(find.byType(AttendanceScannerScreen)), same(state));
      expect(source.active, isTrue);
      // Rebuilt in place — the same camera, not a fresh one.
      expect(source.builds, greaterThanOrEqualTo(builds));
      expect(
        tester.widget<KeyedSubtree>(find.byType(KeyedSubtree).first).key,
        isNotNull,
      );
      semantics.dispose();
    });

    testWidgets('a result: its heading, body and Got it change at once; '
        'nothing is sent again', (tester) async {
      final repository = returning(
        record('absent', first: false, method: 'manual'),
      );
      final source = await pumpScanner(tester, repository);
      source.read(token);
      await tester.pumpAndSettle();
      expect(find.text(mn('scannerResultAbsent')), findsOneWidget);
      final state = tester.state(find.byType(AttendanceScannerScreen));

      await locale.setEnglish(true);
      await tester.pump();

      for (final key in [
        'scannerResultAbsent',
        'scannerTeacherRecorded',
        'scannerDone',
      ]) {
        expect(find.text(en(key)), findsOneWidget, reason: key);
        expect(find.text(mn(key)), findsNothing, reason: key);
      }
      expect(tester.state(find.byType(AttendanceScannerScreen)), same(state));
      expect(repository.checkInCalls, 1);
    });

    testWidgets('an unknown status heading changes at once, the status '
        'itself as sent', (tester) async {
      final source = await pumpScanner(
        tester,
        returning(record('remote', first: false)),
      );
      source.read(token);
      await tester.pumpAndSettle();
      expect(
        find.text(other('remote', LocalePreference.mongolian)),
        findsOneWidget,
      );

      await locale.setEnglish(true);
      await tester.pump();
      expect(
        find.text(other('remote', LocalePreference.english)),
        findsOneWidget,
      );
    });

    testWidgets('a refusal: Scan again changes at once; the stored message '
        'keeps its language until the next scan (documented)', (tester) async {
      final repository = refusing('invalid_token');
      final source = await pumpScanner(tester, repository);
      source.read(token);
      await tester.pumpAndSettle();
      expect(find.text(mn('scannerInvalidToken')), findsOneWidget);

      await locale.setEnglish(true);
      await tester.pump();

      expect(find.text(en('scannerRescan')), findsOneWidget);
      // Stored by the controller when the check-in failed — unchanged.
      expect(find.text(mn('scannerInvalidToken')), findsOneWidget);
      expect(find.text(en('scannerInvalidToken')), findsNothing);

      // The next scan computes it again, in English.
      await tester.tap(find.text(en('scannerRescan')));
      await tester.pumpAndSettle();
      source.read(token);
      await tester.pumpAndSettle();
      expect(find.text(en('scannerInvalidToken')), findsOneWidget);
      expect(repository.checkInCalls, 2);
    });

    testWidgets('a camera message keeps its language until the next retry '
        '(documented); its retry label changes at once', (tester) async {
      final source = await pumpScanner(tester, FakeAttendanceRepository());
      source.fail(QrScanUnavailable.permissionDenied);
      await tester.pumpAndSettle();
      expect(find.text(mn('scannerCameraDenied')), findsOneWidget);

      await locale.setEnglish(true);
      await tester.pump();

      expect(find.text(en('commonRetry')), findsOneWidget);
      expect(find.text(mn('scannerCameraDenied')), findsOneWidget);

      await tester.tap(find.text(en('commonRetry')));
      await tester.pumpAndSettle();
      source.fail(QrScanUnavailable.permissionDenied);
      await tester.pumpAndSettle();
      expect(find.text(en('scannerCameraDenied')), findsOneWidget);
    });
  });

  // --- Large text -------------------------------------------------------------

  const width = 320.0;
  const height = 852.0;

  /// Each state, how to reach it, and the visible labels it shows.
  final states =
      <
        ({
          String name,
          FakeAttendanceRepository Function() repository,
          void Function(FakeScanSource) act,
          bool hold,
          List<String Function(LocalePreference)> labels,
        })
      >[
        (
          name: 'scanning',
          repository: FakeAttendanceRepository.new,
          act: (_) {},
          hold: false,
          labels: [(l) => text('scannerHint', l)],
        ),
        (
          name: 'checking in',
          repository: FakeAttendanceRepository.new,
          act: (s) => s.read(token),
          hold: true,
          labels: [(l) => text('scannerCheckingIn', l)],
        ),
        for (final (status, first, key) in [
          ('present', true, 'scannerResultPresent'),
          ('late', true, 'scannerResultLate'),
        ])
          (
            name: 'result, $status',
            repository: () => returning(record(status, first: first)),
            act: (s) => s.read(token),
            hold: false,
            labels: [(l) => text(key, l), (l) => text('scannerDone', l)],
          ),
        (
          name: 'result, a repeat',
          repository: () => returning(record('present', first: false)),
          act: (s) => s.read(token),
          hold: false,
          labels: [
            (l) => text('scannerResultPresent', l),
            (l) => text('scannerAlreadyCheckedIn', l),
            (l) => text('scannerDone', l),
          ],
        ),
        for (final (status, key) in [
          ('absent', 'scannerResultAbsent'),
          ('excused', 'scannerResultExcused'),
        ])
          (
            name: 'result, a teacher\'s $status',
            repository: () =>
                returning(record(status, first: false, method: 'manual')),
            act: (s) => s.read(token),
            hold: false,
            labels: [
              (l) => text(key, l),
              (l) => text('scannerTeacherRecorded', l),
              (l) => text('scannerDone', l),
            ],
          ),
        (
          name: 'result, an unknown status',
          repository: () => returning(record('remote', first: false)),
          act: (s) => s.read(token),
          hold: false,
          labels: [
            (l) => other('remote', l),
            (l) => text('scannerAlreadyCheckedIn', l),
            (l) => text('scannerDone', l),
          ],
        ),
        for (final (code, key) in [
          ('invalid_token', 'scannerInvalidToken'),
          ('token_required', 'scannerTokenRequired'),
          ('not_enrolled', 'scannerNotEnrolled'),
        ])
          (
            name: 'refusal, $code',
            repository: () => refusing(code),
            act: (s) => s.read(token),
            hold: false,
            labels: [(l) => text(key, l), (l) => text('scannerRescan', l)],
          ),
        for (final (reason, key, retry) in [
          (QrScanUnavailable.permissionDenied, 'scannerCameraDenied', true),
          (QrScanUnavailable.unsupported, 'scannerCameraUnsupported', false),
          (QrScanUnavailable.failed, 'scannerCameraFailed', true),
        ])
          (
            name: 'camera, ${reason.name}',
            repository: FakeAttendanceRepository.new,
            act: (s) => s.fail(reason),
            hold: false,
            labels: [
              (l) => text(key, l),
              if (retry) (l) => text('commonRetry', l),
            ],
          ),
      ];

  for (final state in states) {
    for (final language in LocalePreference.values) {
      testWidgets('${state.name}, ${language.name}, 2.0× text on a 320 pt '
          'phone: no overflow, every line whole, inside the screen and its '
          'card, nothing cut short', (tester) async {
        await locale.setPreference(language);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final gate = Completer<void>();
        final repository = state.hold
            ? _HeldRepository(gate, record('present'))
            : state.repository();
        final source = await pumpScanner(tester, repository, width: width);
        state.act(source);
        if (state.hold) {
          await tester.pump();
        } else {
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);

        for (final labelOf in state.labels) {
          final value = labelOf(language);
          final label = find.text(value);
          expect(label, findsOneWidget, reason: value);
          await tester.ensureVisible(label);
          await tester.pump();

          final rect = tester.getRect(label);
          expect(rect.left, greaterThanOrEqualTo(0), reason: value);
          expect(rect.right, lessThanOrEqualTo(width), reason: value);
          expect(rect.top, greaterThanOrEqualTo(0), reason: value);
          expect(rect.bottom, lessThanOrEqualTo(height), reason: value);

          // Inside the panel's scroll viewport, when it is in one: shown, not
          // hidden under its edge.
          final viewport = find.ancestor(
            of: label,
            matching: find.byType(Scrollable),
          );
          if (viewport.evaluate().isNotEmpty) {
            final box = tester.getRect(viewport.first);
            expect(
              rect.top,
              greaterThanOrEqualTo(box.top - 0.01),
              reason: value,
            );
            expect(
              rect.bottom,
              lessThanOrEqualTo(box.bottom + 0.01),
              reason: value,
            );
          }

          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: label, matching: find.byType(RichText)).first,
          );
          // Not cut short, and drawn at its full height.
          expect(paragraph.didExceedMaxLines, isFalse, reason: value);
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(
              paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
            ),
            reason: value,
          );
        }
        expect(tester.takeException(), isNull);
        if (state.hold) {
          gate.complete();
          await tester.pumpAndSettle();
        }
      });
    }
  }
}

/// Holds the check-in until [gate] completes, so the "checking in" state
/// can be seen.
class _HeldRepository extends FakeAttendanceRepository {
  _HeldRepository(this.gate, AttendanceCheckIn result) {
    checkInResult = result;
  }

  final Completer<void> gate;

  @override
  Future<AttendanceCheckIn> checkIn(String token) async {
    final result = super.checkIn(token);
    await gate.future;
    return result;
  }
}
