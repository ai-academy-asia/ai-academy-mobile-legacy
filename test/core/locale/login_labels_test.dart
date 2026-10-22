import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/domain/auth_failure.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/presentation/login_screen.dart';
import 'package:aia_mobile/features/auth/presentation/login_strings.dart';
import 'package:aia_mobile/features/auth/presentation/widgets/remember_me_checkbox.dart';
import 'package:aia_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/auth/fake_auth_repository.dart';
import '../../features/profile/fake_current_user_repository.dart';
import '../../support/screenshot.dart';

/// Issue #513: the Login screen and its manager-contact sheet in the
/// selected language. Mongolian reads exactly as before.
void main() {
  setUpAll(loadAppFonts);
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  /// The approved copy, by key.
  const copy = <String, ({String mongolian, String english})>{
    'loginTitle': (mongolian: 'Нэвтрэх', english: 'Log in'),
    'loginIdentifierPlaceholder': (
      mongolian: 'Утасны дугаар / Email хаяг',
      english: 'Phone or email',
    ),
    'loginIdentifierPhoneLabel': (
      mongolian: 'Утасны дугаар',
      english: 'Phone number',
    ),
    'loginIdentifierEmailLabel': (
      mongolian: 'Email хаяг',
      english: 'Email address',
    ),
    'loginPasswordLabel': (mongolian: 'Нууц үг', english: 'Password'),
    'loginRememberMe': (mongolian: 'Намайг сануулах', english: 'Remember me'),
    'loginResetPassword': (
      mongolian: 'Нууц үг сэргээх',
      english: 'Reset password',
    ),
    'loginContactSupporting': (
      mongolian: 'Бүртгэлгүй эсвэл нууц үгээ мартсан бол',
      english: 'No account, or forgot your password?',
    ),
    'loginContactManager': (
      mongolian: 'Менежертэй холбогдоорой',
      english: 'Contact a manager',
    ),
    'loginContactSheetTitle': (
      mongolian: 'Танд асуух зүйл байна уу?',
      english: 'Do you have a question?',
    ),
    'loginContactMessage': (
      mongolian:
          'Сургалт болон бүртгэлтэй холбоотой мэдээлэл авах бол бидэнтэй '
          'холбогдоорой.',
      english: 'Contact us for information about courses and registration.',
    ),
    'loginContactCall': (mongolian: 'Утасдах', english: 'Call'),
    'loginContactEmail': (mongolian: 'Email бичих', english: 'Write an email'),
    'loginIdentifierRequired': (
      mongolian: 'Утасны дугаар эсвэл имэйл хаягаа оруулна уу',
      english: 'Enter your phone number or email address',
    ),
    'loginIdentifierInvalid': (
      mongolian: 'Утасны дугаар эсвэл имэйл хаяг буруу байна',
      english: 'The phone number or email address is not valid',
    ),
    'loginPasswordRequired': (
      mongolian: 'Нууц үгээ оруулна уу',
      english: 'Enter your password',
    ),
    'loginPasswordTooShort': (
      mongolian: 'Нууц үг дор хаяж 6 тэмдэгт байх ёстой',
      english: 'The password must be at least 6 characters',
    ),
    'loginInvalidCredentials': (
      mongolian: 'Утасны дугаар эсвэл нууц үг буруу байна',
      english: 'Incorrect phone number or password',
    ),
    'authShowPassword': (
      mongolian: 'Нууц үг харуулах',
      english: 'Show password',
    ),
    'authHidePassword': (mongolian: 'Нууц үг нуух', english: 'Hide password'),
    // The shared error keys (Issue #507) the screen also shows.
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
    'loginTitle': s.loginTitle,
    'loginIdentifierPlaceholder': s.loginIdentifierPlaceholder,
    'loginIdentifierPhoneLabel': s.loginIdentifierPhoneLabel,
    'loginIdentifierEmailLabel': s.loginIdentifierEmailLabel,
    'loginPasswordLabel': s.loginPasswordLabel,
    'loginRememberMe': s.loginRememberMe,
    'loginResetPassword': s.loginResetPassword,
    'loginContactSupporting': s.loginContactSupporting,
    'loginContactManager': s.loginContactManager,
    'loginContactSheetTitle': s.loginContactSheetTitle,
    'loginContactMessage': s.loginContactMessage,
    'loginContactCall': s.loginContactCall,
    'loginContactEmail': s.loginContactEmail,
    'loginIdentifierRequired': s.loginIdentifierRequired,
    'loginIdentifierInvalid': s.loginIdentifierInvalid,
    'loginPasswordRequired': s.loginPasswordRequired,
    'loginPasswordTooShort': s.loginPasswordTooShort,
    'loginInvalidCredentials': s.loginInvalidCredentials,
    'authShowPassword': s.authShowPassword,
    'authHidePassword': s.authHidePassword,
    'commonNetworkError': s.commonNetworkError,
    'commonServerError': s.commonServerError,
    'commonUnexpectedError': s.commonUnexpectedError,
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

  group('every LoginStrings member', () {
    final members = <(String, String Function(), String)>[
      ('heading', () => LoginStrings.heading, 'loginTitle'),
      (
        'identifierPlaceholder',
        () => LoginStrings.identifierPlaceholder,
        'loginIdentifierPlaceholder',
      ),
      (
        'identifierPhoneLabel',
        () => LoginStrings.identifierPhoneLabel,
        'loginIdentifierPhoneLabel',
      ),
      (
        'identifierEmailLabel',
        () => LoginStrings.identifierEmailLabel,
        'loginIdentifierEmailLabel',
      ),
      ('passwordLabel', () => LoginStrings.passwordLabel, 'loginPasswordLabel'),
      ('rememberMe', () => LoginStrings.rememberMe, 'loginRememberMe'),
      ('signIn', () => LoginStrings.signIn, 'loginTitle'),
      ('resetPassword', () => LoginStrings.resetPassword, 'loginResetPassword'),
      (
        'contactSupporting',
        () => LoginStrings.contactSupporting,
        'loginContactSupporting',
      ),
      (
        'contactManager',
        () => LoginStrings.contactManager,
        'loginContactManager',
      ),
      (
        'contactSheetTitle',
        () => LoginStrings.contactSheetTitle,
        'loginContactSheetTitle',
      ),
      (
        'contactMessage',
        () => LoginStrings.contactMessage,
        'loginContactMessage',
      ),
      ('contactCall', () => LoginStrings.contactCall, 'loginContactCall'),
      ('contactEmail', () => LoginStrings.contactEmail, 'loginContactEmail'),
      (
        'identifierRequired',
        () => LoginStrings.identifierRequired,
        'loginIdentifierRequired',
      ),
      (
        'identifierInvalid',
        () => LoginStrings.identifierInvalid,
        'loginIdentifierInvalid',
      ),
      (
        'passwordRequired',
        () => LoginStrings.passwordRequired,
        'loginPasswordRequired',
      ),
      (
        'passwordTooShort',
        () => LoginStrings.passwordTooShort,
        'loginPasswordTooShort',
      ),
      (
        'invalidCredentials',
        () => LoginStrings.invalidCredentials,
        'loginInvalidCredentials',
      ),
      ('networkError', () => LoginStrings.networkError, 'commonNetworkError'),
      ('serverError', () => LoginStrings.serverError, 'commonServerError'),
      (
        'unexpectedError',
        () => LoginStrings.unexpectedError,
        'commonUnexpectedError',
      ),
      ('showPassword', () => LoginStrings.showPassword, 'authShowPassword'),
      ('hidePassword', () => LoginStrings.hidePassword, 'authHidePassword'),
    ];

    test('are all 24', () => expect(members, hasLength(24)));

    for (final language in LocalePreference.values) {
      test(language.name, () async {
        await locale.setPreference(language);
        for (final (name, member, key) in members) {
          expect(member(), text(key, language), reason: name);
        }
      });
    }
  });

  Future<void> pumpLogin(
    WidgetTester tester, {
    FakeAuthRepository? repository,
    Size size = const Size(393, 852),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: LoginScreen(
            repository: repository ?? FakeAuthRepository(),
            // Never the app-wide store.
            sessionStore: AuthSessionStore(),
            currentUserRepository: FakeCurrentUserRepository(hold: true),
            openUrl: (_) async => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(int index) => find.byType(EditableText).at(index);
  FocusNode focusOf(WidgetTester tester, int index) =>
      tester.widget<EditableText>(field(index)).focusNode;
  bool rememberMe(WidgetTester tester) =>
      tester.widget<RememberMeCheckbox>(find.byType(RememberMeCheckbox)).value;

  Future<void> tapSignIn(WidgetTester tester) async {
    final button = find.text(LoginStrings.signIn).last;
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('in English: the heading, fields, buttons and contact card', (
    tester,
  ) async {
    await locale.setEnglish(true);
    await pumpLogin(tester);

    // The heading and the button are the one "Log in".
    expect(find.text('Log in'), findsNWidgets(2));
    expect(find.text('Phone or email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('No account, or forgot your password?'), findsOneWidget);
    expect(find.text('Contact a manager'), findsOneWidget);
    expect(find.text('Нэвтрэх'), findsNothing);
  });

  testWidgets('in English: the password toggle announces Show, then Hide', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await locale.setEnglish(true);
    await pumpLogin(tester);

    expect(find.bySemanticsLabel('Show password'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Show password'));
    await tester.pump();
    expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
    expect(find.bySemanticsLabel('Show password'), findsNothing);
    semantics.dispose();
  });

  testWidgets('in English: the contact sheet', (tester) async {
    await locale.setEnglish(true);
    await pumpLogin(tester);

    await tester.ensureVisible(find.text('Contact a manager'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contact a manager'));
    await tester.pumpAndSettle();

    expect(find.text('Do you have a question?'), findsOneWidget);
    expect(
      find.text('Contact us for information about courses and registration.'),
      findsOneWidget,
    );
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Write an email'), findsOneWidget);
    // The business's contact, unchanged.
    expect(find.text('+976 7505 1055'), findsOneWidget);
    expect(find.text('info@ai-academy.asia'), findsOneWidget);
  });

  testWidgets('switching language on the mounted screen: every label changes; '
      'typed input, focus and Remember me are kept', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpLogin(tester);

    await tester.enterText(field(0), 'student@example.com');
    await tester.enterText(field(1), 'secret123');
    await tester.tap(find.byType(RememberMeCheckbox));
    await tester.pump();
    final wasRemembered = rememberMe(tester);
    expect(focusOf(tester, 1).hasFocus, isTrue);
    // An email is recognised: the field floats its email label.
    expect(find.text('Email хаяг'), findsOneWidget);

    await locale.setEnglish(true);
    await tester.pump();

    expect(find.text('Log in'), findsNWidgets(2));
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Contact a manager'), findsOneWidget);
    expect(find.bySemanticsLabel('Show password'), findsOneWidget);
    for (final key in copy.keys) {
      expect(find.text(text(key, LocalePreference.mongolian)), findsNothing);
    }
    // Nothing the person did is lost.
    expect(find.text('student@example.com'), findsOneWidget);
    expect(tester.widget<EditableText>(field(1)).controller.text, 'secret123');
    expect(focusOf(tester, 1).hasFocus, isTrue);
    expect(rememberMe(tester), wasRemembered);

    await locale.setEnglish(false);
    await tester.pump();
    expect(find.text('Нэвтрэх'), findsNWidgets(2));
    expect(find.text('Email хаяг'), findsOneWidget);
    expect(rememberMe(tester), wasRemembered);
    semantics.dispose();
  });

  testWidgets('in English: validation after the first submit, and its '
      're-validation on every edit', (tester) async {
    final repository = FakeAuthRepository();
    await locale.setEnglish(true);
    await pumpLogin(tester, repository: repository);

    await tapSignIn(tester);
    // The first field's error is the one shown; nothing was sent.
    expect(find.text('Enter your phone number or email address'), findsWidgets);
    expect(repository.calls, isEmpty);

    // From now on each edit re-validates.
    await tester.enterText(field(0), 'not an address');
    await tester.pump();
    expect(
      find.text('The phone number or email address is not valid'),
      findsWidgets,
    );

    await tester.enterText(field(0), 'student@example.com');
    await tester.enterText(field(1), '123');
    await tester.pump();
    expect(
      find.text('The password must be at least 6 characters'),
      findsWidgets,
    );

    await tester.enterText(field(1), '');
    await tester.pump();
    expect(find.text('Enter your password'), findsWidgets);
  });

  testWidgets('an error already shown keeps its language until the next '
      'edit re-validates it', (tester) async {
    await pumpLogin(tester);
    await tapSignIn(tester);
    expect(
      find.text(text('loginIdentifierRequired', LocalePreference.mongolian)),
      findsWidgets,
    );

    await locale.setEnglish(true);
    await tester.pump();
    // Stored when the field was validated, as every controller does.
    expect(
      find.text(text('loginIdentifierRequired', LocalePreference.mongolian)),
      findsWidgets,
    );

    await tester.enterText(field(0), 'x');
    await tester.pump();
    expect(
      find.text('The phone number or email address is not valid'),
      findsWidgets,
    );
  });

  for (final language in LocalePreference.values) {
    testWidgets(
      'a refused sign-in reads "${text('loginInvalidCredentials', language)}" '
      'in ${language.name}',
      (tester) async {
        await locale.setPreference(language);
        final repository = FakeAuthRepository(
          failure: const AuthFailure(AuthFailureKind.invalidCredentials),
        );
        await pumpLogin(tester, repository: repository);

        await tester.enterText(field(0), 'student@example.com');
        await tester.enterText(field(1), 'secret123');
        await tapSignIn(tester);

        expect(repository.calls, hasLength(1));
        expect(
          find.text(text('loginInvalidCredentials', language)),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('in English at 1.5× text on a 393 pt phone, the empty field\'s '
      'placeholder is whole', (tester) async {
    // The longer "Phone number / Email address" was cut short here, where
    // the Mongolian is not; "Phone or email" fits.
    await locale.setEnglish(true);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpLogin(tester);

    expect(tester.takeException(), isNull);
    final placeholder = find.text('Phone or email');
    expect(placeholder, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: placeholder, matching: find.byType(RichText)),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
  });

  group('English at 2.0× text on a 320 pt phone', () {
    Future<void> pumpLarge(
      WidgetTester tester,
      LocalePreference language,
    ) async {
      await locale.setPreference(language);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpLogin(tester, size: const Size(320, 568));
    }

    /// The screen's labels, by key.
    const keys = [
      'loginTitle',
      'loginIdentifierPlaceholder',
      'loginPasswordLabel',
      'loginRememberMe',
      'loginResetPassword',
      'loginContactSupporting',
      'loginContactManager',
    ];

    /// Lays the screen out in [language] and returns the keys whose text is
    /// cut short (ellipsized or past its line limit), after checking that
    /// every label is on screen and inside the screen's width.
    Future<Set<String>> cutShort(
      WidgetTester tester,
      LocalePreference language,
    ) async {
      await pumpLarge(tester, language);
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
        'nothing short that Mongolian does not', (tester) async {
      // At this size the empty field's one-line placeholder and the contact
      // card's two-line supporting text are cut short in Mongolian too — the
      // screen's existing large-text behaviour, which this change keeps.
      final mongolian = await cutShort(tester, LocalePreference.mongolian);
      final english = await cutShort(tester, LocalePreference.english);

      expect(english.difference(mongolian), isEmpty);
      // The title of every control and the button are whole in English.
      for (final key in [
        'loginTitle',
        'loginPasswordLabel',
        'loginRememberMe',
        'loginResetPassword',
        'loginContactManager',
      ]) {
        expect(english, isNot(contains(key)), reason: key);
      }
    });

    testWidgets('the contact sheet opens and both options are whole', (
      tester,
    ) async {
      await pumpLarge(tester, LocalePreference.english);
      await tester.ensureVisible(find.text('Contact a manager'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Contact a manager'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (final label in ['Call', 'Write an email']) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        final rect = tester.getRect(find.text(label));
        expect(rect.right, lessThanOrEqualTo(320), reason: label);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text(label),
            matching: find.byType(RichText),
          ),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      }
    });
  });
}
