import 'package:aia_mobile/core/locale/app_format.dart';
import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/certificates/presentation/certificate_strings.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/attendance_panel_parts.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_week_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #505: dates, times and weekday names in the selected language.
/// Mongolian is the app's output from before the shared formatter, byte for
/// byte; English is `intl`'s `en_US`.
void main() {
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  Future<void> english() => locale.setEnglish(true);

  // Thursday 6 August 2026, 09:05 — single-digit minutes and days pad.
  final thursday = DateTime(2026, 8, 6, 9, 5);

  group('times — 24-hour, padded, the same in both languages', () {
    for (final language in LocalePreference.values) {
      test(language.name, () async {
        await locale.setPreference(language);

        expect(AppFormat.clock(0, 0), '00:00');
        expect(AppFormat.clock(9, 5), '09:05');
        expect(AppFormat.clock(23, 59), '23:59');
        expect(AppFormat.time(thursday), '09:05');
        expect(AppFormat.hour(7), '07:00');
        expect(AppFormat.hour(22), '22:00');
      });
    }
  });

  group('Mongolian — exactly as before', () {
    test('short dates: MM/dd, or dd/MM where Home writes it', () {
      expect(AppFormat.shortDate(thursday), '08/06');
      expect(AppFormat.shortDate(thursday, dayFirst: true), '06/08');
      expect(AppFormat.shortDate(DateTime(2026, 12, 25)), '12/25');
    });

    test('the long date: "N-р сарын D", unpadded', () {
      expect(AppFormat.longDate(thursday), '8-р сарын 6');
      expect(AppFormat.longDate(DateTime(2026, 11, 17)), '11-р сарын 17');
    });

    test('dates with a year, joined by the caller\'s separator', () {
      expect(
        AppFormat.dateWithYear(thursday, mongolianSeparator: '/'),
        '2026/08/06',
      );
      expect(
        AppFormat.dateWithYear(thursday, mongolianSeparator: '.'),
        '2026.08.06',
      );
    });

    test('the month and year, every month', () {
      const months = [
        'Нэгдүгээр',
        'Хоёрдугаар',
        'Гуравдугаар',
        'Дөрөвдүгээр',
        'Тавдугаар',
        'Зургаадугаар',
        'Долоодугаар',
        'Наймдугаар',
        'Есдүгээр',
        'Аравдугаар',
        'Арван нэгдүгээр',
        'Арван хоёрдугаар',
      ];
      for (var m = 1; m <= 12; m++) {
        expect(
          AppFormat.monthYear(DateTime(2026, m)),
          '${months[m - 1]} сар, 2026',
        );
      }
    });

    test('weekdays: two Mongolian letters, in DateTime.weekday order', () {
      expect(
        [for (var d = 1; d <= 7; d++) AppFormat.weekday(d)],
        ['Да', 'Мя', 'Лх', 'Пү', 'Ба', 'Бя', 'Ня'],
      );
      expect(AppFormat.weekdays(first: DateTime.sunday), [
        'Ня',
        'Да',
        'Мя',
        'Лх',
        'Пү',
        'Ба',
        'Бя',
      ]);
    });

    test('weekday letters: the Latin ones the Junior frame draws', () {
      expect(AppFormat.weekdayLetters(first: DateTime.sunday), [
        'S',
        'M',
        'T',
        'W',
        'T',
        'F',
        'S',
      ]);
    });

    test('today, or the MM/dd date, with the time', () {
      expect(AppFormat.todayOrDate(thursday, now: thursday), 'Today, 09:05');
      expect(
        AppFormat.todayOrDate(thursday, now: DateTime(2026, 8, 6, 23, 59)),
        'Today, 09:05',
      );
      expect(
        AppFormat.todayOrDate(thursday, now: DateTime(2026, 8, 7)),
        '08/06, 09:05',
      );
      // The same day a year apart is not today.
      expect(
        AppFormat.todayOrDate(thursday, now: DateTime(2027, 8, 6)),
        '08/06, 09:05',
      );
    });
  });

  group('English — intl\'s en_US, the same fields', () {
    test(
      'short dates: the month by name, whichever order Mongolian uses',
      () async {
        await english();

        expect(AppFormat.shortDate(thursday), 'Aug 6');
        expect(AppFormat.shortDate(thursday, dayFirst: true), 'Aug 6');
      },
    );

    test(
      'the long date, the month and year, and a date with its year',
      () async {
        await english();

        expect(AppFormat.longDate(DateTime(2026, 11, 17)), 'November 17');
        expect(AppFormat.monthYear(thursday), 'August 2026');
        expect(
          AppFormat.dateWithYear(thursday, mongolianSeparator: '/'),
          'Aug 6, 2026',
        );
      },
    );

    test('weekdays, in order from the first day asked for', () async {
      await english();

      expect(
        [for (var d = 1; d <= 7; d++) AppFormat.weekday(d)],
        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      );
      expect(AppFormat.weekdays(first: DateTime.sunday), [
        'Sun',
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
      ]);
      expect(AppFormat.weekdayLetters(first: DateTime.sunday), [
        'S',
        'M',
        'T',
        'W',
        'T',
        'F',
        'S',
      ]);
    });

    test('today, or the date, with the time', () async {
      await english();

      expect(AppFormat.todayOrDate(thursday, now: thursday), 'Today, 09:05');
      expect(
        AppFormat.todayOrDate(thursday, now: DateTime(2026, 8, 7)),
        'Aug 6, 09:05',
      );
    });
  });

  group('ages — the same short form in both languages', () {
    final now = DateTime(2026, 10, 8, 15, 18);
    String ageOf(Duration ago) => AppFormat.age(now.subtract(ago), now);

    for (final language in LocalePreference.values) {
      test(language.name, () async {
        await locale.setPreference(language);

        expect(ageOf(Duration.zero), '1m');
        expect(ageOf(const Duration(seconds: 59)), '1m');
        expect(ageOf(const Duration(minutes: 5)), '5m');
        expect(ageOf(const Duration(minutes: 59, seconds: 59)), '59m');
        expect(ageOf(const Duration(hours: 1)), '1h');
        expect(ageOf(const Duration(hours: 23, minutes: 59)), '23h');
        expect(ageOf(const Duration(days: 1)), '1d');
        expect(ageOf(const Duration(days: 7, hours: 5)), '7d');
        // A clock running ahead never reads as negative.
        expect(AppFormat.age(now.add(const Duration(hours: 1)), now), '1m');
      });
    }
  });

  group('time zones — the caller\'s instant, never converted here', () {
    test('a UTC instant keeps its UTC fields', () async {
      final utc = DateTime.utc(2026, 8, 6, 23, 30);

      expect(AppFormat.time(utc), '23:30');
      expect(AppFormat.shortDate(utc), '08/06');

      await english();
      expect(AppFormat.time(utc), '23:30');
      expect(AppFormat.shortDate(utc), 'Aug 6');
    });

    test('the features still convert where they always did', () async {
      final utc = DateTime.utc(2026, 8, 6, 23, 30);
      final local = utc.toLocal();

      expect(
        CertificateStrings.date(utc),
        AppFormat.dateWithYear(local, mongolianSeparator: '/'),
      );
      expect(
        NotificationStrings.sentAt(utc),
        '${AppFormat.dateWithYear(local, mongolianSeparator: '.')} '
        '· ${AppFormat.time(local)}',
      );
    });
  });

  group('every migrated call site, in both languages', () {
    final end = DateTime(2026, 8, 6, 11, 0);

    test('Mongolian', () {
      expect(HomeStrings.lessonWindow(thursday, end), '06/08 • 09:05 – 11:00');
      expect(
        JuniorProgressStrings.nextLessonTime(thursday, end),
        '08/06 • 09:05 – 11:00',
      );
      expect(
        JuniorProgressStrings.monthLabel(thursday),
        'Наймдугаар сар, 2026',
      );
      expect(JuniorProgressStrings.weekdays, [
        'S',
        'M',
        'T',
        'W',
        'T',
        'F',
        'S',
      ]);
      expect(
        TeacherGradebookStrings.timestamp(thursday, now: DateTime(2026, 8, 9)),
        '08/06, 09:05',
      );
      expect(TeacherScheduleStrings.headerDate(thursday), '8-р сарын 6');
      expect(TeacherScheduleStrings.weekdays.first, 'Ня');
      expect(hourLabel(7), '07:00');
      expect(NotificationStrings.sentAt(thursday), '2026.08.06 · 09:05');
      expect(CertificateStrings.date(thursday), '2026/08/06');
    });

    test('English', () async {
      await english();

      expect(HomeStrings.lessonWindow(thursday, end), 'Aug 6 • 09:05 – 11:00');
      expect(
        JuniorProgressStrings.nextLessonTime(thursday, end),
        'Aug 6 • 09:05 – 11:00',
      );
      expect(JuniorProgressStrings.monthLabel(thursday), 'August 2026');
      expect(JuniorProgressStrings.weekdays, [
        'S',
        'M',
        'T',
        'W',
        'T',
        'F',
        'S',
      ]);
      expect(
        TeacherGradebookStrings.timestamp(thursday, now: DateTime(2026, 8, 9)),
        'Aug 6, 09:05',
      );
      expect(TeacherScheduleStrings.headerDate(thursday), 'August 6');
      expect(TeacherScheduleStrings.weekdays, [
        'Sun',
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
      ]);
      expect(hourLabel(7), '07:00');
      expect(NotificationStrings.sentAt(thursday), 'Aug 6, 2026 · 09:05');
      expect(CertificateStrings.date(thursday), 'Aug 6, 2026');
    });
  });

  testWidgets('a date drawn on screen follows a language change at once', (
    tester,
  ) async {
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AttendanceMonthHeader(
              month: DateTime(2026, 8),
              onPrevious: () {},
              onNext: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Наймдугаар сар, 2026'), findsOneWidget);

    await english();
    await tester.pump();
    expect(find.text('August 2026'), findsOneWidget);

    await locale.setEnglish(false);
    await tester.pump();
    expect(find.text('Наймдугаар сар, 2026'), findsOneWidget);
  });
}
