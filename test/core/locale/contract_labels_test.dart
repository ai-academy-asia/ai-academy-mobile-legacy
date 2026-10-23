import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/contracts/domain/contract_detail.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_screen.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_strings.dart';
import 'package:aia_mobile/features/contracts/presentation/widgets/contract_card.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/presentation/home_screen.dart';
import 'package:aia_mobile/features/home/presentation/widgets/contract_banner.dart';
import 'package:aia_mobile/features/profile/presentation/profile_screen.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/auth/fake_auth_repository.dart';
import '../../features/contracts/fake_contract_repository.dart';
import '../../features/home/fake_home_dashboard_repository.dart';
import '../../features/profile/fake_current_user_repository.dart';
import '../../support/screenshot.dart';

/// Issue #527: the E-Contract list's empty line, status pills and actions in
/// the selected language. Mongolian reads exactly as before; the bilingual
/// title and the signing flow are untouched, and signing stays off.
void main() {
  setUpAll(loadAppFonts);
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  const copy = <String, ({String mongolian, String english})>{
    'contractEmpty': (
      mongolian: 'Одоогоор гэрээ алга байна',
      english: 'No contracts yet',
    ),
    'contractStatusSigned': (mongolian: 'Гэрээ байгуулсан', english: 'Signed'),
    'contractStatusPending': (
      mongolian: 'Гэрээ хийгдээгүй байна',
      english: 'Not signed yet',
    ),
    // "Download contract" was cut short at 2.0× on a 320 pt phone where the
    // Mongolian is not, so the approved fallback (Issue #527).
    'contractDownload': (mongolian: 'Гэрээ татах', english: 'Download'),
    'contractSign': (mongolian: 'Гэрээ байгуулах', english: 'Sign contract'),
  };

  String text(String key, LocalePreference language) =>
      language == LocalePreference.mongolian
      ? copy[key]!.mongolian
      : copy[key]!.english;

  String en(String key) => text(key, LocalePreference.english);
  String mn(String key) => text(key, LocalePreference.mongolian);

  group('the keys', () {
    for (final language in LocalePreference.values) {
      test(language.name, () {
        final s = L10n.of(language);
        expect(
          {
            'contractEmpty': s.contractEmpty,
            'contractStatusSigned': s.contractStatusSigned,
            'contractStatusPending': s.contractStatusPending,
            'contractDownload': s.contractDownload,
            'contractSign': s.contractSign,
          },
          {for (final key in copy.keys) key: text(key, language)},
        );
      });
    }

    test('the pending pill is its own short key, not the banner\'s '
        'sentence', () {
      final english = L10n.of(LocalePreference.english);
      final mongolian = L10n.of(LocalePreference.mongolian);
      expect(mongolian.contractStatusPending, mongolian.juniorContractTitle);
      expect(english.contractStatusPending, isNot(english.juniorContractTitle));
    });

    for (final language in LocalePreference.values) {
      test('ContractStrings in ${language.name}', () async {
        await locale.setPreference(language);
        expect(ContractStrings.empty, text('contractEmpty', language));
        expect(
          ContractStrings.statusSigned,
          text('contractStatusSigned', language),
        );
        expect(
          ContractStrings.statusPending,
          text('contractStatusPending', language),
        );
        expect(ContractStrings.download, text('contractDownload', language));
        expect(ContractStrings.sign, text('contractSign', language));
        // Out of scope: the bilingual title reads the same in both.
        expect(ContractStrings.title, 'Гэрээ · E-Contract');
      });
    }
  });

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

  /// Signable by the server — but `ContractScreen.open` passes no `onSign`,
  /// so its action is drawn disabled.
  const pending = StudentContract(
    id: '2',
    contractNumber: 'TEST-C-0002',
    status: StudentContractStatus.pending,
    course: ContractCourse(id: 10, titleEn: 'Test course two', level: 'junior'),
    cohort: ContractCohort(id: 4, name: 'Test Cohort 02'),
    canView: true,
    canSign: true,
    isCurrent: true,
  );

  late FakeContractRepository repository;
  late List<Uri> opened;

  setUp(() {
    repository = FakeContractRepository();
    opened = [];
  });

  /// The list as the tests drive it, under the language rebuild scope.
  Future<void> pumpList(
    WidgetTester tester,
    List<StudentContract> contracts, {
    Size size = const Size(393, 1800),
  }) async {
    repository.contracts = contracts;
    useLogicalViewport(tester, size, padding: iPhonePadding);
    // A fresh tree: nothing carried over from an earlier pump.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: ContractScreen(
            repository: repository,
            openUrl: (url) async {
              opened.add(url);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder card(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(ContractCard));

  Finder inCard(String title, Finder finder) =>
      find.descendant(of: card(title), matching: finder);

  group('in English', () {
    setUp(() => locale.setEnglish(true));

    testWidgets('no contracts: "No contracts yet"', (tester) async {
      await pumpList(tester, const []);

      expect(find.text(en('contractEmpty')), findsOneWidget);
      expect(find.text(mn('contractEmpty')), findsNothing);
      expect(find.byType(ContractCard), findsNothing);
    });

    testWidgets('a signed card reads Signed / Download, a pending '
        'one Not signed yet / Sign contract', (tester) async {
      await pumpList(tester, const [signed, pending]);

      expect(
        inCard('Test course one', find.text(en('contractStatusSigned'))),
        findsOneWidget,
      );
      expect(
        inCard('Test course one', find.text(en('contractDownload'))),
        findsOneWidget,
      );
      expect(
        inCard('Test course two', find.text(en('contractStatusPending'))),
        findsOneWidget,
      );
      expect(
        inCard('Test course two', find.text(en('contractSign'))),
        findsOneWidget,
      );
      for (final key in copy.keys) {
        expect(find.text(mn(key)), findsNothing, reason: key);
      }
      // The bilingual title is unchanged.
      expect(find.text('Гэрээ · E-Contract'), findsOneWidget);
    });

    testWidgets('Download still fetches a fresh link and opens it', (
      tester,
    ) async {
      repository.downloads.add(
        ContractDownload(
          url: Uri.parse('https://files.example.test/first.pdf'),
          expiresAt: DateTime.utc(2026, 10, 11, 3, 5),
        ),
      );
      await pumpList(tester, const [signed]);

      await tester.tap(
        inCard('Test course one', find.text(en('contractDownload'))),
      );
      await tester.pumpAndSettle();

      expect(repository.downloadCalls, ['1']);
      expect(opened, [Uri.parse('https://files.example.test/first.pdf')]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Sign contract stays disabled: nothing is asked of the API', (
      tester,
    ) async {
      await pumpList(tester, const [pending]);

      expect(
        tester.getSemantics(
          inCard('Test course two', find.bySemanticsLabel(en('contractSign'))),
        ),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          label: en('contractSign'),
        ),
      );
      await tester.tap(
        inCard('Test course two', find.text(en('contractSign'))),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(repository.detailCalls, isEmpty);
      expect(repository.signCalls, isEmpty);
    });

    testWidgets('opened from the Adult Profile\'s E-Contract row, the list '
        'reads in English and its Sign is disabled', (tester) async {
      repository.contracts = const [pending];
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      await tester.pumpWidget(
        L10nRebuildScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: ProfileScreen(
              repository: FakeCurrentUserRepository(hold: true),
              authRepository: FakeAuthRepository(),
              sessionStore: AuthSessionStore()
                ..save(const AuthSession(accessToken: 'tok')),
              contractRepository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(ProfileStrings.eContract));
      await tester.pumpAndSettle();

      expect(find.byType(ContractScreen), findsOneWidget);
      expect(repository.callCount, 1);
      expect(find.text(en('contractStatusPending')), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(en('contractSign'))),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          label: en('contractSign'),
        ),
      );
    });

    testWidgets('opened from Adult Home\'s contract banner, the empty list '
        'reads in English', (tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      await tester.pumpWidget(
        L10nRebuildScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: HomeScreen(
              repository: FakeHomeDashboardRepository(
                dashboard: HomeDashboard(
                  program: sampleProgram(),
                  contract: const ContractStatus(signed: false),
                ),
              ),
              clock: () => DateTime(2026, 4, 8, 7),
              showPaymentPreview: false,
              contractRepository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ContractBanner));
      await tester.pumpAndSettle();

      expect(find.byType(ContractScreen), findsOneWidget);
      expect(repository.callCount, 1);
      expect(find.text(en('contractEmpty')), findsOneWidget);
      expect(find.text(mn('contractEmpty')), findsNothing);
    });
  });

  testWidgets('switching language on the open list: every label changes, the '
      'screen keeps its state and nothing is fetched again', (tester) async {
    await pumpList(tester, const [signed, pending]);
    for (final key in copy.keys.where((k) => k != 'contractEmpty')) {
      expect(find.text(mn(key)), findsOneWidget, reason: key);
    }
    final state = tester.state(find.byType(ContractScreen));
    final calls = repository.callCount;

    await locale.setEnglish(true);
    await tester.pump();

    for (final key in copy.keys.where((k) => k != 'contractEmpty')) {
      expect(find.text(en(key)), findsOneWidget, reason: key);
      expect(find.text(mn(key)), findsNothing, reason: key);
    }
    expect(tester.state(find.byType(ContractScreen)), same(state));
    expect(repository.callCount, calls);

    await locale.setPreference(LocalePreference.mongolian);
    await tester.pump();
    expect(find.text(mn('contractDownload')), findsOneWidget);
  });

  testWidgets('switching language on the empty list changes its line', (
    tester,
  ) async {
    await pumpList(tester, const []);
    expect(find.text(mn('contractEmpty')), findsOneWidget);
    final calls = repository.callCount;

    await locale.setEnglish(true);
    await tester.pump();

    expect(find.text(en('contractEmpty')), findsOneWidget);
    expect(repository.callCount, calls);
  });

  // --- Large text -------------------------------------------------------------

  const width = 320.0;
  const height = 1200.0;

  for (final (name, contracts, keys) in [
    ('the empty list', const <StudentContract>[], ['contractEmpty']),
    (
      'a signed and a pending card',
      const [signed, pending],
      [
        'contractStatusSigned',
        'contractDownload',
        'contractStatusPending',
        'contractSign',
      ],
    ),
  ]) {
    testWidgets('$name: English at 2.0× text on a 320 pt phone has no '
        'overflow, every line whole and inside the screen, nothing cut '
        'short that Mongolian is not', (tester) async {
      Future<Set<String>> cutShort(LocalePreference language) async {
        await locale.setPreference(language);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpList(tester, contracts, size: const Size(width, height));
        expect(tester.takeException(), isNull);

        final cut = <String>{};
        for (final key in keys) {
          final label = find.text(text(key, language));
          expect(label, findsOneWidget, reason: key);
          final rect = tester.getRect(label);
          expect(rect.left, greaterThanOrEqualTo(0), reason: key);
          expect(rect.right, lessThanOrEqualTo(width), reason: key);
          expect(rect.top, greaterThanOrEqualTo(0), reason: key);
          expect(rect.bottom, lessThanOrEqualTo(height), reason: key);

          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: label, matching: find.byType(RichText)).first,
          );
          if (paragraph.didExceedMaxLines) cut.add(key);
          // Drawn at its full height: nothing clipped.
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(
              paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
            ),
            reason: key,
          );
          // A card's labels stay inside their card.
          final owner = find.ancestor(
            of: label,
            matching: find.byType(ContractCard),
          );
          if (owner.evaluate().isNotEmpty) {
            final cardRect = tester.getRect(owner);
            expect(rect.left, greaterThanOrEqualTo(cardRect.left), reason: key);
            expect(rect.right, lessThanOrEqualTo(cardRect.right), reason: key);
            expect(
              rect.bottom,
              lessThanOrEqualTo(cardRect.bottom),
              reason: key,
            );
          }
        }
        expect(tester.takeException(), isNull);
        return cut;
      }

      final mongolian = await cutShort(LocalePreference.mongolian);
      final english = await cutShort(LocalePreference.english);
      expect(english.difference(mongolian), isEmpty);
    });
  }
}
