import 'package:aia_mobile/app.dart';
import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/core/theme/app_theme_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'core/locale/fake_locale_persistence.dart';

/// Issue #501: the app root gives `MaterialApp` the chosen language, so
/// Flutter's own widgets — Material, Widgets, Cupertino — follow it.
void main() {
  tearDown(() => ContentLanguage.prefersEnglish = false);

  Future<void> pumpApp(WidgetTester tester, AppLocaleController locale) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(393, 852) * 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AiAcademyApp(
        themeController: AppThemeController(),
        localeController: locale,
      ),
    );
  }

  MaterialApp app(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp));

  /// A context under `MaterialApp`'s localizations.
  BuildContext inside(WidgetTester tester) =>
      tester.element(find.byType(Navigator));

  testWidgets('supports Mongolian and English, with the global delegates', (
    tester,
  ) async {
    await pumpApp(tester, AppLocaleController());

    expect(app(tester).supportedLocales, const [Locale('mn'), Locale('en')]);
    expect(app(tester).localizationsDelegates, [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ]);
  });

  testWidgets('Mongolian by default: Material, Widgets and Cupertino in mn', (
    tester,
  ) async {
    await pumpApp(tester, AppLocaleController());

    expect(app(tester).locale, const Locale('mn'));
    final context = inside(tester);
    expect(Localizations.localeOf(context), const Locale('mn'));
    // Flutter's own Mongolian strings, not its English defaults.
    expect(
      MaterialLocalizations.of(context).cancelButtonLabel,
      isNot(const DefaultMaterialLocalizations().cancelButtonLabel),
    );
    expect(
      CupertinoLocalizations.of(context).todayLabel,
      isNot(const DefaultCupertinoLocalizations().todayLabel),
    );
    expect(WidgetsLocalizations.of(context), isNotNull);
  });

  testWidgets('a saved English opens in English', (tester) async {
    final locale = AppLocaleController();
    await locale.attach(FakeLocalePersistence(stored: 'en'));
    await pumpApp(tester, locale);

    expect(app(tester).locale, const Locale('en'));
    expect(
      MaterialLocalizations.of(inside(tester)).cancelButtonLabel,
      const DefaultMaterialLocalizations().cancelButtonLabel,
    );
    expect(
      CupertinoLocalizations.of(inside(tester)).todayLabel,
      const DefaultCupertinoLocalizations().todayLabel,
    );
  });

  testWidgets('a change applies to MaterialApp at once', (tester) async {
    final locale = AppLocaleController();
    await pumpApp(tester, locale);
    final mongolianCancel = MaterialLocalizations.of(
      inside(tester),
    ).cancelButtonLabel;

    await locale.setEnglish(true);
    await tester.pump();

    expect(app(tester).locale, const Locale('en'));
    expect(Localizations.localeOf(inside(tester)), const Locale('en'));
    final englishCancel = MaterialLocalizations.of(
      inside(tester),
    ).cancelButtonLabel;
    expect(englishCancel, isNot(mongolianCancel));

    await locale.setEnglish(false);
    await tester.pump();

    expect(app(tester).locale, const Locale('mn'));
    expect(
      MaterialLocalizations.of(inside(tester)).cancelButtonLabel,
      mongolianCancel,
    );
  });
}
