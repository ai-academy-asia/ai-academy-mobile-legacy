import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/attendance/presentation/attendance_scanner_strings.dart';
import 'package:aia_mobile/features/auth/presentation/login_strings.dart';
import 'package:aia_mobile/features/auth/presentation/reset_password_strings.dart';
import 'package:aia_mobile/features/certificates/presentation/certificate_strings.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_strings.dart';
import 'package:aia_mobile/features/contracts/domain/contract_failure.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_form_screen.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/courses/presentation/course_catalog_strings.dart';
import 'package:aia_mobile/features/courses/presentation/course_detail_strings.dart';
import 'package:aia_mobile/features/enrollments/presentation/enrollment_strings.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_strings.dart';
import 'package:aia_mobile/features/notifications/domain/notification_failure.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_center.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_screen.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_strings.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:aia_mobile/features/splash/presentation/splash_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/contracts/fake_contract_repository.dart';
import '../../features/notifications/fake_notification_repository.dart';
import '../../features/teacher/fake_schedule_change_repository.dart';

/// Issue #507: the five error and retry messages every feature repeated,
/// now one ARB key each. Every member reads exactly as before in Mongolian,
/// reads the approved English in English, and is wired to its own key.
void main() {
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  /// Each shared key: its Mongolian exactly as every feature wrote it before
  /// Issue #507, and its approved English.
  const keys = <String, ({String mongolian, String english})>{
    'commonNetworkError': (
      mongolian: 'Сүлжээнд холбогдож чадсангүй. Дахин оролдоно уу',
      english: 'Could not connect to the network. Please try again.',
    ),
    'commonServerError': (
      mongolian: 'Серверт алдаа гарлаа. Түр хүлээгээд дахин оролдоно уу',
      english:
          'Something went wrong on the server. Please wait a moment and try '
          'again.',
    ),
    'commonUnexpectedError': (
      mongolian: 'Алдаа гарлаа. Дахин оролдоно уу',
      english: 'Something went wrong. Please try again.',
    ),
    'commonSessionExpired': (
      mongolian: 'Нэвтрэх хугацаа дууссан. Дахин нэвтэрнэ үү',
      english: 'Your session has expired. Please sign in again.',
    ),
    'commonRetry': (mongolian: 'Дахин оролдох', english: 'Try again.'),
  };

  /// Every migrated declaration and alias, and the key it reads.
  final members = <(String, String Function(), String)>[
    // The 43 declarations, file by file.
    (
      'LoginStrings.networkError',
      () => LoginStrings.networkError,
      'commonNetworkError',
    ),
    (
      'LoginStrings.serverError',
      () => LoginStrings.serverError,
      'commonServerError',
    ),
    (
      'LoginStrings.unexpectedError',
      () => LoginStrings.unexpectedError,
      'commonUnexpectedError',
    ),
    (
      'ResetPasswordStrings.sessionExpired',
      () => ResetPasswordStrings.sessionExpired,
      'commonSessionExpired',
    ),
    (
      'ResetPasswordStrings.networkError',
      () => ResetPasswordStrings.networkError,
      'commonNetworkError',
    ),
    (
      'ResetPasswordStrings.serverError',
      () => ResetPasswordStrings.serverError,
      'commonServerError',
    ),
    (
      'ResetPasswordStrings.unexpectedError',
      () => ResetPasswordStrings.unexpectedError,
      'commonUnexpectedError',
    ),
    ('CohortListStrings.retry', () => CohortListStrings.retry, 'commonRetry'),
    (
      'CohortListStrings.networkError',
      () => CohortListStrings.networkError,
      'commonNetworkError',
    ),
    (
      'CohortListStrings.serverError',
      () => CohortListStrings.serverError,
      'commonServerError',
    ),
    (
      'CohortListStrings.unexpectedError',
      () => CohortListStrings.unexpectedError,
      'commonUnexpectedError',
    ),
    (
      'CourseLearningStrings.retry',
      () => CourseLearningStrings.retry,
      'commonRetry',
    ),
    (
      'CourseLearningStrings.sessionExpired',
      () => CourseLearningStrings.sessionExpired,
      'commonSessionExpired',
    ),
    (
      'CourseLearningStrings.networkError',
      () => CourseLearningStrings.networkError,
      'commonNetworkError',
    ),
    (
      'CourseLearningStrings.serverError',
      () => CourseLearningStrings.serverError,
      'commonServerError',
    ),
    (
      'CourseLearningStrings.unexpectedError',
      () => CourseLearningStrings.unexpectedError,
      'commonUnexpectedError',
    ),
    (
      'CourseCatalogStrings.retry',
      () => CourseCatalogStrings.retry,
      'commonRetry',
    ),
    (
      'CourseCatalogStrings.networkError',
      () => CourseCatalogStrings.networkError,
      'commonNetworkError',
    ),
    (
      'CourseCatalogStrings.serverError',
      () => CourseCatalogStrings.serverError,
      'commonServerError',
    ),
    (
      'CourseCatalogStrings.unexpectedError',
      () => CourseCatalogStrings.unexpectedError,
      'commonUnexpectedError',
    ),
    (
      'CourseDetailStrings.retry',
      () => CourseDetailStrings.retry,
      'commonRetry',
    ),
    (
      'CourseDetailStrings.networkError',
      () => CourseDetailStrings.networkError,
      'commonNetworkError',
    ),
    (
      'CourseDetailStrings.serverError',
      () => CourseDetailStrings.serverError,
      'commonServerError',
    ),
    (
      'CourseDetailStrings.unexpectedError',
      () => CourseDetailStrings.unexpectedError,
      'commonUnexpectedError',
    ),
    (
      'EnrollmentStrings.sessionExpired',
      () => EnrollmentStrings.sessionExpired,
      'commonSessionExpired',
    ),
    (
      'EnrollmentStrings.networkError',
      () => EnrollmentStrings.networkError,
      'commonNetworkError',
    ),
    (
      'EnrollmentStrings.serverError',
      () => EnrollmentStrings.serverError,
      'commonServerError',
    ),
    (
      'EnrollmentStrings.unexpectedError',
      () => EnrollmentStrings.unexpectedError,
      'commonUnexpectedError',
    ),
    ('HomeStrings.retry', () => HomeStrings.retry, 'commonRetry'),
    (
      'HomeStrings.sessionExpired',
      () => HomeStrings.sessionExpired,
      'commonSessionExpired',
    ),
    (
      'HomeStrings.networkError',
      () => HomeStrings.networkError,
      'commonNetworkError',
    ),
    (
      'HomeStrings.serverError',
      () => HomeStrings.serverError,
      'commonServerError',
    ),
    (
      'HomeStrings.unexpectedError',
      () => HomeStrings.unexpectedError,
      'commonUnexpectedError',
    ),
    ('JuniorHomeStrings.retry', () => JuniorHomeStrings.retry, 'commonRetry'),
    (
      'JuniorHomeStrings.sessionExpired',
      () => JuniorHomeStrings.sessionExpired,
      'commonSessionExpired',
    ),
    (
      'JuniorHomeStrings.networkError',
      () => JuniorHomeStrings.networkError,
      'commonNetworkError',
    ),
    (
      'JuniorHomeStrings.serverError',
      () => JuniorHomeStrings.serverError,
      'commonServerError',
    ),
    (
      'JuniorHomeStrings.unexpectedError',
      () => JuniorHomeStrings.unexpectedError,
      'commonUnexpectedError',
    ),
    (
      'NotificationStrings.retry',
      () => NotificationStrings.retry,
      'commonRetry',
    ),
    (
      'ProfileStrings.sessionExpired',
      () => ProfileStrings.sessionExpired,
      'commonSessionExpired',
    ),
    (
      'ProfileStrings.networkError',
      () => ProfileStrings.networkError,
      'commonNetworkError',
    ),
    (
      'ProfileStrings.serverError',
      () => ProfileStrings.serverError,
      'commonServerError',
    ),
    (
      'ProfileStrings.unexpectedError',
      () => ProfileStrings.unexpectedError,
      'commonUnexpectedError',
    ),
    // The five aliases, now getters over the member they always named.
    (
      'AttendanceScannerStrings.retryCamera',
      () => AttendanceScannerStrings.retryCamera,
      'commonRetry',
    ),
    ('ContractStrings.retry', () => ContractStrings.retry, 'commonRetry'),
    (
      'ContractStrings.previewFailed',
      () => ContractStrings.previewFailed,
      'commonUnexpectedError',
    ),
    ('CertificateStrings.retry', () => CertificateStrings.retry, 'commonRetry'),
    ('TeacherHomeStrings.retry', () => TeacherHomeStrings.retry, 'commonRetry'),
    // Splash's Retry, which had its own key (Issue #503).
    ('SplashStrings.retry', () => SplashStrings.retry, 'commonRetry'),
  ];

  test('every migrated declaration is listed: 43, plus five aliases and '
      'Splash Retry', () {
    expect(members, hasLength(49));
    expect({for (final (name, _, _) in members) name}, hasLength(49));
  });

  for (final language in LocalePreference.values) {
    test('each shared key\'s ${language.name} text', () {
      final strings = L10n.of(language);
      final read = <String, String>{
        'commonNetworkError': strings.commonNetworkError,
        'commonServerError': strings.commonServerError,
        'commonUnexpectedError': strings.commonUnexpectedError,
        'commonSessionExpired': strings.commonSessionExpired,
        'commonRetry': strings.commonRetry,
      };
      expect(read, {
        for (final MapEntry(:key, :value) in keys.entries)
          key: language == LocalePreference.mongolian
              ? value.mongolian
              : value.english,
      });
    });

    test('every member reads its key\'s ${language.name} text', () async {
      await locale.setPreference(language);
      for (final (name, read, key) in members) {
        final expected = language == LocalePreference.mongolian
            ? keys[key]!.mongolian
            : keys[key]!.english;
        expect(read(), expected, reason: name);
      }
    });
  }

  test('the five keys read differently from one another in both languages, '
      'so a member wired to the wrong key cannot pass', () {
    expect({for (final v in keys.values) v.mongolian}, hasLength(5));
    expect({for (final v in keys.values) v.english}, hasLength(5));
  });

  group('live switching', () {
    testWidgets('an error drawn from its failure: the message and Retry both '
        'switch, and the failure stays the same', (tester) async {
      final repository = FakeContractRepository(
        detailFailure: const ContractFailure(ContractFailureKind.network),
      );
      await tester.pumpWidget(
        L10nRebuildScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: ContractFormScreen(contractId: '12', repository: repository),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(keys['commonNetworkError']!.mongolian), findsOneWidget);
      expect(find.text(keys['commonRetry']!.mongolian), findsOneWidget);
      final calls = repository.detailCalls.length;

      await locale.setEnglish(true);
      await tester.pump();

      expect(find.text(keys['commonNetworkError']!.english), findsOneWidget);
      expect(find.text(keys['commonRetry']!.english), findsOneWidget);
      expect(find.text(keys['commonNetworkError']!.mongolian), findsNothing);
      // Nothing was asked again: the same failure, drawn in English.
      expect(repository.detailCalls, hasLength(calls));

      await locale.setEnglish(false);
      await tester.pump();
      expect(find.text(keys['commonNetworkError']!.mongolian), findsOneWidget);
      expect(find.text(keys['commonRetry']!.mongolian), findsOneWidget);
    });

    testWidgets('an error a controller stored as text: Retry switches at '
        'once, the stored message on the next load', (tester) async {
      final repository = FakeNotificationRepository()
        ..feedFailure = const NotificationFailure(
          NotificationFailureKind.network,
        );
      final center = NotificationCenter(repository: repository);
      await tester.pumpWidget(
        L10nRebuildScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: NotificationScreen(
              center: center,
              scheduleChangeRepository: FakeScheduleChangeRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(keys['commonNetworkError']!.mongolian), findsOneWidget);

      await locale.setEnglish(true);
      await tester.pump();

      // Retry is read while drawing; the message was stored when the load
      // failed, in the language of that moment.
      expect(find.text(keys['commonRetry']!.english), findsOneWidget);
      expect(find.text(keys['commonNetworkError']!.mongolian), findsOneWidget);

      await tester.tap(find.text(keys['commonRetry']!.english));
      await tester.pumpAndSettle();

      expect(find.text(keys['commonNetworkError']!.english), findsOneWidget);
    });
  });
}
