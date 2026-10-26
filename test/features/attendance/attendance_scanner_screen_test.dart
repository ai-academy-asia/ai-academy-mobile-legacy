import 'dart:async';

import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/attendance/domain/attendance_check_in.dart';
import 'package:aia_mobile/features/attendance/domain/attendance_failure.dart';
import 'package:aia_mobile/features/attendance/presentation/attendance_scanner_screen.dart';
import 'package:aia_mobile/features/attendance/presentation/qr_scan_view.dart';
import 'package:aia_mobile/features/attendance/presentation/student_check_in_controller.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/shared/widgets/app_back_button.dart';
import 'package:aia_mobile/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_attendance_repository.dart';

/// The attendance scanner (Issues #202, #384): a swappable scan source
/// stands in for the camera, and a fake repository for the API — no camera,
/// no production call, no real attendance. The tokens are made-up fixtures.
const token = 'fixture-qr-token_AbC-123';

/// Stands in for the camera: records what the screen asks of it, and lets
/// a test report a code or a camera failure by hand.
class FakeScanSource {
  bool active = false;
  int builds = 0;
  ValueChanged<String>? _onCode;
  ValueChanged<QrScanUnavailable>? _onUnavailable;

  Widget build({
    required bool active,
    required ValueChanged<String> onCode,
    required ValueChanged<QrScanUnavailable> onUnavailable,
  }) {
    this.active = active;
    builds++;
    _onCode = onCode;
    _onUnavailable = onUnavailable;
    // No picture: what shows is the screen's own ground under the scrim,
    // as the reference draws it.
    return const SizedBox.expand();
  }

  /// The camera read [code] — only delivered while scanning, as the real
  /// view does.
  void read(String code) {
    if (active) _onCode!(code);
  }

  /// The camera read [code] regardless — a stray frame after it was told
  /// to stop.
  void readAnyway(String code) => _onCode!(code);

  void fail(QrScanUnavailable reason) => _onUnavailable!(reason);
}

AttendanceCheckIn record(
  String status, {
  bool first = true,
  String method = 'qr',
}) => AttendanceCheckIn(
  sessionId: 41,
  status: status,
  method: method,
  checkedInAt: DateTime.utc(2026, 10, 13, 6, 1),
  firstCheckIn: first,
);

void main() {
  setUpAll(loadAppFonts);

  Future<(FakeScanSource, FakeAttendanceRepository)> pumpScanner(
    WidgetTester tester, {
    FakeAttendanceRepository? repository,
    double width = 393,
    double scale = 1,
    List<String>? errors,
  }) async {
    final source = FakeScanSource();
    final repo = repository ?? FakeAttendanceRepository();
    useLogicalViewport(tester, Size(width, 852), padding: iPhonePadding);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final previous = FlutterError.onError;
    if (errors != null) {
      FlutterError.onError = (details) => errors.add(details.toString());
    }
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AttendanceScannerScreen(
                        repository: repo,
                        scanView: source.build,
                      ),
                    ),
                  ),
                  child: const Text('home'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previous;
    }
    return (source, repo);
  }

  testWidgets('scanning: the hint, the window, the camera live — and no '
      '"Гараар оруулах"', (tester) async {
    final (source, _) = await pumpScanner(tester);
    expect(find.text(AttendanceScannerStrings.hint), findsOneWidget);
    expect(
      find.bySemanticsLabel(AttendanceScannerStrings.window),
      findsOneWidget,
    );
    expect(source.active, isTrue);
    expect(find.text('Гараар оруулах'), findsNothing);
    expect(find.byType(PillButton), findsNothing);
  });

  testWidgets('the first code is checked in once: the camera stops, and '
      'further detections are ignored', (tester) async {
    final gate = Completer<void>();
    final repo = _GatedRepository(gate, record('present'));
    final (source, _) = await pumpScanner(tester, repository: repo);

    source.read(token);
    await tester.pump();
    expect(repo.tokens, [token]);
    expect(source.active, isFalse);
    expect(find.text(AttendanceScannerStrings.checkingIn), findsOneWidget);
    expect(find.text(AttendanceScannerStrings.hint), findsNothing);

    // The same code next frame, another code: nothing more is sent.
    source.readAnyway(token);
    source.readAnyway('another-fixture');
    await tester.pump();
    expect(repo.tokens, [token]);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ирц бүртгэгдлээ'), findsOneWidget);
    expect(repo.tokens, [token]);
  });

  for (final (status, title) in [
    ('present', 'Ирц бүртгэгдлээ'),
    ('late', 'Хоцорсон гэж бүртгэгдлээ'),
  ]) {
    testWidgets('a first check-in, $status: "$title"', (tester) async {
      final (source, _) = await pumpScanner(
        tester,
        repository: FakeAttendanceRepository()..checkInResult = record(status),
      );
      source.read(token);
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(
        find.text(AttendanceScannerStrings.resultBody(record(status)) ?? '-'),
        findsNothing,
      );
    });
  }

  testWidgets('a repeat says the record is the earlier one', (tester) async {
    final (source, _) = await pumpScanner(
      tester,
      repository: FakeAttendanceRepository()
        ..checkInResult = record('present', first: false),
    );
    source.read(token);
    await tester.pumpAndSettle();
    expect(find.text('Ирц бүртгэгдлээ'), findsOneWidget);
    expect(
      find.text('Та энэ хичээлд өмнө нь бүртгэгдсэн байна.'),
      findsOneWidget,
    );
  });

  for (final (status, title) in [
    ('absent', 'Ирээгүй гэж бүртгэгдсэн байна'),
    ('excused', 'Чөлөөтэй гэж бүртгэгдсэн байна'),
  ]) {
    testWidgets('a repeat returning a teacher\'s "$status" shows "$title", '
        'never a success', (tester) async {
      final (source, _) = await pumpScanner(
        tester,
        repository: FakeAttendanceRepository()
          ..checkInResult = record(status, first: false, method: 'manual'),
      );
      source.read(token);
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(find.text('Ирц бүртгэгдлээ'), findsNothing);
      expect(find.textContaining('Багш таны ирцийг'), findsOneWidget);
    });
  }

  testWidgets('an unknown status is shown as returned', (tester) async {
    final (source, _) = await pumpScanner(
      tester,
      repository: FakeAttendanceRepository()
        ..checkInResult = record('remote', first: false),
    );
    source.read(token);
    await tester.pumpAndSettle();
    expect(find.text('Ирцийн төлөв: remote'), findsOneWidget);
  });

  testWidgets('"Ойлголоо" closes the scanner', (tester) async {
    final (source, _) = await pumpScanner(
      tester,
      repository: FakeAttendanceRepository()..checkInResult = record('present'),
    );
    source.read(token);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AttendanceScannerStrings.done));
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceScannerScreen), findsNothing);
  });

  group('refusals and failures', () {
    for (final (code, message) in [
      ('invalid_token', 'QR код хүчингүй'),
      ('token_required', 'QR код уншигдсангүй'),
      ('not_enrolled', 'Та энэ хичээлд бүртгэлгүй байна.'),
    ]) {
      testWidgets('$code: says so; "Дахин уншуулах" scans again', (
        tester,
      ) async {
        final repo = FakeAttendanceRepository()
          ..checkInFailure = AttendanceFailure(
            AttendanceFailureKind.rejected,
            code: code,
          );
        final (source, _) = await pumpScanner(tester, repository: repo);
        source.read(token);
        await tester.pumpAndSettle();
        expect(find.textContaining(message), findsOneWidget);
        expect(source.active, isFalse);

        expect(find.text(AttendanceScannerStrings.rescan), findsOneWidget);
        repo
          ..checkInFailure = null
          ..checkInResult = record('present');
        await tester.tap(find.text(AttendanceScannerStrings.rescan));
        await tester.pumpAndSettle();
        expect(source.active, isTrue);
        source.read(token);
        await tester.pumpAndSettle();
        expect(repo.checkInCalls, 2);
        expect(find.text('Ирц бүртгэгдлээ'), findsOneWidget);
      });
    }

    for (final (kind, message) in [
      (AttendanceFailureKind.network, HomeStrings.networkError),
      (AttendanceFailureKind.server, HomeStrings.serverError),
      (AttendanceFailureKind.unexpected, HomeStrings.unexpectedError),
    ]) {
      testWidgets('${kind.name}: its message, and a rescan', (tester) async {
        final (source, _) = await pumpScanner(
          tester,
          repository: FakeAttendanceRepository()
            ..checkInFailure = AttendanceFailure(kind),
        );
        source.read(token);
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
        expect(find.text(AttendanceScannerStrings.rescan), findsOneWidget);
      });
    }

    testWidgets('session expired: says so, and offers no rescan', (
      tester,
    ) async {
      final (source, _) = await pumpScanner(
        tester,
        repository: FakeAttendanceRepository()
          ..checkInFailure = const AttendanceFailure(
            AttendanceFailureKind.sessionExpired,
          ),
      );
      source.read(token);
      await tester.pumpAndSettle();
      expect(find.text(HomeStrings.sessionExpired), findsOneWidget);
      expect(find.text(AttendanceScannerStrings.rescan), findsNothing);
    });
  });

  group('the camera', () {
    testWidgets('permission denied: says so; retry starts a fresh camera', (
      tester,
    ) async {
      final (source, _) = await pumpScanner(tester);
      source.fail(QrScanUnavailable.permissionDenied);
      await tester.pumpAndSettle();
      expect(find.textContaining('Камер ашиглах зөвшөөрөл'), findsOneWidget);
      expect(source.active, isFalse);
      final builds = source.builds;
      await tester.tap(find.text(AttendanceScannerStrings.retryCamera));
      await tester.pumpAndSettle();
      expect(source.active, isTrue);
      expect(source.builds, greaterThan(builds));
      expect(find.text(AttendanceScannerStrings.hint), findsOneWidget);
    });

    testWidgets('unsupported (e.g. the simulator): says so, no retry', (
      tester,
    ) async {
      final (source, _) = await pumpScanner(tester);
      source.fail(QrScanUnavailable.unsupported);
      await tester.pumpAndSettle();
      expect(
        find.text('Энэ төхөөрөмж дээр камер ашиглах боломжгүй.'),
        findsOneWidget,
      );
      expect(find.text(AttendanceScannerStrings.retryCamera), findsNothing);
    });

    testWidgets('a camera failure after a code was read changes nothing', (
      tester,
    ) async {
      final (source, _) = await pumpScanner(
        tester,
        repository: FakeAttendanceRepository()
          ..checkInResult = record('present'),
      );
      source.read(token);
      await tester.pumpAndSettle();
      source.fail(QrScanUnavailable.failed);
      await tester.pumpAndSettle();
      expect(find.text('Ирц бүртгэгдлээ'), findsOneWidget);
    });
  });

  testWidgets('back returns to where it was opened from', (tester) async {
    await pumpScanner(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AppBackButton),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceScannerScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a result arriving after the scanner closed changes nothing', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repo = _GatedRepository(gate, record('present'));
    final (source, _) = await pumpScanner(tester, repository: repo);
    source.read(token);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    gate.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the token is never shown or kept in the widget tree', (
    tester,
  ) async {
    final repo = FakeAttendanceRepository()
      ..checkInFailure = const AttendanceFailure(
        AttendanceFailureKind.rejected,
        code: 'invalid_token',
      );
    final (source, _) = await pumpScanner(tester, repository: repo);
    source.read(token);
    await tester.pumpAndSettle();
    final tree = tester.binding.rootElement!.toStringDeep();
    expect(tree.contains(token), isFalse);
    expect(find.textContaining(token), findsNothing);
  });

  group('layout', () {
    for (final width in [320.0, 393.0]) {
      for (final scale in [1.0, 2.0, 3.0]) {
        testWidgets('${width.toInt()} wide, text ×$scale: each state without '
            'overflow', (tester) async {
          final errors = <String>[];
          final repo = FakeAttendanceRepository()
            ..checkInResult = record('absent', first: false);
          final (source, _) = await pumpScanner(
            tester,
            repository: repo,
            width: width,
            scale: scale,
            errors: errors,
          );
          final previous = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(details.toString());
          try {
            source.read(token);
            await tester.pumpAndSettle();
            expect(find.text(AttendanceScannerStrings.done), findsOneWidget);
          } finally {
            FlutterError.onError = previous;
          }
          expect(errors, isEmpty);
        });
      }
    }
  });

  // Issue #532: the refusal and camera pill held "Дахин уншуулах" to one line
  // and cut it short at 2.0× text on a 320pt phone; it now wraps.
  group('large text, strict: the action pill whole at 2.0× on 320pt', () {
    tearDown(
      () => AppLocaleController.instance.setPreference(
        LocalePreference.mongolian,
      ),
    );

    final cases =
        <
          (
            String,
            void Function(FakeScanSource),
            FakeAttendanceRepository Function(),
          )
        >[
          for (final code in [
            'invalid_token',
            'token_required',
            'not_enrolled',
          ])
            (
              'refusal $code',
              (s) => s.read(token),
              () => FakeAttendanceRepository()
                ..checkInFailure = AttendanceFailure(
                  AttendanceFailureKind.rejected,
                  code: code,
                ),
            ),
          for (final reason in [
            QrScanUnavailable.permissionDenied,
            QrScanUnavailable.failed,
          ])
            (
              'camera ${reason.name}',
              (s) => s.fail(reason),
              FakeAttendanceRepository.new,
            ),
        ];

    for (final (name, act, repository) in cases) {
      for (final language in LocalePreference.values) {
        testWidgets('$name, ${language.name}: the pill\'s label is whole, '
            'inside the pill, the panel and the screen', (tester) async {
          await AppLocaleController.instance.setPreference(language);
          final errors = <String>[];
          final (source, _) = await pumpScanner(
            tester,
            repository: repository(),
            width: 320,
            scale: 2,
            errors: errors,
          );
          act(source);
          await tester.pumpAndSettle();

          final pill = find.byType(PillButton);
          expect(pill, findsOneWidget);
          final label = find.descendant(
            of: pill,
            matching: find.byType(RichText),
          );
          await tester.ensureVisible(pill);
          await tester.pumpAndSettle();
          final paragraph = tester.renderObject<RenderParagraph>(label);
          final text = paragraph.text.toPlainText();
          // Not cut short, and drawn at its full height.
          expect(paragraph.didExceedMaxLines, isFalse, reason: text);
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(
              paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
            ),
            reason: text,
          );
          final box = tester.getRect(label);
          final pillRect = tester.getRect(pill);
          expect(box.left, greaterThanOrEqualTo(pillRect.left), reason: text);
          expect(box.right, lessThanOrEqualTo(pillRect.right), reason: text);
          expect(box.top, greaterThanOrEqualTo(pillRect.top), reason: text);
          expect(box.bottom, lessThanOrEqualTo(pillRect.bottom), reason: text);
          final viewport = tester.getRect(
            find.ancestor(of: pill, matching: find.byType(Scrollable)).first,
          );
          expect(pillRect.top, greaterThanOrEqualTo(viewport.top - 0.01));
          expect(pillRect.bottom, lessThanOrEqualTo(viewport.bottom + 0.01));
          expect(pillRect.left, greaterThanOrEqualTo(0));
          expect(pillRect.right, lessThanOrEqualTo(320));
          expect(pillRect.bottom, lessThanOrEqualTo(852));
          expect(tester.takeException(), isNull);
          expect(errors, isEmpty);
        });
      }
    }

    testWidgets('at the default size the rescan pill is still 44 tall, one '
        'line', (tester) async {
      final (source, _) = await pumpScanner(
        tester,
        repository: FakeAttendanceRepository()
          ..checkInFailure = const AttendanceFailure(
            AttendanceFailureKind.rejected,
            code: 'invalid_token',
          ),
        width: 320,
      );
      source.read(token);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(PillButton)).height, 44);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(PillButton),
          matching: find.byType(RichText),
        ),
      );
      expect(
        paragraph.size.height,
        paragraph.getMaxIntrinsicHeight(double.infinity),
      );
    });

    testWidgets('the result\'s "Ойлголоо" pill is unchanged: one line', (
      tester,
    ) async {
      final (source, _) = await pumpScanner(
        tester,
        repository: FakeAttendanceRepository()
          ..checkInResult = record('present'),
      );
      source.read(token);
      await tester.pumpAndSettle();
      final pill = tester.widget<PillButton>(find.byType(PillButton));
      expect(pill.wrapLabel, isFalse);
    });
  });

  group('goldens', () {
    testWidgets('scanning, at the reference frame', (tester) async {
      await pumpScanner(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/attendance_scanner.png'),
      );
    });

    testWidgets('a first check-in, present', (tester) async {
      final (source, _) = await pumpScanner(
        tester,
        repository: FakeAttendanceRepository()
          ..checkInResult = record('present'),
      );
      source.read(token);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/attendance_scanner_present.png'),
      );
    });

    testWidgets('an expired code', (tester) async {
      final (source, _) = await pumpScanner(
        tester,
        repository: FakeAttendanceRepository()
          ..checkInFailure = const AttendanceFailure(
            AttendanceFailureKind.rejected,
            code: 'invalid_token',
          ),
      );
      source.read(token);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/attendance_scanner_invalid.png'),
      );
    });
  });

  test('the controller ignores an empty code', () async {
    final repo = FakeAttendanceRepository()..checkInResult = record('present');
    final controller = StudentCheckInController(repository: repo);
    await controller.onCode('');
    expect(repo.checkInCalls, 0);
    expect(controller.phase, CheckInPhase.scanning);
  });
}

/// Holds [checkIn] until [gate] completes, recording each token it was
/// given (test fixtures only).
class _GatedRepository extends FakeAttendanceRepository {
  _GatedRepository(this.gate, AttendanceCheckIn result) {
    checkInResult = result;
  }

  final Completer<void> gate;
  final List<String> tokens = [];

  @override
  Future<AttendanceCheckIn> checkIn(String token) async {
    tokens.add(token);
    await gate.future;
    return super.checkIn(token);
  }
}
