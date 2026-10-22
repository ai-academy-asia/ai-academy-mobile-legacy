import 'dart:ui' show CheckedState;

import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/domain/auth_failure.dart';
import 'package:aia_mobile/features/auth/domain/password_policy.dart';
import 'package:aia_mobile/features/auth/presentation/home_route.dart';
import 'package:aia_mobile/features/auth/presentation/reset_password_screen.dart';
import 'package:aia_mobile/features/auth/presentation/reset_password_strings.dart';
import 'package:aia_mobile/l10n/app_localizations.dart';
import 'package:aia_mobile/shared/widgets/app_back_button.dart';
import 'package:aia_mobile/shared/widgets/back_title_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/auth/fake_password_repository.dart';
import '../../support/screenshot.dart';

/// Issue #515: the password-reset screen in the selected language, in both
/// its flows. Mongolian reads exactly as before, the Lorem ipsum line
/// included.
void main() {
  setUpAll(loadAppFonts);
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  /// The approved copy, by key.
  const copy = <String, ({String mongolian, String english})>{
    'resetTitle': (
      mongolian: 'Нууц үгээ тохируулах',
      english: 'Set your password',
    ),
    'resetCurrentPassword': (
      mongolian: 'Одоогийн нууц үг',
      english: 'Current password',
    ),
    'resetNewPassword': (mongolian: 'Шинэ нууц үг', english: 'New password'),
    'resetConfirmPassword': (
      mongolian: 'Шинэ нууц үг давтах',
      english: 'Confirm new password',
    ),
    'resetRequirementsTitle': (
      mongolian: 'Нууц үг нь дараах шаардлагыг хангасан байна:',
      english: 'Your password must meet these requirements:',
    ),
    'resetSubmit': (mongolian: 'Хадгалах', english: 'Save'),
    'resetRuleMinLength': (
      mongolian: '8 ба түүнээс дээш тэмдэгт ашиглах',
      english: 'Use 8 or more characters',
    ),
    'resetRuleUppercase': (
      mongolian: 'Том үсэг ашиглах',
      english: 'Use an uppercase letter',
    ),
    'resetRuleLowercase': (
      mongolian: 'Жижиг үсэг ашиглах',
      english: 'Use a lowercase letter',
    ),
    'resetRuleDigit': (mongolian: 'Тоо ашиглах', english: 'Use a number'),
    'resetRuleSpecial': (
      mongolian: 'Тусгай тэмдэгт ашиглах',
      english: 'Use a special character',
    ),
    'resetCurrentPasswordRequired': (
      mongolian: 'Одоогийн нууц үгээ оруулна уу',
      english: 'Enter your current password',
    ),
    'resetNewPasswordRequired': (
      mongolian: 'Шинэ нууц үгээ оруулна уу',
      english: 'Enter a new password',
    ),
    'resetNewPasswordWeak': (
      mongolian: 'Нууц үг шаардлагыг хангахгүй байна',
      english: 'The password does not meet the requirements',
    ),
    'resetConfirmPasswordRequired': (
      mongolian: 'Шинэ нууц үгээ давтан оруулна уу',
      english: 'Enter your new password again',
    ),
    'resetConfirmPasswordMismatch': (
      mongolian: 'Шинэ нууц үгтэй таарахгүй байна',
      english: 'Does not match the new password',
    ),
    'resetNewPasswordSameAsCurrent': (
      mongolian: 'Шинэ нууц үг одоогийнхоос өөр байх ёстой',
      english: 'The new password must be different from the current one',
    ),
    'resetSuccess': (
      mongolian: 'Нууц үг амжилттай солигдлоо',
      english: 'Your password has been changed',
    ),
    'resetInvalidCurrentPassword': (
      mongolian: 'Одоогийн нууц үг буруу байна',
      english: 'The current password is incorrect',
    ),
    // Reused from Login (Issue #513) and the shared errors (Issue #507).
    'authShowPassword': (
      mongolian: 'Нууц үг харуулах',
      english: 'Show password',
    ),
    'authHidePassword': (mongolian: 'Нууц үг нуух', english: 'Hide password'),
    'commonSessionExpired': (
      mongolian: 'Нэвтрэх хугацаа дууссан. Дахин нэвтэрнэ үү',
      english: 'Your session has expired. Please sign in again.',
    ),
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
  };

  String text(String key, LocalePreference language) =>
      language == LocalePreference.mongolian
      ? copy[key]!.mongolian
      : copy[key]!.english;

  Map<String, String> read(AppLocalizations s) => {
    'resetTitle': s.resetTitle,
    'resetCurrentPassword': s.resetCurrentPassword,
    'resetNewPassword': s.resetNewPassword,
    'resetConfirmPassword': s.resetConfirmPassword,
    'resetRequirementsTitle': s.resetRequirementsTitle,
    'resetSubmit': s.resetSubmit,
    'resetRuleMinLength': s.resetRuleMinLength,
    'resetRuleUppercase': s.resetRuleUppercase,
    'resetRuleLowercase': s.resetRuleLowercase,
    'resetRuleDigit': s.resetRuleDigit,
    'resetRuleSpecial': s.resetRuleSpecial,
    'resetCurrentPasswordRequired': s.resetCurrentPasswordRequired,
    'resetNewPasswordRequired': s.resetNewPasswordRequired,
    'resetNewPasswordWeak': s.resetNewPasswordWeak,
    'resetConfirmPasswordRequired': s.resetConfirmPasswordRequired,
    'resetConfirmPasswordMismatch': s.resetConfirmPasswordMismatch,
    'resetNewPasswordSameAsCurrent': s.resetNewPasswordSameAsCurrent,
    'resetSuccess': s.resetSuccess,
    'resetInvalidCurrentPassword': s.resetInvalidCurrentPassword,
    'authShowPassword': s.authShowPassword,
    'authHidePassword': s.authHidePassword,
    'commonSessionExpired': s.commonSessionExpired,
    'commonNetworkError': s.commonNetworkError,
    'commonServerError': s.commonServerError,
    'commonUnexpectedError': s.commonUnexpectedError,
  };

  const rules = {
    PasswordRequirement.minLength: 'resetRuleMinLength',
    PasswordRequirement.uppercase: 'resetRuleUppercase',
    PasswordRequirement.lowercase: 'resetRuleLowercase',
    PasswordRequirement.digit: 'resetRuleDigit',
    PasswordRequirement.special: 'resetRuleSpecial',
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

  group('every ResetPasswordStrings member', () {
    final members = <(String, String Function(), String)>[
      ('title', () => ResetPasswordStrings.title, 'resetTitle'),
      (
        'currentPassword',
        () => ResetPasswordStrings.currentPassword,
        'resetCurrentPassword',
      ),
      (
        'newPassword',
        () => ResetPasswordStrings.newPassword,
        'resetNewPassword',
      ),
      (
        'confirmPassword',
        () => ResetPasswordStrings.confirmPassword,
        'resetConfirmPassword',
      ),
      (
        'requirementsTitle',
        () => ResetPasswordStrings.requirementsTitle,
        'resetRequirementsTitle',
      ),
      ('submit', () => ResetPasswordStrings.submit, 'resetSubmit'),
      for (final MapEntry(key: rule, value: key) in rules.entries)
        (
          'requirement(${rule.name})',
          () => ResetPasswordStrings.requirement(rule),
          key,
        ),
      (
        'currentPasswordRequired',
        () => ResetPasswordStrings.currentPasswordRequired,
        'resetCurrentPasswordRequired',
      ),
      (
        'newPasswordRequired',
        () => ResetPasswordStrings.newPasswordRequired,
        'resetNewPasswordRequired',
      ),
      (
        'newPasswordWeak',
        () => ResetPasswordStrings.newPasswordWeak,
        'resetNewPasswordWeak',
      ),
      (
        'confirmPasswordRequired',
        () => ResetPasswordStrings.confirmPasswordRequired,
        'resetConfirmPasswordRequired',
      ),
      (
        'confirmPasswordMismatch',
        () => ResetPasswordStrings.confirmPasswordMismatch,
        'resetConfirmPasswordMismatch',
      ),
      (
        'newPasswordSameAsCurrent',
        () => ResetPasswordStrings.newPasswordSameAsCurrent,
        'resetNewPasswordSameAsCurrent',
      ),
      ('success', () => ResetPasswordStrings.success, 'resetSuccess'),
      (
        'invalidCurrentPassword',
        () => ResetPasswordStrings.invalidCurrentPassword,
        'resetInvalidCurrentPassword',
      ),
      (
        'sessionExpired',
        () => ResetPasswordStrings.sessionExpired,
        'commonSessionExpired',
      ),
      (
        'networkError',
        () => ResetPasswordStrings.networkError,
        'commonNetworkError',
      ),
      (
        'serverError',
        () => ResetPasswordStrings.serverError,
        'commonServerError',
      ),
      (
        'unexpectedError',
        () => ResetPasswordStrings.unexpectedError,
        'commonUnexpectedError',
      ),
      (
        'showPassword',
        () => ResetPasswordStrings.showPassword,
        'authShowPassword',
      ),
      (
        'hidePassword',
        () => ResetPasswordStrings.hidePassword,
        'authHidePassword',
      ),
    ];

    test('are all 25 — 21 newly localized, 4 shared errors', () {
      expect(members, hasLength(25));
    });

    for (final language in LocalePreference.values) {
      test(language.name, () async {
        await locale.setPreference(language);
        for (final (name, member, key) in members) {
          expect(member(), text(key, language), reason: name);
        }
        // The design's placeholder, the same in both languages, unchanged.
        expect(
          ResetPasswordStrings.supporting,
          'Lorem ipsum dolor sit amet consectetur.',
        );
      });
    }
  });

  const good = 'Nuutsug1!';
  const current = 'oldpass12';

  Finder field(int index) => find.byType(EditableText).at(index);
  FocusNode focusOf(WidgetTester tester, int index) =>
      tester.widget<EditableText>(field(index)).focusNode;

  Future<void> tapSave(WidgetTester tester) async {
    final save = find.text(ResetPasswordStrings.submit);
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  /// The required change: the screen alone, as `openSignedIn` opens it.
  Future<void> pumpRequired(
    WidgetTester tester, {
    FakePasswordRepository? repository,
    VoidCallback? onCompleted,
    Size size = const Size(393, 852),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: ResetPasswordScreen(
            repository: repository ?? FakePasswordRepository(),
            onCompleted: onCompleted ?? () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The voluntary change: pushed over another page, with its Back.
  Future<void> pumpVoluntary(
    WidgetTester tester, {
    FakePasswordRepository? repository,
  }) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ResetPasswordScreen(
                      repository: repository ?? FakePasswordRepository(),
                      showBackButton: true,
                    ),
                  ),
                ),
                child: const Text('profile'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('profile'));
    await tester.pumpAndSettle();
  }

  /// Each rule's screen-reader node: its label and whether it is checked.
  Map<String, bool> ruleStates(
    WidgetTester tester,
    LocalePreference language,
  ) => {
    for (final key in rules.values)
      key:
          tester
              .getSemantics(find.bySemanticsLabel(text(key, language)))
              .flagsCollection
              .isChecked ==
          CheckedState.isTrue,
  };

  group('in English', () {
    setUp(() => locale.setEnglish(true));

    testWidgets('the required change: title, fields, panel, rules and Save; '
        'no Back', (tester) async {
      await pumpRequired(tester);

      expect(find.text('Set your password'), findsOneWidget);
      expect(find.byType(AppBackButton), findsNothing);
      for (final key in [
        'resetCurrentPassword',
        'resetNewPassword',
        'resetConfirmPassword',
        'resetRequirementsTitle',
        ...rules.values,
        'resetSubmit',
      ]) {
        expect(
          find.text(text(key, LocalePreference.english)),
          findsOneWidget,
          reason: key,
        );
      }
      expect(
        find.text('Lorem ipsum dolor sit amet consectetur.'),
        findsOneWidget,
      );
      for (final c in copy.values) {
        expect(find.text(c.mongolian), findsNothing);
      }
    });

    testWidgets('the voluntary change: its Back header reads the title, and '
        'Back goes back', (tester) async {
      await pumpVoluntary(tester);

      expect(
        find.descendant(
          of: find.byType(BackTitleHeader),
          matching: find.text('Set your password'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(ResetPasswordScreen), findsNothing);
      expect(find.text('profile'), findsOneWidget);
    });

    testWidgets('each rule is announced by its English label, checked once '
        'met', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpRequired(tester);

      await tester.enterText(field(1), 'abc');
      await tester.pump();
      final weak = ruleStates(tester, LocalePreference.english);
      expect(weak['resetRuleLowercase'], isTrue);
      expect(weak['resetRuleMinLength'], isFalse);
      expect(weak['resetRuleUppercase'], isFalse);

      await tester.enterText(field(1), good);
      await tester.pump();
      expect(
        ruleStates(tester, LocalePreference.english).values,
        everyElement(isTrue),
      );
      semantics.dispose();
    });

    testWidgets('each password field\'s eye announces Show, then Hide', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpRequired(tester);

      expect(find.bySemanticsLabel('Show password'), findsNWidgets(3));
      await tester.tap(find.bySemanticsLabel('Show password').first);
      await tester.pump();
      expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
      expect(find.bySemanticsLabel('Show password'), findsNWidgets(2));
      semantics.dispose();
    });

    testWidgets('validation after the first Save shows the first error, and '
        're-validates on every edit', (tester) async {
      // One message at a time, in field order: current, new, confirm.
      final repository = FakePasswordRepository();
      await pumpRequired(tester, repository: repository);

      await tapSave(tester);
      expect(find.text('Enter your current password'), findsOneWidget);
      expect(repository.calls, isEmpty);

      await tester.enterText(field(0), current);
      await tester.pump();
      expect(find.text('Enter a new password'), findsOneWidget);

      await tester.enterText(field(1), 'weak');
      await tester.pump();
      expect(
        find.text('The password does not meet the requirements'),
        findsOneWidget,
      );

      await tester.enterText(field(1), good);
      await tester.pump();
      expect(find.text('Enter your new password again'), findsOneWidget);

      await tester.enterText(field(2), 'Different1!');
      await tester.pump();
      expect(find.text('Does not match the new password'), findsOneWidget);

      await tester.enterText(field(0), good);
      await tester.enterText(field(2), good);
      await tester.pump();
      expect(
        find.text('The new password must be different from the current one'),
        findsOneWidget,
      );
      expect(repository.calls, isEmpty);
    });
  });

  for (final language in LocalePreference.values) {
    testWidgets(
      'a refused current password reads '
      '"${text('resetInvalidCurrentPassword', language)}" in ${language.name}',
      (tester) async {
        await locale.setPreference(language);
        final repository = FakePasswordRepository(
          failure: const AuthFailure(AuthFailureKind.invalidCredentials),
        );
        await pumpRequired(tester, repository: repository);

        await tester.enterText(field(0), current);
        await tester.enterText(field(1), good);
        await tester.enterText(field(2), good);
        await tapSave(tester);

        expect(repository.calls, hasLength(1));
        expect(
          find.text(text('resetInvalidCurrentPassword', language)),
          findsWidgets,
        );
        expect(find.byType(ResetPasswordScreen), findsOneWidget);
      },
    );

    testWidgets('the voluntary change succeeds with '
        '"${text('resetSuccess', language)}" in ${language.name}', (
      tester,
    ) async {
      await locale.setPreference(language);
      final repository = FakePasswordRepository();
      await pumpVoluntary(tester, repository: repository);

      await tester.enterText(field(0), current);
      await tester.enterText(field(1), good);
      await tester.enterText(field(2), good);
      await tapSave(tester);

      expect(repository.calls, hasLength(1));
      expect(find.text(text('resetSuccess', language)), findsOneWidget);
      // The screen closes back to where it was opened from.
      expect(find.byType(ResetPasswordScreen), findsNothing);
    });

    testWidgets('the required change, once done, opens Home with '
        '"${text('resetSuccess', language)}" in ${language.name} '
        '(home_route)', (tester) async {
      await locale.setPreference(language);
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      await tester.pumpWidget(
        L10nRebuildScope(
          child: MaterialApp(
            theme: AppTheme.light,
            routes: {
              HomeRoutes.adult: (_) => const Scaffold(body: Text('home')),
            },
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => openSignedIn(
                  context,
                  homeRoute: HomeRoutes.adult,
                  mustChangePassword: true,
                ),
                child: const Text('signed in'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('signed in'));
      await tester.pumpAndSettle();
      expect(find.byType(ResetPasswordScreen), findsOneWidget);

      // What the screen calls once `POST /auth/change-password` succeeds —
      // the request itself is covered above.
      tester
          .widget<ResetPasswordScreen>(find.byType(ResetPasswordScreen))
          .onCompleted!();
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(find.text(text('resetSuccess', language)), findsOneWidget);
    });
  }

  testWidgets('switching language on the mounted screen: every label changes; '
      'typed passwords, focus and each rule\'s met state are kept', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpRequired(tester);

    await tester.enterText(field(0), current);
    await tester.enterText(field(1), 'Abcdefgh');
    await tester.enterText(field(2), 'Abc');
    await tester.pump();
    expect(focusOf(tester, 2).hasFocus, isTrue);
    final before = ruleStates(tester, LocalePreference.mongolian);
    // Some met, some not: the switch must carry both.
    expect(before.values, containsAll([true, false]));

    await locale.setEnglish(true);
    await tester.pump();

    for (final key in [
      'resetTitle',
      'resetCurrentPassword',
      'resetNewPassword',
      'resetConfirmPassword',
      'resetRequirementsTitle',
      'resetSubmit',
    ]) {
      expect(
        find.text(text(key, LocalePreference.english)),
        findsOneWidget,
        reason: key,
      );
      expect(
        find.text(text(key, LocalePreference.mongolian)),
        findsNothing,
        reason: key,
      );
    }
    expect(find.bySemanticsLabel('Show password'), findsNWidgets(3));
    expect(ruleStates(tester, LocalePreference.english), before);
    expect(tester.widget<EditableText>(field(0)).controller.text, current);
    expect(tester.widget<EditableText>(field(1)).controller.text, 'Abcdefgh');
    expect(tester.widget<EditableText>(field(2)).controller.text, 'Abc');
    expect(focusOf(tester, 2).hasFocus, isTrue);

    await locale.setEnglish(false);
    await tester.pump();
    expect(
      find.text(text('resetTitle', LocalePreference.mongolian)),
      findsOneWidget,
    );
    expect(ruleStates(tester, LocalePreference.mongolian), before);
    semantics.dispose();
  });

  testWidgets('an error already shown keeps its language until the next edit '
      're-validates it', (tester) async {
    await pumpRequired(tester);
    await tapSave(tester);
    expect(
      find.text(
        text('resetCurrentPasswordRequired', LocalePreference.mongolian),
      ),
      findsWidgets,
    );

    await locale.setEnglish(true);
    await tester.pump();
    // Stored when the field was validated, as every controller does.
    expect(
      find.text(
        text('resetCurrentPasswordRequired', LocalePreference.mongolian),
      ),
      findsWidgets,
    );

    await tester.enterText(field(1), 'x');
    await tester.pump();
    expect(find.text('Enter your current password'), findsWidgets);
  });

  group('English at 2.0× text on a 320 pt phone', () {
    const keys = [
      'resetTitle',
      'resetCurrentPassword',
      'resetNewPassword',
      'resetConfirmPassword',
      'resetRequirementsTitle',
      'resetRuleMinLength',
      'resetRuleUppercase',
      'resetRuleLowercase',
      'resetRuleDigit',
      'resetRuleSpecial',
      'resetSubmit',
    ];

    /// Lays the required change out in [language] and returns the keys whose
    /// text is cut short, after checking every label is on screen and inside
    /// the screen's width.
    Future<Set<String>> cutShort(
      WidgetTester tester,
      LocalePreference language,
    ) async {
      await locale.setPreference(language);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpRequired(tester, size: const Size(320, 568));
      expect(tester.takeException(), isNull);
      final cut = <String>{};
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

    testWidgets('lays out without overflow, every label on screen, and cuts '
        'nothing short that Mongolian does not — but the one accepted '
        '"New password"', (tester) async {
      final mongolian = await cutShort(tester, LocalePreference.mongolian);
      final english = await cutShort(tester, LocalePreference.english);

      // KNOWN LIMITATION, accepted for Issue #515: at this size each password
      // field's label has 220 pt beside its eye button. "New password" needs
      // 223, so English cuts it short by 3 pt, empty or filled, where
      // "Шинэ нууц үг" fits. The approved copy and the layout stay as they
      // are. This is the only exception, at this size only: any other label
      // English cuts and Mongolian does not still fails.
      const accepted = {'resetNewPassword'};
      expect(mongolian, isNot(contains('resetNewPassword')));
      expect(english, containsAll(accepted));
      expect(english.difference(mongolian).difference(accepted), isEmpty);
    });
  });
}
