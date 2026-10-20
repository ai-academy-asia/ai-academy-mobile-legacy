import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Contact rows, the same on every Profile: "Term of Service" and
/// "Privacy Policy" open the owner's published pages, "Help center" opens
/// nothing yet, and a link the OS will not open says so.
///
/// [pumpWith] pumps the Profile with `openUrl` in place of the platform —
/// no test reaches it. The URLs are spelled out here, not read from the
/// app, so a changed URL fails.
void profileContactLinkCases({
  required String helpCenter,
  required String termsOfService,
  required String privacyPolicy,
  required Future<void> Function(
    WidgetTester tester,
    Future<bool> Function(Uri url) openUrl,
  )
  pumpWith,
}) {
  group('Contact links: Terms of Service and Privacy Policy', () {
    Future<void> tapRow(WidgetTester tester, String label) async {
      final row = find.text(label);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
    }

    for (final (label, url) in [
      (termsOfService, 'https://ai-academy.asia/en/terms'),
      (privacyPolicy, 'https://ai-academy.asia/mn/privacy-policy'),
    ]) {
      testWidgets('"$label" opens $url, and nothing else', (tester) async {
        final opened = <Uri>[];
        await pumpWith(tester, (link) async {
          opened.add(link);
          return true;
        });

        await tapRow(tester, label);

        expect(opened, [Uri.parse(url)]);
        expect(find.byType(SnackBar), findsNothing);
      });
    }

    testWidgets('Help center still opens nothing', (tester) async {
      final opened = <Uri>[];
      await pumpWith(tester, (link) async {
        opened.add(link);
        return true;
      });

      await tapRow(tester, helpCenter);

      expect(opened, isEmpty);
    });

    testWidgets('a link the OS does not open shows the generic error, and '
        'the Profile stays', (tester) async {
      final opened = <Uri>[];
      await pumpWith(tester, (link) async {
        opened.add(link);
        return false;
      });

      await tapRow(tester, privacyPolicy);

      expect(opened, [Uri.parse('https://ai-academy.asia/mn/privacy-policy')]);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(ProfileStrings.unexpectedError),
        ),
        findsOneWidget,
      );
      expect(find.text(privacyPolicy), findsOneWidget);
    });
  });
}
