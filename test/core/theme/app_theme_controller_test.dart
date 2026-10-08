import 'package:aia_mobile/app.dart';
import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `AppThemeController` (Issue #252): the one theme state for Adult, Junior
/// and Teacher, read once above the whole navigator.
void main() {
  group('AppThemeController', () {
    test('starts light', () {
      expect(AppThemeController().mode, ThemeMode.light);
      expect(AppThemeController.instance.mode, ThemeMode.light);
    });

    test('setMode changes the mode and tells listeners once', () {
      final controller = AppThemeController();
      var notified = 0;
      controller.addListener(() => notified++);

      controller.setMode(ThemeMode.dark);
      expect(controller.mode, ThemeMode.dark);
      expect(notified, 1);

      controller.setMode(ThemeMode.dark);
      expect(notified, 1, reason: 'the same mode again is not a change');

      controller.setMode(ThemeMode.system);
      expect(controller.mode, ThemeMode.system);
      expect(notified, 2);
    });
  });

  group('AiAcademyApp', () {
    Future<void> pumpApp(
      WidgetTester tester,
      AppThemeController controller,
    ) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(393, 852) * 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(AiAcademyApp(themeController: controller));
    }

    MaterialApp materialApp(WidgetTester tester) =>
        tester.widget<MaterialApp>(find.byType(MaterialApp));

    testWidgets('gives MaterialApp the controller\'s mode, and follows it', (
      tester,
    ) async {
      final controller = AppThemeController();
      await pumpApp(tester, controller);
      expect(materialApp(tester).themeMode, ThemeMode.light);

      controller.setMode(ThemeMode.system);
      await tester.pump();
      expect(materialApp(tester).themeMode, ThemeMode.system);
    });

    testWidgets('one theme for every route: the light palette, whatever '
        'the mode, until a dark theme exists', (tester) async {
      final controller = AppThemeController(ThemeMode.dark);
      await pumpApp(tester, controller);

      // No dark theme yet: nothing a user sees may change.
      expect(materialApp(tester).darkTheme, isNull);
      final context = tester.element(find.byType(Navigator).first);
      expect(Theme.of(context).brightness, Brightness.light);
      expect(context.palette, same(AppPalette.light));
    });
  });
}
