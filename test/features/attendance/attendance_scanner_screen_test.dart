import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/attendance/presentation/attendance_scanner_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_learning_back_button.dart';
import 'package:aia_mobile/features/home/presentation/widgets/home_pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// The attendance scanner (Issue #202): UI only — no camera, no check-in
/// call.
void main() {
  setUpAll(loadAppFonts);

  Future<void> pump(WidgetTester tester) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AttendanceScannerScreen(),
                  ),
                ),
                child: const Text('home'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  testWidgets('draws the hint and "Гараар оруулах"', (tester) async {
    await pump(tester);

    expect(find.text(AttendanceScannerStrings.hint), findsOneWidget);
    expect(
      find.widgetWithText(HomePillButton, AttendanceScannerStrings.manualEntry),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(AttendanceScannerStrings.window),
      findsOneWidget,
    );
  });

  testWidgets('"Гараар оруулах" is live but leads nowhere yet', (tester) async {
    await pump(tester);
    final manual = find.widgetWithText(
      HomePillButton,
      AttendanceScannerStrings.manualEntry,
    );

    expect(tester.widget<HomePillButton>(manual).onPressed, isNotNull);
    await tester.tap(manual);
    await tester.pumpAndSettle();

    expect(find.byType(AttendanceScannerScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back returns to where it was opened from', (tester) async {
    await pump(tester);

    await tester.tap(find.byType(CourseLearningBackButton));
    await tester.pumpAndSettle();

    expect(find.byType(AttendanceScannerScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('at the reference frame', (tester) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: const AttendanceScannerScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/attendance_scanner.png'),
    );
  });
}
