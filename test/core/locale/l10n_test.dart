import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/features/auth/presentation/sign_out_strings.dart';
import 'package:aia_mobile/features/splash/presentation/splash_strings.dart';
import 'package:aia_mobile/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #503: the app's own strings, generated from `lib/l10n/*.arb` and
/// read without a `BuildContext`, in the language of the app's one
/// [AppLocaleController].
void main() {
  tearDown(
    () =>
        AppLocaleController.instance.setPreference(LocalePreference.mongolian),
  );

  /// Every message exactly as it was written before it moved to ARB — the
  /// pilot (Issue #503) and the shared error and retry messages (Issue #507).
  /// Mongolian must read the same, character for character.
  const mongolian = {
    'signOutTitle': 'Гарах уу?',
    'signOutMessage': 'Та бүртгэлээс гарахдаа итгэлтэй байна уу?',
    'signOutCancel': 'Цуцлах',
    'signOutConfirm': 'Гарах',
    'splashWordmarkLine1': 'AI academy',
    'splashWordmarkLine2': 'Asia',
    'splashNetworkError': 'Интернэт холболтоо шалгаад дахин оролдоно уу.',
    'commonNetworkError': 'Сүлжээнд холбогдож чадсангүй. Дахин оролдоно уу',
    'commonServerError':
        'Серверт алдаа гарлаа. Түр хүлээгээд дахин оролдоно уу',
    'commonUnexpectedError': 'Алдаа гарлаа. Дахин оролдоно уу',
    'commonSessionExpired': 'Нэвтрэх хугацаа дууссан. Дахин нэвтэрнэ үү',
    'commonRetry': 'Дахин оролдох',
  };

  Map<String, String> messages(AppLocalizations strings) => {
    'signOutTitle': strings.signOutTitle,
    'signOutMessage': strings.signOutMessage,
    'signOutCancel': strings.signOutCancel,
    'signOutConfirm': strings.signOutConfirm,
    'splashWordmarkLine1': strings.splashWordmarkLine1,
    'splashWordmarkLine2': strings.splashWordmarkLine2,
    'splashNetworkError': strings.splashNetworkError,
    'commonNetworkError': strings.commonNetworkError,
    'commonServerError': strings.commonServerError,
    'commonUnexpectedError': strings.commonUnexpectedError,
    'commonSessionExpired': strings.commonSessionExpired,
    'commonRetry': strings.commonRetry,
  };

  group('generated strings', () {
    test('Mongolian, then English — the languages the app supports', () {
      expect(AppLocalizations.supportedLocales, const [
        Locale('mn'),
        Locale('en'),
      ]);
      expect(
        AppLocalizations.supportedLocales,
        AppLocaleController.supportedLocales,
      );
    });

    test('Mongolian reads exactly as before', () {
      expect(messages(L10n.of(LocalePreference.mongolian)), mongolian);
    });

    test('English: the app\'s existing English copy, and the brand', () {
      final english = L10n.of(LocalePreference.english);

      // Cancel and Log out are the app's own English for these actions
      // (`CourseLearningStrings.cancelUpload`, `ProfileStrings.logOut`).
      expect(english.signOutCancel, 'Cancel');
      expect(english.signOutConfirm, 'Log out');
      expect(english.splashWordmarkLine1, 'AI academy');
      expect(english.splashWordmarkLine2, 'Asia');
    });

    test('English: the approved sign-out confirmation (Issue #521)', () {
      final english = L10n.of(LocalePreference.english);
      expect(english.signOutTitle, 'Log out?');
      expect(
        english.signOutMessage,
        'Are you sure you want to log out of your account?',
      );
    });

    test('English: the approved shared error and retry messages (Issue '
        '#507)', () {
      final english = L10n.of(LocalePreference.english);
      expect(
        english.commonNetworkError,
        'Could not connect to the network. Please try again.',
      );
      expect(
        english.commonServerError,
        'Something went wrong on the server. Please wait a moment and try '
        'again.',
      );
      expect(
        english.commonUnexpectedError,
        'Something went wrong. Please try again.',
      );
      expect(
        english.commonSessionExpired,
        'Your session has expired. Please sign in again.',
      );
      expect(english.commonRetry, 'Try again.');
    });

    test('English without approved copy falls back to the Mongolian, and is '
        'listed as untranslated', () {
      const untranslated = ['splashNetworkError'];
      final english = messages(L10n.of(LocalePreference.english));
      for (final key in untranslated) {
        expect(english[key], mongolian[key], reason: key);
      }

      // The list `flutter gen-l10n` writes is the same open work — so new
      // English copy, or a new untranslated message, updates both.
      final listed = jsonDecode(
        File('lib/l10n/untranslated_messages.json').readAsStringSync(),
      );
      expect(listed, {'en': untranslated});
    });

    test('each language is one set, made once', () {
      expect(
        identical(
          L10n.of(LocalePreference.english),
          L10n.of(LocalePreference.english),
        ),
        isTrue,
      );
      expect(L10n.of(LocalePreference.mongolian).localeName, 'mn');
      expect(L10n.of(LocalePreference.english).localeName, 'en');
    });
  });

  group('L10n.current follows the app\'s one controller', () {
    test('Mongolian by default', () {
      expect(L10n.current.localeName, 'mn');
    });

    test('a choice applies at once, both ways', () async {
      await AppLocaleController.instance.setEnglish(true);
      expect(L10n.current.localeName, 'en');

      await AppLocaleController.instance.setEnglish(false);
      expect(L10n.current.localeName, 'mn');
    });

    test('another controller — a test seam — does not move it', () async {
      final other = AppLocaleController();
      await other.setEnglish(true);

      expect(L10n.current.localeName, 'mn');
    });
  });

  group('the pilot strings read the selected language', () {
    test('SignOutStrings', () async {
      expect(SignOutStrings.title, 'Гарах уу?');
      expect(
        SignOutStrings.message,
        'Та бүртгэлээс гарахдаа итгэлтэй байна уу?',
      );
      expect(SignOutStrings.cancel, 'Цуцлах');
      expect(SignOutStrings.confirm, 'Гарах');

      await AppLocaleController.instance.setEnglish(true);

      expect(SignOutStrings.cancel, 'Cancel');
      expect(SignOutStrings.confirm, 'Log out');
      // Approved English since Issue #521.
      expect(SignOutStrings.title, 'Log out?');
      expect(
        SignOutStrings.message,
        'Are you sure you want to log out of your account?',
      );
    });

    test('SplashStrings', () async {
      expect(SplashStrings.wordmarkSemanticsLabel, 'AI academy Asia');
      expect(
        SplashStrings.networkError,
        'Интернэт холболтоо шалгаад дахин оролдоно уу.',
      );
      expect(SplashStrings.retry, 'Дахин оролдох');

      await AppLocaleController.instance.setEnglish(true);

      expect(SplashStrings.wordmarkSemanticsLabel, 'AI academy Asia');
      // Retry is the shared key (Issue #507); the network error still has
      // no approved English.
      expect(SplashStrings.retry, 'Try again.');
      expect(
        SplashStrings.networkError,
        'Интернэт холболтоо шалгаад дахин оролдоно уу.',
      );
    });
  });
}
