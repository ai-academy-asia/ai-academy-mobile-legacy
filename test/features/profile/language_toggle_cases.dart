import 'dart:ui' show Tristate;

import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/locale/fake_locale_persistence.dart';

/// The "Хэл / Language" MN/EN control (Issue #501), the same on every
/// Profile: it shows the app's one language and writes it, at once, saved
/// on the device. [pumpWith] pumps the Profile with [controller] in place
/// of `AppLocaleController.instance`.
void profileLanguageToggleCases({
  required Future<void> Function(
    WidgetTester tester,
    AppLocaleController controller,
  )
  pumpWith,
}) {
  group('MN/EN language control (Issue #501)', () {
    tearDown(() => ContentLanguage.prefersEnglish = false);

    /// Whether the [label] segment is announced as selected.
    bool selected(WidgetTester tester, String label) =>
        tester
            .getSemantics(find.bySemanticsLabel(label))
            .flagsCollection
            .isSelected ==
        Tristate.isTrue;

    Future<void> tap(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the app\'s language: MN by default', (tester) async {
      await pumpWith(tester, AppLocaleController());

      expect(selected(tester, ProfileStrings.languageMn), isTrue);
      expect(selected(tester, ProfileStrings.languageEn), isFalse);
    });

    testWidgets('shows English when the device chose it', (tester) async {
      final controller = AppLocaleController();
      await controller.attach(FakeLocalePersistence(stored: 'en'));
      await pumpWith(tester, controller);

      expect(selected(tester, ProfileStrings.languageEn), isTrue);
      expect(selected(tester, ProfileStrings.languageMn), isFalse);
    });

    testWidgets('EN switches the app to English and saves it; MN switches '
        'back', (tester) async {
      final persistence = FakeLocalePersistence();
      final controller = AppLocaleController();
      await controller.attach(persistence);
      await pumpWith(tester, controller);

      await tap(tester, ProfileStrings.languageEn);

      expect(controller.preference, LocalePreference.english);
      expect(ContentLanguage.prefersEnglish, isTrue);
      expect(persistence.stored, 'en');
      expect(selected(tester, ProfileStrings.languageEn), isTrue);

      await tap(tester, ProfileStrings.languageMn);

      expect(controller.preference, LocalePreference.mongolian);
      expect(ContentLanguage.prefersEnglish, isFalse);
      expect(persistence.stored, 'mn');
      expect(selected(tester, ProfileStrings.languageMn), isTrue);
    });

    testWidgets('a save that fails still switches for this session', (
      tester,
    ) async {
      final persistence = FakeLocalePersistence()..failWrite = true;
      final controller = AppLocaleController();
      await controller.attach(persistence);
      await pumpWith(tester, controller);

      await tap(tester, ProfileStrings.languageEn);

      expect(controller.preference, LocalePreference.english);
      expect(selected(tester, ProfileStrings.languageEn), isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
