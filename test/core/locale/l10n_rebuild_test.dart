import 'package:aia_mobile/app.dart';
import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/core/theme/app_theme_controller.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/presentation/sign_out_strings.dart';
import 'package:aia_mobile/features/auth/presentation/widgets/sign_out_confirmation_dialog.dart';
import 'package:aia_mobile/features/profile/presentation/profile_screen.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:aia_mobile/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/auth/fake_auth_repository.dart';
import '../../features/profile/fake_current_user_repository.dart';
import '../../support/screenshot.dart' show loadAppFonts;
import 'fake_locale_persistence.dart';

/// Issue #503: a language change redraws the app's own strings at once —
/// without a restart, and without losing navigation or any screen's state.
void main() {
  setUpAll(loadAppFonts);
  tearDown(
    () =>
        AppLocaleController.instance.setPreference(LocalePreference.mongolian),
  );

  final locale = AppLocaleController.instance;

  /// The app root's shape: [L10nRebuildScope] over a `MaterialApp` that
  /// follows the controller, with Flutter's own delegates.
  Widget app({Widget? home, Map<String, WidgetBuilder>? routes}) =>
      L10nRebuildScope(
        child: ListenableBuilder(
          listenable: locale,
          builder: (_, _) => MaterialApp(
            theme: AppTheme.light,
            locale: locale.locale,
            supportedLocales: AppLocaleController.supportedLocales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: home,
            routes: routes ?? const {},
          ),
        ),
      );

  Finder anywhere(String text) => find.text(text, skipOffstage: false);

  testWidgets('a pushed route and the route under it both redraw, keeping '
      'their state', (tester) async {
    await tester.pumpWidget(app(home: const _CounterPage(name: 'under')));
    await tester.tap(find.text('under: 0'));
    await tester.pump();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const _FormPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'typed');

    expect(find.text('Цуцлах'), findsOneWidget);

    await locale.setEnglish(true);
    await tester.pump();

    // The top route: the new language, the typed text kept.
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Цуцлах'), findsNothing);
    expect(find.text('typed'), findsOneWidget);

    // The route under it redrew too, its counter kept.
    expect(anywhere('under: 1'), findsOneWidget);
    expect(anywhere('Log out'), findsOneWidget);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('under: 1'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets('a tab kept alive in an IndexedStack redraws, keeping its '
      'state', (tester) async {
    await tester.pumpWidget(app(home: const _Tabs()));
    await tester.tap(find.text('tab: 0'));
    await tester.pump();
    await tester.tap(find.text('show other tab'));
    await tester.pump();
    expect(find.text('tab: 1'), findsNothing);

    await locale.setEnglish(true);
    await tester.pump();

    expect(anywhere('tab: 1'), findsOneWidget);
    expect(anywhere('Cancel'), findsOneWidget);
    expect(anywhere('Цуцлах'), findsNothing);

    await tester.tap(find.text('show first tab'));
    await tester.pump();
    expect(find.text('tab: 1'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('an open sign-out confirmation redraws and still answers', (
    tester,
  ) async {
    bool? answer;
    await tester.pumpWidget(
      app(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answer = await confirmSignOut(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final dialog = find.byType(SignOutConfirmationDialog);
    Finder inDialog(String text) =>
        find.descendant(of: dialog, matching: find.text(text));
    expect(inDialog('Гарах'), findsOneWidget);

    await locale.setEnglish(true);
    await tester.pump();

    expect(dialog, findsOneWidget);
    expect(inDialog('Log out'), findsOneWidget);
    expect(inDialog('Cancel'), findsOneWidget);
    expect(inDialog('Гарах'), findsNothing);

    await locale.setEnglish(false);
    await tester.pump();
    expect(inDialog('Гарах'), findsOneWidget);
    expect(inDialog('Цуцлах'), findsOneWidget);

    await tester.tap(inDialog('Цуцлах'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
  });

  testWidgets('the Profile MN/EN control switches the app\'s own strings', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(393, 1400) * 3;
    addTearDown(tester.view.reset);
    // No controller injected: the Profile uses the app's own, as in the app.
    await tester.pumpWidget(
      app(
        home: ProfileScreen(
          repository: FakeCurrentUserRepository(hold: true),
          authRepository: FakeAuthRepository(),
          sessionStore: AuthSessionStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(ProfileStrings.languageEn));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ProfileStrings.languageEn));
    await tester.pumpAndSettle();

    expect(locale.english, isTrue);
    expect(L10n.current.localeName, 'en');
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('en'),
    );

    await tester.ensureVisible(find.text(ProfileStrings.logOut));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ProfileStrings.logOut));
    await tester.pumpAndSettle();
    final dialog = find.byType(SignOutConfirmationDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Log out')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Cancel')),
      findsOneWidget,
    );
  });

  group('the app root', () {
    Future<void> pumpRoot(WidgetTester tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(393, 852) * 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AiAcademyApp(themeController: AppThemeController()),
      );
    }

    testWidgets('carries the rebuild scope above MaterialApp', (tester) async {
      await pumpRoot(tester);

      expect(
        find.ancestor(
          of: find.byType(MaterialApp),
          matching: find.byType(L10nRebuildScope),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a change redraws a screen that depends on nothing else', (
      tester,
    ) async {
      await pumpRoot(tester);
      await tester.pumpAndSettle();
      appNavigatorKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const _Probe()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Цуцлах'), findsOneWidget);

      await locale.setEnglish(true);
      await tester.pump();

      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('a saved English is in effect on the first frame', (
      tester,
    ) async {
      await locale.attach(FakeLocalePersistence(stored: 'en'));
      await pumpRoot(tester);

      // The first frame — Splash — already reads the English set. Its only
      // pilot text on screen is the wordmark's label: the brand, the same in
      // both languages.
      expect(L10n.current.localeName, 'en');
      expect(
        Localizations.localeOf(tester.element(find.byType(SplashScreen))),
        const Locale('en'),
      );
      final english = L10n.of(LocalePreference.english);
      expect(
        tester.widget<SvgPicture>(find.byType(SvgPicture)).semanticsLabel,
        '${english.splashWordmarkLine1} ${english.splashWordmarkLine2}',
      );
      expect(SignOutStrings.confirm, 'Log out');
    });
  });
}

/// Reads a pilot string and nothing else — no theme, no `Localizations` —
/// so only [L10nRebuildScope] can redraw it.
class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Text(SignOutStrings.cancel),
  );
}

/// A page with state of its own (a counter) and a pilot string.
class _CounterPage extends StatefulWidget {
  const _CounterPage({required this.name});

  final String name;

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      GestureDetector(
        onTap: () => setState(() => _count++),
        child: Text('${widget.name}: $_count'),
      ),
      Text(SignOutStrings.confirm),
    ],
  );
}

/// A page with a text field (its state) and a pilot string.
class _FormPage extends StatefulWidget {
  const _FormPage();

  @override
  State<_FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<_FormPage> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextField(controller: _text),
        const _Probe(),
      ],
    ),
  );
}

/// Two tabs in an `IndexedStack`, as the app's shells keep them.
class _Tabs extends StatefulWidget {
  const _Tabs();

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextButton(
        onPressed: () => setState(() => _index = 1),
        child: const Text('show other tab'),
      ),
      TextButton(
        onPressed: () => setState(() => _index = 0),
        child: const Text('show first tab'),
      ),
      Expanded(
        child: IndexedStack(
          index: _index,
          children: const [_TabPage(), Text('other tab')],
        ),
      ),
    ],
  );
}

class _TabPage extends StatefulWidget {
  const _TabPage();

  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      GestureDetector(
        onTap: () => setState(() => _count++),
        child: Text('tab: $_count'),
      ),
      const _Probe(),
    ],
  );
}
