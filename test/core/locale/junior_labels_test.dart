import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/home/presentation/widgets/contract_banner.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_learning_map_view.dart';
import 'package:aia_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/junior_home/fake_junior_home_repository.dart';
import '../../features/junior_home/fake_junior_progress_repository.dart';
import '../../support/screenshot.dart';

/// Issue #519: Junior Home and Junior Progress in the selected language.
/// Mongolian reads exactly as before; the design's own English and the
/// English-only screen-reader labels are untouched. The payment card has
/// been in the selected language since Issue #529
/// (`payment_card_labels_test.dart`).
void main() {
  setUpAll(loadAppFonts);
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  /// The approved copy, by key — the ten new keys and the three L8 keys
  /// Junior reuses.
  const copy = <String, ({String mongolian, String english})>{
    'homeEmpty': (
      mongolian: 'Та одоогоор ямар нэг ангид бүртгүүлээгүй байна',
      english: 'You are not enrolled in any class yet',
    ),
    'learningNotEnrolled': (
      mongolian: 'Та энэ хөтөлбөрт бүртгэлгүй байна',
      english: 'You are not enrolled in this program',
    ),
    'learningNotFound': (
      mongolian: 'Хөтөлбөр олдсонгүй',
      english: 'Program not found',
    ),
    'juniorContractTitle': (
      mongolian: 'Гэрээ хийгдээгүй байна',
      english: 'Your contract is not signed yet',
    ),
    'juniorShowParent': (
      mongolian: 'Эцэг эхдээ үзүүлнэ үү 😊',
      english: 'Please show this to your parents 😊',
    ),
    'homeAttendanceLabel': (mongolian: 'Хичээлийн ирц', english: 'Attendance'),
    'juniorExam': (mongolian: 'Шалгалтын дүн', english: 'Exam results'),
    'homeNextLesson': (mongolian: 'Дараагийн хичээл:', english: 'Next lesson:'),
    'juniorLegendTitle': (mongolian: 'Тайлбар:', english: 'Legend:'),
    'juniorLegendHint': (
      mongolian: 'Та хичээлдээ идэвхттэй суугаад тамгаа цуглуулаарай',
      english: 'Attend your lessons actively and collect your stamps',
    ),
    'juniorLessonDay': (mongolian: 'Хичээлтэй өдөр', english: 'Lesson day'),
    'juniorLessonMissed': (
      mongolian: 'Хичээлээ тасалсан',
      english: 'Missed lesson',
    ),
    'juniorLessonAttended': (
      mongolian: 'Хичээлдээ суусан',
      english: 'Attended lesson',
    ),
  };

  String text(String key, LocalePreference language) =>
      language == LocalePreference.mongolian
      ? copy[key]!.mongolian
      : copy[key]!.english;
  String en(String key) => text(key, LocalePreference.english);
  String mn(String key) => text(key, LocalePreference.mongolian);

  Map<String, String> read(AppLocalizations s) => {
    'homeEmpty': s.homeEmpty,
    'learningNotEnrolled': s.learningNotEnrolled,
    'learningNotFound': s.learningNotFound,
    'juniorContractTitle': s.juniorContractTitle,
    'juniorShowParent': s.juniorShowParent,
    'homeAttendanceLabel': s.homeAttendanceLabel,
    'juniorExam': s.juniorExam,
    'homeNextLesson': s.homeNextLesson,
    'juniorLegendTitle': s.juniorLegendTitle,
    'juniorLegendHint': s.juniorLegendHint,
    'juniorLessonDay': s.juniorLessonDay,
    'juniorLessonMissed': s.juniorLessonMissed,
    'juniorLessonAttended': s.juniorLessonAttended,
  };

  /// The payment card's parent line: since Issue #529, the banner's own
  /// `juniorShowParent` key, so it follows the language too.
  const paymentLine = (
    mongolian: 'Эцэг эхдээ үзүүлнэ үү 😊',
    english: 'Please show this to your parents 😊',
  );

  group('the keys', () {
    for (final language in LocalePreference.values) {
      test(language.name, () {
        expect(read(L10n.of(language)), {
          for (final key in copy.keys) key: text(key, language),
        });
      });
    }

    test('read differently from one another in both languages, so a member '
        'wired to the wrong key cannot pass', () {
      expect({
        for (final c in copy.values) c.mongolian,
      }, hasLength(copy.length));
      expect({for (final c in copy.values) c.english}, hasLength(copy.length));
    });
  });

  group('every in-scope member', () {
    final members = <(String, String Function(), String)>[
      ('JuniorHomeStrings.empty', () => JuniorHomeStrings.empty, 'homeEmpty'),
      (
        'JuniorHomeStrings.notEnrolled',
        () => JuniorHomeStrings.notEnrolled,
        'learningNotEnrolled',
      ),
      (
        'JuniorHomeStrings.notFound',
        () => JuniorHomeStrings.notFound,
        'learningNotFound',
      ),
      (
        'JuniorProgressStrings.contractTitle',
        () => JuniorProgressStrings.contractTitle,
        'juniorContractTitle',
      ),
      (
        'JuniorProgressStrings.showParent',
        () => JuniorProgressStrings.showParent,
        'juniorShowParent',
      ),
      (
        'JuniorProgressStrings.attendance',
        () => JuniorProgressStrings.attendance,
        'homeAttendanceLabel',
      ),
      (
        'JuniorProgressStrings.exam',
        () => JuniorProgressStrings.exam,
        'juniorExam',
      ),
      (
        'JuniorProgressStrings.nextLesson',
        () => JuniorProgressStrings.nextLesson,
        'homeNextLesson',
      ),
      (
        'JuniorProgressStrings.legendTitle',
        () => JuniorProgressStrings.legendTitle,
        'juniorLegendTitle',
      ),
      (
        'JuniorProgressStrings.legendHint',
        () => JuniorProgressStrings.legendHint,
        'juniorLegendHint',
      ),
      (
        'JuniorProgressStrings.lessonDay',
        () => JuniorProgressStrings.lessonDay,
        'juniorLessonDay',
      ),
      (
        'JuniorProgressStrings.lessonMissed',
        () => JuniorProgressStrings.lessonMissed,
        'juniorLessonMissed',
      ),
      (
        'JuniorProgressStrings.lessonAttended',
        () => JuniorProgressStrings.lessonAttended,
        'juniorLessonAttended',
      ),
    ];

    test('are all 13', () => expect(members, hasLength(13)));

    for (final language in LocalePreference.values) {
      test(language.name, () async {
        await locale.setPreference(language);
        for (final (name, member, key) in members) {
          expect(member(), text(key, language), reason: name);
        }
      });
    }

    test('what stays out of scope reads the same in English', () async {
      await locale.setEnglish(true);
      // The payment card: in English since Issue #529 (its full coverage is
      // `payment_card_labels_test.dart`).
      expect(JuniorProgressStrings.paymentShowParent, paymentLine.english);
      expect(JuniorProgressStrings.paymentTitle, 'Next payment:');
      expect(JuniorProgressStrings.payAction, 'Pay');
      expect(JuniorProgressStrings.paymentDueIn(3), '3 days left');
      // The English-only screen-reader labels, unchanged.
      expect(JuniorHomeStrings.learningMap, 'Learning map');
      expect(JuniorProgressStrings.previousMonth, 'Previous month');
      expect(JuniorProgressStrings.nextMonth, 'Next month');
    });
  });

  Widget scoped(Widget child) => L10nRebuildScope(
    child: MaterialApp(theme: AppTheme.light, home: child),
  );

  Future<FakeJuniorHomeRepository> pumpHome(
    WidgetTester tester, {
    FakeJuniorHomeRepository? repository,
    Size size = const Size(393, 852),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    useReducedMotion(tester);
    final repo = repository ?? FakeJuniorHomeRepository();
    await tester.pumpWidget(
      scoped(
        JuniorHomeScreen(
          repository: repo,
          clock: () => DateTime(2026, 10, 6, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<FakeJuniorProgressRepository> pumpProgress(
    WidgetTester tester, {
    FakeJuniorProgressRepository? repository,
    Size size = const Size(393, 852),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    final repo = repository ?? FakeJuniorProgressRepository();
    await tester.pumpWidget(scoped(JuniorProgressScreen(repository: repo)));
    await tester.pumpAndSettle();
    return repo;
  }

  group('Junior Home in English', () {
    setUp(() => locale.setEnglish(true));

    testWidgets('the map draws; its screen-reader label is unchanged', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpHome(tester);

      expect(find.byType(JuniorLearningMapView), findsOneWidget);
      expect(find.bySemanticsLabel('Learning map'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('enrolled in nothing: the empty line', (tester) async {
      await pumpHome(tester, repository: FakeJuniorHomeRepository(empty: true));

      expect(find.text(en('homeEmpty')), findsOneWidget);
      expect(find.text(mn('homeEmpty')), findsNothing);
    });

    for (final (kind, key) in [
      (CourseLearningFailureKind.notEnrolled, 'learningNotEnrolled'),
      (CourseLearningFailureKind.notFound, 'learningNotFound'),
    ]) {
      testWidgets('a ${kind.name} failure: its English line and Try again', (
        tester,
      ) async {
        await pumpHome(
          tester,
          repository: FakeJuniorHomeRepository(
            failure: CourseLearningFailure(kind),
          ),
        );

        expect(find.text(en(key)), findsOneWidget);
        expect(find.text('Try again.'), findsOneWidget);
        expect(find.byType(JuniorLearningMapView), findsNothing);
      });
    }
  });

  group('Junior Progress in English', () {
    setUp(() => locale.setEnglish(true));

    testWidgets('the contract banner, attendance and exam cards, and the '
        'legend', (tester) async {
      await pumpProgress(tester);

      final banner = find.byType(ContractBanner);
      expect(
        find.descendant(
          of: banner,
          matching: find.text(en('juniorContractTitle')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: banner,
          matching: find.text(en('juniorShowParent')),
        ),
        findsOneWidget,
      );
      for (final key in [
        'homeAttendanceLabel',
        'juniorExam',
        'homeNextLesson',
        'juniorLegendTitle',
        'juniorLegendHint',
        'juniorLessonDay',
        'juniorLessonMissed',
        'juniorLessonAttended',
      ]) {
        final label = find.text(en(key));
        if (label.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            label,
            100,
            scrollable: find.byType(Scrollable).first,
          );
        }
        expect(label, findsOneWidget, reason: key);
      }
    });

    testWidgets('the payment card\'s parent line reads in English too, as '
        'the banner\'s does (Issue #529)', (tester) async {
      await pumpProgress(tester);

      // Once under the banner, once on the payment card; no Mongolian left.
      expect(find.text(paymentLine.english), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(ContractBanner),
          matching: find.text(paymentLine.english),
        ),
        findsOneWidget,
      );
      expect(find.text(paymentLine.mongolian), findsNothing);
    });

    testWidgets('the calendar announces each marked day in English', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpProgress(tester);

      for (final key in [
        'juniorLessonDay',
        'juniorLessonMissed',
        'juniorLessonAttended',
      ]) {
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(en(key)))),
          findsWidgets,
          reason: key,
        );
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(mn(key)))),
          findsNothing,
          reason: key,
        );
      }
      semantics.dispose();
    });
  });

  testWidgets('switching language on mounted Junior Home: the empty line '
      'changes; nothing reloads', (tester) async {
    final repository = await pumpHome(
      tester,
      repository: FakeJuniorHomeRepository(empty: true),
    );
    final state = tester.state(find.byType(JuniorHomeScreen));
    final loads = repository.calls;
    expect(find.text(mn('homeEmpty')), findsOneWidget);

    await locale.setEnglish(true);
    await tester.pump();

    expect(find.text(en('homeEmpty')), findsOneWidget);
    expect(find.text(mn('homeEmpty')), findsNothing);
    expect(tester.state(find.byType(JuniorHomeScreen)), same(state));
    expect(repository.calls, loads);

    await locale.setEnglish(false);
    await tester.pump();
    expect(find.text(mn('homeEmpty')), findsOneWidget);
  });

  testWidgets('switching language on mounted Junior Progress: every label '
      'changes; the screen, its scroll and its data stay', (tester) async {
    final repository = await pumpProgress(tester);
    final state = tester.state(find.byType(JuniorProgressScreen));
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ContractBanner), const Offset(0, -120));
    await tester.pumpAndSettle();
    final offset = scrollable.position.pixels;
    expect(offset, greaterThan(0));
    final loads = repository.callCount;

    await locale.setEnglish(true);
    await tester.pump();

    // The payment card's parent line follows the language too (Issue #529),
    // so no Mongolian line of this screen is left, and the banner's own line
    // is still checked inside the banner.
    for (final key in copy.keys.where(
      (k) => !k.startsWith('learning') && k != 'homeEmpty',
    )) {
      expect(find.text(mn(key)), findsNothing, reason: key);
    }
    expect(
      find.descendant(
        of: find.byType(ContractBanner),
        matching: find.text(en('juniorShowParent')),
      ),
      findsOneWidget,
    );
    expect(find.text(en('juniorContractTitle')), findsOneWidget);
    expect(find.text(en('homeAttendanceLabel')), findsOneWidget);
    // The payment card's line is now the English one (Issue #529).
    expect(find.text(paymentLine.english), findsNWidgets(2));
    expect(find.text(paymentLine.mongolian), findsNothing);
    expect(tester.state(find.byType(JuniorProgressScreen)), same(state));
    expect(scrollable.position.pixels, offset);
    expect(repository.callCount, loads);

    await locale.setEnglish(false);
    await tester.pump();
    expect(find.text(mn('juniorContractTitle')), findsOneWidget);
  });

  group('English at 2.0× text on a 320 pt phone', () {
    /// Lays out [screen] in [language] and returns the keys among [keys] cut
    /// short, after checking each is on screen and inside the width.
    Future<Set<String>> cutShort(
      WidgetTester tester,
      LocalePreference language,
      List<String> keys,
      Future<void> Function() pump,
    ) async {
      await locale.setPreference(language);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      // A fresh tree: nothing carried over from the other language's pass.
      await tester.pumpWidget(const SizedBox());
      await pump();
      expect(tester.takeException(), isNull);
      final cut = <String>{};
      for (final key in keys) {
        final label = find.text(text(key, language));
        // Built lazily further down a scroll view, or already on screen (a
        // state message has nothing to scroll).
        if (label.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            label.first,
            100,
            scrollable: find.byType(Scrollable).first,
          );
        }
        expect(label, findsWidgets, reason: key);
        for (final element in label.evaluate()) {
          final one = find.byWidget(element.widget);
          await tester.ensureVisible(one);
          await tester.pumpAndSettle();
          final rect = tester.getRect(one);
          expect(rect.left, greaterThanOrEqualTo(0), reason: key);
          expect(rect.right, lessThanOrEqualTo(320), reason: key);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: one, matching: find.byType(RichText)).first,
          );
          if (paragraph.didExceedMaxLines) cut.add(key);
        }
      }
      expect(tester.takeException(), isNull);
      return cut;
    }

    testWidgets('Junior Progress: no overflow, nothing cut short that '
        'Mongolian is not', (tester) async {
      const keys = [
        'juniorContractTitle',
        'juniorShowParent',
        'homeAttendanceLabel',
        'juniorExam',
        'homeNextLesson',
        'juniorLegendTitle',
        'juniorLegendHint',
        'juniorLessonDay',
        'juniorLessonMissed',
        'juniorLessonAttended',
      ];
      Future<void> pump() => pumpProgress(tester, size: const Size(320, 568));
      final mongolian = await cutShort(
        tester,
        LocalePreference.mongolian,
        keys,
        pump,
      );
      final english = await cutShort(
        tester,
        LocalePreference.english,
        keys,
        pump,
      );
      expect(english.difference(mongolian), isEmpty);
    });

    testWidgets('Junior Home: the empty and error lines — no overflow, '
        'nothing cut short that Mongolian is not', (tester) async {
      for (final (repository, key) in [
        (() => FakeJuniorHomeRepository(empty: true), 'homeEmpty'),
        (
          () => FakeJuniorHomeRepository(
            failure: const CourseLearningFailure(
              CourseLearningFailureKind.notEnrolled,
            ),
          ),
          'learningNotEnrolled',
        ),
        (
          () => FakeJuniorHomeRepository(
            failure: const CourseLearningFailure(
              CourseLearningFailureKind.notFound,
            ),
          ),
          'learningNotFound',
        ),
      ]) {
        Future<void> pump() => pumpHome(
          tester,
          repository: repository(),
          size: const Size(320, 568),
        );
        final mongolian = await cutShort(tester, LocalePreference.mongolian, [
          key,
        ], pump);
        final english = await cutShort(tester, LocalePreference.english, [
          key,
        ], pump);
        expect(english.difference(mongolian), isEmpty, reason: key);
      }
    });
  });
}
