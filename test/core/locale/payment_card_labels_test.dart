import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/presentation/home_screen.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/home/presentation/widgets/payment_card.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_strings.dart';
import 'package:aia_mobile/features/payments/presentation/payment_strings.dart';
import 'package:aia_mobile/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/home/fake_home_dashboard_repository.dart';
import '../../features/junior_home/fake_junior_progress_repository.dart';
import '../../support/screenshot.dart';

/// Issue #529: the payment card on Adult Home and on Junior Progress in the
/// selected language. Mongolian reads exactly as before — "Дараанийн" is the
/// design's own spelling — and the debug-only Payment screen is untouched.
void main() {
  setUpAll(loadAppFonts);
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  const copy = <String, ({String mongolian, String english})>{
    'paymentNext': (mongolian: 'Дараанийн төлөлт', english: 'Next payment'),
    'juniorPaymentTitle': (
      mongolian: 'Дараанийн төлөлт:',
      english: 'Next payment:',
    ),
    'paymentOverdue': (mongolian: 'Хугацаа хэтэрсэн', english: 'Overdue'),
    'paymentPayAction': (mongolian: 'Төлбөр төлөх', english: 'Pay'),
    'juniorShowParent': (
      mongolian: 'Эцэг эхдээ үзүүлнэ үү 😊',
      english: 'Please show this to your parents 😊',
    ),
  };

  /// `paymentDueIn(days)`, exactly, in each language.
  const dueIn = <int, ({String mongolian, String english})>{
    0: (mongolian: '0 хоног дутуу', english: '0 days left'),
    1: (mongolian: '1 хоног дутуу', english: '1 day left'),
    2: (mongolian: '2 хоног дутуу', english: '2 days left'),
    3: (mongolian: '3 хоног дутуу', english: '3 days left'),
    21: (mongolian: '21 хоног дутуу', english: '21 days left'),
  };

  String pick(
    ({String mongolian, String english}) entry,
    LocalePreference language,
  ) => language == LocalePreference.mongolian ? entry.mongolian : entry.english;

  String text(String key, LocalePreference language) =>
      pick(copy[key]!, language);
  String en(String key) => text(key, LocalePreference.english);
  String mn(String key) => text(key, LocalePreference.mongolian);
  String due(int days, LocalePreference language) =>
      pick(dueIn[days]!, language);

  group('the keys', () {
    for (final language in LocalePreference.values) {
      test(language.name, () {
        final s = L10n.of(language);
        expect(
          {
            'paymentNext': s.paymentNext,
            'juniorPaymentTitle': s.juniorPaymentTitle,
            'paymentOverdue': s.paymentOverdue,
            'paymentPayAction': s.paymentPayAction,
            'juniorShowParent': s.juniorShowParent,
          },
          {for (final key in copy.keys) key: text(key, language)},
        );
      });

      test('paymentDueIn at 0, 1, 2 and 21 in ${language.name}', () {
        final s = L10n.of(language);
        for (final days in [0, 1, 2, 21]) {
          expect(s.paymentDueIn(days), due(days, language), reason: '$days');
        }
      });

      test('the strings members in ${language.name}', () async {
        await locale.setPreference(language);
        expect(HomeStrings.paymentLabel, text('paymentNext', language));
        expect(HomeStrings.paymentOverdue, text('paymentOverdue', language));
        expect(HomeStrings.payAction, text('paymentPayAction', language));
        expect(
          JuniorProgressStrings.paymentTitle,
          text('juniorPaymentTitle', language),
        );
        expect(
          JuniorProgressStrings.paymentOverdue,
          text('paymentOverdue', language),
        );
        expect(
          JuniorProgressStrings.payAction,
          text('paymentPayAction', language),
        );
        expect(
          JuniorProgressStrings.paymentShowParent,
          text('juniorShowParent', language),
        );
        // The parent line is the banner's own key, not a copy of it.
        expect(
          JuniorProgressStrings.paymentShowParent,
          JuniorProgressStrings.showParent,
        );
        for (final days in [0, 1, 2, 21]) {
          expect(HomeStrings.paymentDueIn(days), due(days, language));
          expect(JuniorProgressStrings.paymentDueIn(days), due(days, language));
        }
      });
    }

    test(
      'the debug-only Payment screen keeps its Mongolian (out of scope)',
      () async {
        await locale.setEnglish(true);
        expect(PaymentStrings.payAction, 'Төлбөр төлөх');
        expect(PaymentStrings.overdue, 'Хугацаа хэтэрсэн');
        expect(PaymentStrings.dueIn(3), '3 хоног дутуу');
      },
    );
  });

  // --- Adult Home -----------------------------------------------------------

  Future<FakeHomeDashboardRepository> pumpHome(
    WidgetTester tester,
    PaymentStat stat, {
    Size size = const Size(393, 852),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    final repository = FakeHomeDashboardRepository(
      dashboard: HomeDashboard(program: sampleProgram(), stats: [stat]),
    );
    // A fresh tree: nothing carried over from an earlier pump.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: HomeScreen(
            repository: repository,
            clock: () => DateTime(2026, 4, 8, 8),
            // As in a release build: the Payment screen is debug-only.
            showPaymentPreview: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  const dueTile = PaymentStat(
    PaymentStatus.dueIn(3),
    layout: HomeStatLayout.tile,
  );
  const overdueTile = PaymentStat(
    PaymentStatus.overdue(),
    layout: HomeStatLayout.tile,
  );
  const dueRow = PaymentStat(
    PaymentStatus.dueIn(3),
    layout: HomeStatLayout.row,
  );

  Finder inPaymentCard(Finder finder) =>
      find.descendant(of: find.byType(PaymentCard), matching: finder);

  PillButton pill(WidgetTester tester, String label) =>
      tester.widget<PillButton>(find.widgetWithText(PillButton, label));

  group('Adult Home in English', () {
    setUp(() => locale.setEnglish(true));

    testWidgets('a due tile: Next payment, 3 days left, and Pay muted as '
        'before', (tester) async {
      await pumpHome(tester, dueTile);

      expect(inPaymentCard(find.text(en('paymentNext'))), findsOneWidget);
      expect(
        inPaymentCard(find.text(due(3, LocalePreference.english))),
        findsOneWidget,
      );
      expect(inPaymentCard(find.text(en('paymentPayAction'))), findsOneWidget);
      expect(pill(tester, en('paymentPayAction')).onPressed, isNull);
      for (final key in ['paymentNext', 'paymentPayAction']) {
        expect(find.text(mn(key)), findsNothing, reason: key);
      }
      expect(find.text(due(3, LocalePreference.mongolian)), findsNothing);
    });

    testWidgets('an overdue tile: Overdue, and Pay live as before', (
      tester,
    ) async {
      await pumpHome(tester, overdueTile);

      expect(inPaymentCard(find.text(en('paymentNext'))), findsOneWidget);
      expect(inPaymentCard(find.text(en('paymentOverdue'))), findsOneWidget);
      expect(find.text(mn('paymentOverdue')), findsNothing);
      // Live, with no destination in a release build — unchanged.
      expect(pill(tester, en('paymentPayAction')).onPressed, isNotNull);
      await tester.tap(find.widgetWithText(PillButton, en('paymentPayAction')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('a row: Next payment and 3 days left, with Details and no '
        'Pay, as before', (tester) async {
      await pumpHome(tester, dueRow);

      expect(inPaymentCard(find.text(en('paymentNext'))), findsOneWidget);
      expect(
        inPaymentCard(find.text(due(3, LocalePreference.english))),
        findsOneWidget,
      );
      expect(inPaymentCard(find.text(en('paymentPayAction'))), findsNothing);
      expect(
        tester
            .widget<PillButton>(
              inPaymentCard(find.widgetWithText(PillButton, 'Details')),
            )
            .onPressed,
        isNotNull,
      );
    });
  });

  testWidgets('switching language on Adult Home: the payment card changes, '
      'the screen stays, nothing is fetched again', (tester) async {
    final repository = await pumpHome(tester, dueTile);
    expect(find.text(mn('paymentNext')), findsOneWidget);
    final state = tester.state(find.byType(HomeScreen));
    final loads = repository.callCount;

    await locale.setEnglish(true);
    await tester.pump();

    expect(find.text(en('paymentNext')), findsOneWidget);
    expect(find.text(due(3, LocalePreference.english)), findsOneWidget);
    expect(find.text(en('paymentPayAction')), findsOneWidget);
    expect(find.text(mn('paymentNext')), findsNothing);
    expect(tester.state(find.byType(HomeScreen)), same(state));
    expect(repository.callCount, loads);

    await locale.setPreference(LocalePreference.mongolian);
    await tester.pump();
    expect(find.text(due(3, LocalePreference.mongolian)), findsOneWidget);
  });

  // --- Junior Progress ------------------------------------------------------

  Future<FakeJuniorProgressRepository> pumpProgress(
    WidgetTester tester, {
    PaymentStatus payment = const PaymentStatus.dueIn(3),
    bool withContract = true,
    Size size = const Size(393, 852),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    final repository = FakeJuniorProgressRepository(
      progress: figmaReferenceProgress(
        payment: payment,
        contract: withContract ? const ContractStatus(signed: false) : null,
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: JuniorProgressScreen(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  group('Junior Progress in English', () {
    setUp(() => locale.setEnglish(true));

    testWidgets('a due card: Next payment:, the parent line, 3 days left and '
        'Pay, read out as Pay', (tester) async {
      final semantics = tester.ensureSemantics();
      // No contract banner, so the parent line on screen is the card's.
      await pumpProgress(tester, withContract: false);

      expect(find.text(en('juniorPaymentTitle')), findsOneWidget);
      expect(find.text(en('juniorShowParent')), findsOneWidget);
      expect(find.text(due(3, LocalePreference.english)), findsOneWidget);
      expect(find.text(en('paymentPayAction')), findsOneWidget);
      for (final key in copy.keys) {
        expect(find.text(mn(key)), findsNothing, reason: key);
      }
      // The pill is announced by its label, a button with a tap — as before.
      expect(
        tester.getSemantics(find.bySemanticsLabel(en('paymentPayAction'))),
        matchesSemantics(
          label: en('paymentPayAction'),
          isButton: true,
          hasTapAction: true,
        ),
      );
      // Its tap still leads nowhere.
      await tester.tap(find.text(en('paymentPayAction')));
      await tester.pumpAndSettle();
      expect(find.byType(JuniorProgressScreen), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('an overdue card: Overdue', (tester) async {
      await pumpProgress(tester, payment: const PaymentStatus.overdue());

      expect(find.text(en('paymentOverdue')), findsOneWidget);
      expect(find.text(mn('paymentOverdue')), findsNothing);
      expect(find.text(en('juniorPaymentTitle')), findsOneWidget);
    });
  });

  testWidgets('switching language on Junior Progress: the payment card '
      'changes, the screen stays, nothing is fetched again', (tester) async {
    final repository = await pumpProgress(tester, withContract: false);
    expect(find.text(mn('juniorPaymentTitle')), findsOneWidget);
    final state = tester.state(find.byType(JuniorProgressScreen));
    final loads = repository.callCount;

    await locale.setEnglish(true);
    await tester.pump();

    for (final key in [
      'juniorPaymentTitle',
      'juniorShowParent',
      'paymentPayAction',
    ]) {
      expect(find.text(en(key)), findsOneWidget, reason: key);
      expect(find.text(mn(key)), findsNothing, reason: key);
    }
    expect(find.text(due(3, LocalePreference.english)), findsOneWidget);
    expect(tester.state(find.byType(JuniorProgressScreen)), same(state));
    expect(repository.callCount, loads);
  });

  // The pay pill used to be a fixed 36 tall, which cropped its label at
  // 2.0× in both languages; it is now at least 36 (Issue #529).
  for (final language in LocalePreference.values) {
    testWidgets('the Junior pay pill is 36 tall at 1.0× and grows to its '
        'label at 2.0×, in ${language.name}', (tester) async {
      await locale.setPreference(language);
      final label = find.text(text('paymentPayAction', language));
      Size pill() => tester.getSize(
        find.ancestor(of: label, matching: find.byType(InkWell)).first,
      );

      await pumpProgress(tester, withContract: false);
      expect(pill().height, 36);

      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpProgress(
        tester,
        withContract: false,
        size: const Size(320, 2400),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: label, matching: find.byType(RichText)).first,
      );
      expect(pill().height, greaterThan(36));
      expect(pill().height, greaterThanOrEqualTo(paragraph.size.height));
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  // --- Large text -------------------------------------------------------------

  const width = 320.0;
  const height = 2400.0;

  /// The labels each case measures, by language.
  final cases =
      <
        ({
          String name,
          List<String Function(LocalePreference)> labels,
          Future<void> Function(WidgetTester) pump,
        })
      >[
        (
          name: 'Adult tile, due',
          labels: [
            (l) => text('paymentNext', l),
            (l) => due(3, l),
            (l) => text('paymentPayAction', l),
          ],
          pump: (tester) =>
              pumpHome(tester, dueTile, size: const Size(width, height)),
        ),
        (
          name: 'Adult tile, overdue',
          labels: [
            (l) => text('paymentNext', l),
            (l) => text('paymentOverdue', l),
            (l) => text('paymentPayAction', l),
          ],
          pump: (tester) =>
              pumpHome(tester, overdueTile, size: const Size(width, height)),
        ),
        (
          name: 'Adult row, 21 days',
          labels: [(l) => text('paymentNext', l), (l) => due(21, l)],
          pump: (tester) => pumpHome(
            tester,
            const PaymentStat(
              PaymentStatus.dueIn(21),
              layout: HomeStatLayout.row,
            ),
            size: const Size(width, height),
          ),
        ),
        (
          name: 'Junior card, due',
          labels: [
            (l) => text('juniorPaymentTitle', l),
            (l) => text('juniorShowParent', l),
            (l) => due(3, l),
            (l) => text('paymentPayAction', l),
          ],
          pump: (tester) => pumpProgress(
            tester,
            withContract: false,
            size: const Size(width, height),
          ),
        ),
        (
          name: 'Junior card, overdue',
          labels: [
            (l) => text('juniorPaymentTitle', l),
            (l) => text('paymentOverdue', l),
            (l) => text('paymentPayAction', l),
          ],
          pump: (tester) => pumpProgress(
            tester,
            payment: const PaymentStatus.overdue(),
            withContract: false,
            size: const Size(width, height),
          ),
        ),
      ];

  for (final c in cases) {
    testWidgets('${c.name}: English at 2.0× text on a 320 pt phone has no '
        'overflow, every line whole and inside the screen, nothing cut short '
        'that Mongolian is not', (tester) async {
      Future<Set<int>> cutShort(LocalePreference language) async {
        await locale.setPreference(language);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await c.pump(tester);
        expect(tester.takeException(), isNull);

        final cut = <int>{};
        for (var i = 0; i < c.labels.length; i++) {
          final value = c.labels[i](language);
          final label = find.text(value);
          expect(label, findsOneWidget, reason: value);
          final rect = tester.getRect(label);
          expect(rect.left, greaterThanOrEqualTo(0), reason: value);
          expect(rect.right, lessThanOrEqualTo(width), reason: value);
          expect(rect.top, greaterThanOrEqualTo(0), reason: value);
          expect(rect.bottom, lessThanOrEqualTo(height), reason: value);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: label, matching: find.byType(RichText)).first,
          );
          if (paragraph.didExceedMaxLines) cut.add(i);
          // Drawn at its full height: nothing clipped.
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(
              paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
            ),
            reason: value,
          );
        }
        expect(tester.takeException(), isNull);
        return cut;
      }

      final mongolian = await cutShort(LocalePreference.mongolian);
      final english = await cutShort(LocalePreference.english);
      expect(
        english
            .difference(mongolian)
            .map((i) => c.labels[i](LocalePreference.english)),
        isEmpty,
      );
    });
  }
}
