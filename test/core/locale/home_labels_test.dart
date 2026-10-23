import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/presentation/attendance_detail_screen.dart';
import 'package:aia_mobile/features/home/presentation/home_screen.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/home/presentation/widgets/contract_banner.dart';
import 'package:aia_mobile/features/home/presentation/widgets/program_card.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_strings.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_center.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/l10n/app_localizations.dart';
import 'package:aia_mobile/shared/widgets/back_title_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/home/fake_home_dashboard_repository.dart';
import '../../features/notifications/fake_notification_repository.dart';
import '../../support/screenshot.dart';

/// Issue #517: the Adult Home dashboard and its Attendance detail screen in
/// the selected language. Mongolian reads exactly as before; the design's
/// own English is untouched. The payment card has been in the selected
/// language since Issue #529 (`payment_card_labels_test.dart`).
void main() {
  setUpAll(loadAppFonts);
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  /// The approved copy, by key.
  const copy = <String, ({String mongolian, String english})>{
    'homeNotifications': (mongolian: 'Мэдэгдэл', english: 'Notifications'),
    'homeNextLesson': (mongolian: 'Дараагийн хичээл:', english: 'Next lesson:'),
    'homeLiveHint': (
      mongolian: 'Хичээл эхлсэн та ирцээ бүртгүүлээрэй',
      english: 'The lesson has started. Check in for attendance.',
    ),
    'homeAttendanceAction': (mongolian: 'Ирц бүртгүүлэх', english: 'Check in'),
    'homeContractTitle': (
      mongolian: 'Та гэрээ хийгдээгүй байна',
      english: "You don't have a contract yet",
    ),
    'homeContractSupporting': (
      mongolian: 'Гэрээгээ хийгээрэй',
      english: 'Sign your contract',
    ),
    'homeAttendanceLabel': (mongolian: 'Хичээлийн ирц', english: 'Attendance'),
    'homeDetails': (mongolian: 'Дэлгэрэнгүй', english: 'Details'),
    'homeAttendanceMissed': (
      mongolian: 'Хичээлдээ суугаагүй',
      english: 'Missed class',
    ),
    'homeEmpty': (
      mongolian: 'Та одоогоор ямар нэг ангид бүртгүүлээгүй байна',
      english: 'You are not enrolled in any class yet',
    ),
  };

  String text(String key, LocalePreference language) =>
      language == LocalePreference.mongolian
      ? copy[key]!.mongolian
      : copy[key]!.english;
  String en(String key) => text(key, LocalePreference.english);
  String mn(String key) => text(key, LocalePreference.mongolian);

  Map<String, String> read(AppLocalizations s) => {
    'homeNotifications': s.homeNotifications,
    'homeNextLesson': s.homeNextLesson,
    'homeLiveHint': s.homeLiveHint,
    'homeAttendanceAction': s.homeAttendanceAction,
    'homeContractTitle': s.homeContractTitle,
    'homeContractSupporting': s.homeContractSupporting,
    'homeAttendanceLabel': s.homeAttendanceLabel,
    'homeDetails': s.homeDetails,
    'homeAttendanceMissed': s.homeAttendanceMissed,
    'homeEmpty': s.homeEmpty,
  };

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

  group('every migrated member, and the Teacher alias', () {
    final members = <(String, String Function(), String)>[
      ('notifications', () => HomeStrings.notifications, 'homeNotifications'),
      ('nextLesson', () => HomeStrings.nextLesson, 'homeNextLesson'),
      ('liveHint', () => HomeStrings.liveHint, 'homeLiveHint'),
      (
        'attendanceAction',
        () => HomeStrings.attendanceAction,
        'homeAttendanceAction',
      ),
      ('contractTitle', () => HomeStrings.contractTitle, 'homeContractTitle'),
      (
        'contractSupporting',
        () => HomeStrings.contractSupporting,
        'homeContractSupporting',
      ),
      (
        'attendanceLabel',
        () => HomeStrings.attendanceLabel,
        'homeAttendanceLabel',
      ),
      ('details', () => HomeStrings.details, 'homeDetails'),
      (
        'attendanceMissed',
        () => HomeStrings.attendanceMissed,
        'homeAttendanceMissed',
      ),
      ('empty', () => HomeStrings.empty, 'homeEmpty'),
      (
        'TeacherScheduleStrings.notifications',
        () => TeacherScheduleStrings.notifications,
        'homeNotifications',
      ),
    ];

    test('are all 11', () => expect(members, hasLength(11)));

    for (final language in LocalePreference.values) {
      test(language.name, () async {
        await locale.setPreference(language);
        for (final (name, member, key) in members) {
          expect(member(), text(key, language), reason: name);
        }
      });
    }

    test('the design\'s own English is untouched; the payment card reads in '
        'English since Issue #529', () async {
      await locale.setEnglish(true);
      expect(HomeStrings.logo, 'AI academy Asia');
      expect(HomeStrings.live, 'Live');
      expect(HomeStrings.modules(2, 5), 'Modules 2 of 5 complete');
      expect(HomeStrings.percentComplete(40), '40% complete');
      expect(HomeStrings.paymentLabel, 'Next payment');
      expect(HomeStrings.paymentOverdue, 'Overdue');
      expect(HomeStrings.paymentDueIn(3), '3 days left');
      expect(HomeStrings.payAction, 'Pay');
    });
  });

  Widget scoped(Widget child) => L10nRebuildScope(
    child: MaterialApp(theme: AppTheme.light, home: child),
  );

  group('ContractBanner', () {
    for (final language in LocalePreference.values) {
      testWidgets('with no copy given, Home\'s own lines in ${language.name}', (
        tester,
      ) async {
        await locale.setPreference(language);
        await tester.pumpWidget(scoped(const Scaffold(body: ContractBanner())));

        expect(find.text(text('homeContractTitle', language)), findsOneWidget);
        expect(
          find.text(text('homeContractSupporting', language)),
          findsOneWidget,
        );
      });
    }

    testWidgets('copy it is given — Junior Progress\'s — wins in either '
        'language', (tester) async {
      await locale.setEnglish(true);
      await tester.pumpWidget(
        scoped(
          Scaffold(
            body: ContractBanner(
              title: JuniorProgressStrings.contractTitle,
              supporting: JuniorProgressStrings.showParent,
            ),
          ),
        ),
      );

      expect(find.text(JuniorProgressStrings.contractTitle), findsOneWidget);
      expect(find.text(JuniorProgressStrings.showParent), findsOneWidget);
      expect(find.text(en('homeContractTitle')), findsNothing);
    });
  });

  // Home, as `home_screen_test.dart` pumps it.
  final lessonStart = DateTime(2026, 4, 8, 9);
  final beforeLesson = DateTime(2026, 4, 8, 8);
  final duringLesson = DateTime(2026, 4, 8, 10);

  HomeDashboard dashboard({bool contract = true}) => HomeDashboard(
    program: sampleProgram(
      progress: const ModuleProgress(percent: 40, completed: 2, total: 5),
      nextLesson: sampleLesson(start: lessonStart),
    ),
    contract: contract ? const ContractStatus(signed: false) : null,
    stats: const [
      PaymentStat(PaymentStatus.dueIn(3), layout: HomeStatLayout.tile),
      AttendanceStat(
        AttendanceSummary(attended: 1, total: 20),
        layout: HomeStatLayout.tile,
      ),
    ],
  );

  Future<FakeHomeDashboardRepository> pumpHome(
    WidgetTester tester, {
    HomeDashboard? data,
    DateTime? now,
    NotificationCenter? notifications,
    Size size = const Size(393, 852),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    final repository = FakeHomeDashboardRepository(
      dashboard: data ?? dashboard(),
    );
    await tester.pumpWidget(
      scoped(
        HomeScreen(
          repository: repository,
          clock: () => now ?? beforeLesson,
          showPaymentPreview: false,
          notifications: notifications,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  group('Home in English', () {
    setUp(() => locale.setEnglish(true));

    testWidgets('before the lesson: next lesson, contract, attendance and '
        'Details', (tester) async {
      await pumpHome(tester);

      expect(find.text('Next lesson:'), findsOneWidget);
      expect(find.text("You don't have a contract yet"), findsOneWidget);
      expect(find.text('Sign your contract'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
      // The attendance card's action (the payment card's shows only when it
      // has somewhere to lead).
      expect(find.text('Details'), findsWidgets);
      for (final key in copy.keys) {
        expect(find.text(mn(key)), findsNothing, reason: key);
      }
    });

    testWidgets('during the lesson: the live hint and an enabled Check in', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpHome(tester, now: duringLesson);

      expect(
        find.text('The lesson has started. Check in for attendance.'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Check in')),
        isSemantics(label: 'Check in', isButton: true, isEnabled: true),
      );
      semantics.dispose();
    });

    testWidgets('enrolled in nothing: the empty line', (tester) async {
      await pumpHome(tester, data: const HomeDashboard());

      expect(
        find.text('You are not enrolled in any class yet'),
        findsOneWidget,
      );
    });

    testWidgets('the bell is announced as Notifications, then with the '
        'unread count', (tester) async {
      final semantics = tester.ensureSemantics();
      final feed = FakeNotificationRepository();
      final center = NotificationCenter(repository: feed);
      await pumpHome(tester, notifications: center);
      expect(find.bySemanticsLabel('Notifications'), findsOneWidget);

      feed.notifications = [
        for (var id = 1; id <= 3; id++) sampleNotification(id: id),
      ];
      await tester.fling(find.byType(ProgramCard), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(center.unreadCount, 3);
      expect(find.bySemanticsLabel('Notifications, 3'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('Attendance Details opens Attendance detail: its title and '
        'its missed-class legend', (tester) async {
      await pumpHome(tester);

      final details = find.descendant(
        of: find
            .ancestor(
              of: find.text('Attendance'),
              matching: find.byType(Material),
            )
            .first,
        matching: find.text('Details'),
      );
      await tester.ensureVisible(details);
      await tester.pumpAndSettle();
      await tester.tap(details);
      await tester.pumpAndSettle();

      expect(find.byType(AttendanceDetailScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BackTitleHeader),
          matching: find.text('Attendance'),
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('Missed class'), 100);
      expect(find.text('Missed class'), findsOneWidget);
    });
  });

  testWidgets('switching language on mounted Home: the labels change; the '
      'program, scroll position and data stay', (tester) async {
    final repository = await pumpHome(tester, now: duringLesson);
    final state = tester.state(find.byType(HomeScreen));
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ProgramCard), const Offset(0, -120));
    await tester.pumpAndSettle();
    final offset = scrollable.position.pixels;
    expect(offset, greaterThan(0));
    final loads = repository.callCount;

    await locale.setEnglish(true);
    await tester.pump();

    expect(
      find.text('The lesson has started. Check in for attendance.'),
      findsOneWidget,
    );
    expect(find.text('Check in'), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text(mn('homeLiveHint')), findsNothing);
    // The same screen, scrolled where it was, not reloaded.
    expect(tester.state(find.byType(HomeScreen)), same(state));
    expect(scrollable.position.pixels, offset);
    expect(repository.callCount, loads);
    expect(find.text('Cohort 01'), findsOneWidget);

    await locale.setEnglish(false);
    await tester.pump();
    expect(find.text(mn('homeLiveHint')), findsOneWidget);
  });

  testWidgets('switching language on an open Attendance detail: its title '
      'and legend change; it stays open', (tester) async {
    await pumpHome(tester);
    final details = find.text(mn('homeDetails')).last;
    await tester.ensureVisible(details);
    await tester.pumpAndSettle();
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceDetailScreen), findsOneWidget);
    expect(find.text(mn('homeAttendanceLabel')), findsOneWidget);

    await locale.setEnglish(true);
    await tester.pump();

    expect(find.byType(AttendanceDetailScreen), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text(mn('homeAttendanceLabel')), findsNothing);
    await tester.scrollUntilVisible(find.text('Missed class'), 100);
    expect(find.text('Missed class'), findsOneWidget);
  });

  group('English at 2.0× text on a 320 pt phone', () {
    /// The keys whose text [screen] draws, as laid out in [language]: each
    /// on screen and inside the width; returns those cut short.
    Future<Set<String>> cutShort(
      WidgetTester tester,
      LocalePreference language,
      List<String> keys,
    ) async {
      final cut = <String>{};
      expect(tester.takeException(), isNull);
      for (final key in keys) {
        final label = find.text(text(key, language));
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

    Future<Set<String>> homeCut(
      WidgetTester tester,
      LocalePreference language, {
      required DateTime now,
      required List<String> keys,
    }) async {
      await locale.setPreference(language);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      // A fresh tree: no scroll position carried over from the other pass.
      await tester.pumpWidget(const SizedBox());
      await pumpHome(tester, now: now, size: const Size(320, 568));
      return cutShort(tester, language, keys);
    }

    testWidgets('Home before the lesson: no overflow, nothing cut short that '
        'Mongolian is not', (tester) async {
      const keys = [
        'homeNextLesson',
        'homeContractTitle',
        'homeContractSupporting',
        'homeAttendanceLabel',
        'homeDetails',
      ];
      final mongolian = await homeCut(
        tester,
        LocalePreference.mongolian,
        now: beforeLesson,
        keys: keys,
      );
      final english = await homeCut(
        tester,
        LocalePreference.english,
        now: beforeLesson,
        keys: keys,
      );
      expect(english.difference(mongolian), isEmpty);
    });

    testWidgets('Home during the lesson: no overflow, nothing cut short that '
        'Mongolian is not', (tester) async {
      const keys = ['homeLiveHint', 'homeAttendanceAction'];
      final mongolian = await homeCut(
        tester,
        LocalePreference.mongolian,
        now: duringLesson,
        keys: keys,
      );
      final english = await homeCut(
        tester,
        LocalePreference.english,
        now: duringLesson,
        keys: keys,
      );
      expect(english.difference(mongolian), isEmpty);
    });

    testWidgets('Home enrolled in nothing: no overflow, nothing cut short '
        'that Mongolian is not', (tester) async {
      Future<Set<String>> emptyCut(LocalePreference language) async {
        await locale.setPreference(language);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(const SizedBox());
        await pumpHome(
          tester,
          data: const HomeDashboard(),
          size: const Size(320, 568),
        );
        return cutShort(tester, language, const ['homeEmpty']);
      }

      final mongolian = await emptyCut(LocalePreference.mongolian);
      final english = await emptyCut(LocalePreference.english);
      expect(english.difference(mongolian), isEmpty);
    });

    testWidgets('Attendance detail: no overflow, nothing cut short that '
        'Mongolian is not', (tester) async {
      Future<Set<String>> detailCut(LocalePreference language) async {
        await locale.setPreference(language);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        useLogicalViewport(
          tester,
          const Size(320, 568),
          padding: iPhonePadding,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          scoped(
            AttendanceDetailScreen(
              attendance: const AttendanceSummary(attended: 1, total: 20),
              clock: () => beforeLesson,
            ),
          ),
        );
        await tester.pumpAndSettle();
        return cutShort(tester, language, const [
          'homeAttendanceLabel',
          'homeAttendanceMissed',
        ]);
      }

      final mongolian = await detailCut(LocalePreference.mongolian);
      final english = await detailCut(LocalePreference.english);
      expect(english.difference(mongolian), isEmpty);
    });
  });
}
