import 'dart:async';

import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/contracts/domain/contract_detail.dart';
import 'package:aia_mobile/features/contracts/domain/contract_failure.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_screen.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_strings.dart';
import 'package:aia_mobile/features/contracts/presentation/widgets/contract_card.dart';
import 'package:aia_mobile/features/home/presentation/widgets/home_badges.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_contract_repository.dart';

/// The E-Contract list's cards (Issue #312), from `StudentContract` data
/// through a fake repository — no API is reached, nothing signs. Test values
/// only.
void main() {
  setUpAll(loadAppFonts);

  const signed = StudentContract(
    id: '1',
    contractNumber: 'TEST-C-0001',
    status: StudentContractStatus.signed,
    course: ContractCourse(
      id: 9,
      titleMn: 'Тест курс нэг',
      titleEn: 'Test course one',
      level: 'adult',
    ),
    cohort: ContractCohort(id: 3, name: 'Test Cohort 01'),
    canView: true,
    isCurrent: true,
    documentUrl: '/me/contracts/1/download',
  );

  const pendingSignable = StudentContract(
    id: '2',
    contractNumber: 'TEST-C-0002',
    status: StudentContractStatus.pending,
    course: ContractCourse(id: 10, titleEn: 'Test course two', level: 'junior'),
    cohort: ContractCohort(id: 4, name: 'Test Cohort 02'),
    canView: true,
    canSign: true,
    isCurrent: true,
  );

  const pendingNotSignable = StudentContract(
    id: '3',
    status: StudentContractStatus.pending,
    course: ContractCourse(titleMn: 'Гарын үсэггүй курс', level: 'adult'),
    cohort: ContractCohort(name: 'Test Cohort 03'),
    isCurrent: true,
  );

  const cancelled = StudentContract(
    id: '4',
    status: StudentContractStatus.cancelled,
    course: ContractCourse(titleMn: 'Цуцлагдсан курс', level: 'adult'),
    cohort: ContractCohort(name: 'Test Cohort 04'),
  );

  const unknown = StudentContract(
    id: '5',
    course: ContractCourse(titleMn: 'Үл мэдэгдэх курс', level: 'adult'),
    cohort: ContractCohort(name: 'Test Cohort 05'),
    canSign: true,
    isCurrent: true,
    documentUrl: '/me/contracts/5/download',
  );

  const signedWithoutFile = StudentContract(
    id: '6',
    status: StudentContractStatus.signed,
    course: ContractCourse(titleMn: 'Файлгүй курс', level: 'adult'),
    cohort: ContractCohort(name: 'Test Cohort 06'),
  );

  late FakeContractRepository repository;
  late List<Uri> opened;
  late bool openSucceeds;
  late List<StudentContract> signTaps;

  setUp(() {
    repository = FakeContractRepository();
    opened = [];
    openSucceeds = true;
    signTaps = [];
  });

  Future<void> pump(
    WidgetTester tester,
    List<StudentContract> contracts, {
    bool withSign = false,
    Size size = const Size(393, 1800),
  }) async {
    repository.contracts = contracts;
    useLogicalViewport(tester, size, padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ContractScreen(
          repository: repository,
          openUrl: (url) async {
            opened.add(url);
            return openSucceeds;
          },
          onSign: withSign
              ? (context, contract) => signTaps.add(contract)
              : null,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The card showing [title].
  Finder card(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(ContractCard));

  Finder inCard(String title, Finder finder) =>
      find.descendant(of: card(title), matching: finder);

  SemanticsNode action(WidgetTester tester, String title, String label) =>
      tester.getSemantics(inCard(title, find.bySemanticsLabel(label)));

  testWidgets('one card per contract, in the API\'s order, from the '
      'contract\'s own course and cohort', (tester) async {
    await pump(tester, [signed, pendingSignable]);

    expect(find.byType(ContractCard), findsNWidgets(2));
    expect(find.text(ContractStrings.title), findsOneWidget);
    // Caption: the cohort; title: the course, Mongolian first.
    expect(inCard('Тест курс нэг', find.text('Test Cohort 01')), findsOne);
    expect(find.text('Test course one'), findsNothing);
    // English when that is all the course has.
    expect(inCard('Test course two', find.text('Test Cohort 02')), findsOne);
    expect(
      tester.getTopLeft(card('Тест курс нэг')).dy,
      lessThan(tester.getTopLeft(card('Test course two')).dy),
    );
    expect(find.text(ContractStrings.empty), findsNothing);
  });

  testWidgets('the track badge comes from the course level, and only adult '
      'or junior draws one', (tester) async {
    const otherLevel = StudentContract(
      id: '7',
      status: StudentContractStatus.signed,
      course: ContractCourse(titleMn: 'Бусад түвшин', level: 'teen'),
      cohort: ContractCohort(name: 'Test Cohort 07'),
    );
    await pump(tester, [signed, pendingSignable, otherLevel]);

    expect(inCard('Тест курс нэг', find.byType(TrackBadge)), findsOne);
    expect(
      tester
          .widget<TrackBadge>(inCard('Тест курс нэг', find.byType(TrackBadge)))
          .track,
      'adult',
    );
    expect(
      tester
          .widget<TrackBadge>(
            inCard('Test course two', find.byType(TrackBadge)),
          )
          .track,
      'junior',
    );
    expect(inCard('Бусад түвшин', find.byType(TrackBadge)), findsNothing);
  });

  group('status', () {
    testWidgets('signed reads "Гэрээ байгуулсан" with "Гэрээ татах"', (
      tester,
    ) async {
      await pump(tester, [signed]);

      expect(
        inCard('Тест курс нэг', find.text(ContractStrings.statusSigned)),
        findsOne,
      );
      expect(
        inCard('Тест курс нэг', find.text(ContractStrings.download)),
        findsOne,
      );
      expect(find.text(ContractStrings.statusPending), findsNothing);
      expect(find.text(ContractStrings.sign), findsNothing);
    });

    testWidgets('pending reads "Гэрээ хийгдээгүй байна" with "Гэрээ '
        'байгуулах"', (tester) async {
      await pump(tester, [pendingSignable]);

      expect(
        inCard('Test course two', find.text(ContractStrings.statusPending)),
        findsOne,
      );
      expect(
        inCard('Test course two', find.text(ContractStrings.sign)),
        findsOne,
      );
      expect(find.text(ContractStrings.statusSigned), findsNothing);
      expect(find.text(ContractStrings.download), findsNothing);
    });

    testWidgets('cancelled and unknown are neither signed nor pending, and '
        'offer no action — even with can_sign and a document', (tester) async {
      await pump(tester, [cancelled, unknown]);

      for (final title in ['Цуцлагдсан курс', 'Үл мэдэгдэх курс']) {
        expect(card(title), findsOne, reason: title);
        for (final text in [
          ContractStrings.statusSigned,
          ContractStrings.statusPending,
          ContractStrings.download,
          ContractStrings.sign,
        ]) {
          expect(
            inCard(title, find.text(text)),
            findsNothing,
            reason: '$title $text',
          );
        }
      }
    });
  });

  group('signing — nothing signs here', () {
    testWidgets('without a signing destination the action is disabled', (
      tester,
    ) async {
      await pump(tester, [pendingSignable]);

      expect(
        action(tester, 'Test course two', ContractStrings.sign),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          label: ContractStrings.sign,
        ),
      );
      await tester.tap(
        inCard('Test course two', find.text(ContractStrings.sign)),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(signTaps, isEmpty);
    });

    testWidgets('a contract that cannot be signed never invokes signing', (
      tester,
    ) async {
      await pump(tester, [pendingNotSignable], withSign: true);

      expect(
        action(tester, 'Гарын үсэггүй курс', ContractStrings.sign),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          label: ContractStrings.sign,
        ),
      );
      await tester.tap(
        inCard('Гарын үсэггүй курс', find.text(ContractStrings.sign)),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(signTaps, isEmpty);
    });

    testWidgets('a signable contract hands itself to the signing '
        'destination — and calls no API', (tester) async {
      await pump(tester, [pendingSignable], withSign: true);

      expect(
        action(tester, 'Test course two', ContractStrings.sign),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          label: ContractStrings.sign,
        ),
      );
      await tester.tap(
        inCard('Test course two', find.text(ContractStrings.sign)),
      );
      await tester.pumpAndSettle();

      expect(signTaps.single.id, '2');
      expect(repository.signCalls, isEmpty);
      expect(repository.detailCalls, isEmpty);
    });
  });

  group('download', () {
    ContractDownload link(String name) => ContractDownload(
      url: Uri.parse('https://files.example.test/$name.pdf'),
      expiresAt: DateTime.utc(2026, 10, 11, 3, 5),
    );

    testWidgets('fetches a fresh link for the contract and opens it', (
      tester,
    ) async {
      repository.downloads.addAll([link('first'), link('second')]);
      await pump(tester, [signed]);

      await tester.tap(
        inCard('Тест курс нэг', find.text(ContractStrings.download)),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        inCard('Тест курс нэг', find.text(ContractStrings.download)),
      );
      await tester.pumpAndSettle();

      expect(repository.downloadCalls, ['1', '1']);
      expect(opened, [
        Uri.parse('https://files.example.test/first.pdf'),
        Uri.parse('https://files.example.test/second.pdf'),
      ]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('is busy while the link is fetched, and a second tap asks '
        'for nothing', (tester) async {
      final gate = Completer<bool>();
      repository.downloads.add(link('only'));
      repository.contracts = [signed];
      useLogicalViewport(tester, const Size(393, 1800), padding: iPhonePadding);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ContractScreen(
            repository: repository,
            openUrl: (_) => gate.future,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        inCard('Тест курс нэг', find.text(ContractStrings.download)),
      );
      await tester.pump();
      expect(
        inCard('Тест курс нэг', find.byType(CircularProgressIndicator)),
        findsOne,
      );
      await tester.tap(
        inCard(
          'Тест курс нэг',
          find.bySemanticsLabel(ContractStrings.download),
        ),
        warnIfMissed: false,
      );
      await tester.pump();

      gate.complete(true);
      await tester.pumpAndSettle();
      expect(repository.downloadCalls, ['1']);
    });

    testWidgets('not_signed is a failure with the existing copy, and opens '
        'nothing', (tester) async {
      repository.downloadFailure = const ContractFailure(
        ContractFailureKind.notSigned,
      );
      await pump(tester, [signed]);

      await tester.tap(
        inCard('Тест курс нэг', find.text(ContractStrings.download)),
      );
      await tester.pumpAndSettle();

      expect(opened, isEmpty);
      expect(find.text(ProfileStrings.unexpectedError), findsOneWidget);
    });

    testWidgets('a link the OS will not open says so — never a success', (
      tester,
    ) async {
      repository.downloads.add(link('refused'));
      openSucceeds = false;
      await pump(tester, [signed]);

      await tester.tap(
        inCard('Тест курс нэг', find.text(ContractStrings.download)),
      );
      await tester.pumpAndSettle();

      expect(opened, hasLength(1));
      expect(find.text(ProfileStrings.unexpectedError), findsOneWidget);
    });

    testWidgets('a network failure shows its own copy', (tester) async {
      repository.downloadFailure = const ContractFailure(
        ContractFailureKind.network,
      );
      await pump(tester, [signed]);

      await tester.tap(
        inCard('Тест курс нэг', find.text(ContractStrings.download)),
      );
      await tester.pumpAndSettle();

      expect(find.text(ProfileStrings.networkError), findsOneWidget);
    });

    testWidgets('a signed contract without a document cannot download', (
      tester,
    ) async {
      await pump(tester, [signedWithoutFile]);

      expect(
        action(tester, 'Файлгүй курс', ContractStrings.download),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          label: ContractStrings.download,
        ),
      );
      final label = tester.widget<Text>(
        inCard('Файлгүй курс', find.text(ContractStrings.download)),
      );
      expect(label.style!.color, AppPalette.light.disabledInk);

      await tester.tap(
        inCard('Файлгүй курс', find.text(ContractStrings.download)),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(repository.downloadCalls, isEmpty);
    });
  });

  group('fallbacks — only the contract\'s own fields', () {
    testWidgets('with only a cohort, it is the title and there is no '
        'caption', (tester) async {
      await pump(tester, [
        const StudentContract(
          id: '8',
          status: StudentContractStatus.signed,
          cohort: ContractCohort(name: 'Test Cohort 08'),
        ),
      ]);

      expect(card('Test Cohort 08'), findsOne);
      expect(find.byType(TrackBadge), findsNothing);
    });

    testWidgets('with neither, the contract number is the title', (
      tester,
    ) async {
      await pump(tester, [
        const StudentContract(
          id: '9',
          contractNumber: 'TEST-C-0009',
          status: StudentContractStatus.pending,
        ),
      ]);

      expect(card('TEST-C-0009'), findsOne);
    });
  });

  group('review fixes (PR #313)', () {
    /// The download pill's glyph — the card's only SVG besides the wash.
    SvgPicture downloadGlyph(WidgetTester tester, String title) => tester
        .widgetList<SvgPicture>(inCard(title, find.byType(SvgPicture)))
        .singleWhere(
          (svg) =>
              svg.bytesLoader is SvgAssetLoader &&
              (svg.bytesLoader as SvgAssetLoader).assetName.endsWith(
                'exercise_download.svg',
              ),
        );

    for (final (name, theme, palette) in [
      ('light', AppTheme.light, AppPalette.light),
      ('dark', AppTheme.dark, AppPalette.dark),
    ]) {
      testWidgets('the enabled download glyph takes the theme\'s text '
          'colour ($name) — its SVG strokes are black', (tester) async {
        repository.contracts = [signed];
        useLogicalViewport(
          tester,
          const Size(393, 900),
          padding: iPhonePadding,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: ContractScreen(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          downloadGlyph(tester, 'Тест курс нэг').colorFilter,
          ColorFilter.mode(palette.textPrimary, BlendMode.srcIn),
        );
      });
    }

    testWidgets('no overflow at 2.0× text on a 320pt phone', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(
        tester,
        [signed, pendingSignable, signedWithoutFile],
        withSign: true,
        size: const Size(320, 2400),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ContractCard), findsNWidgets(3));
    });
  });

  testWidgets('many cards scroll, on a small phone too', (tester) async {
    final many = [
      for (var i = 1; i <= 6; i++)
        StudentContract(
          id: '$i',
          status: StudentContractStatus.pending,
          course: ContractCourse(titleMn: 'Курс $i', level: 'adult'),
          cohort: ContractCohort(name: 'Cohort $i'),
        ),
    ];
    await pump(tester, many, size: const Size(320, 568));

    expect(find.text('Курс 6'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Курс 6'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Курс 6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
