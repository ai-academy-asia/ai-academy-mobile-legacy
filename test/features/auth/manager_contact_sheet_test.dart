import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:aia_mobile/core/theme/app_dimens.dart';
import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/core/theme/app_typography.dart';
import 'package:aia_mobile/features/auth/presentation/login_strings.dart';
import 'package:aia_mobile/features/auth/presentation/manager_contact.dart';
import 'package:aia_mobile/features/auth/presentation/widgets/manager_contact_sheet.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// The contact sheet (Issue #186) on its own: what it shows, and what each
/// way out of it answers.
void main() {
  setUpAll(loadAppFonts);

  /// Opens the sheet from a bare page and records what it completes with.
  Future<List<Uri?>> openSheet(WidgetTester tester) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    final answers = <Uri?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async =>
                    answers.add(await chooseManagerContact(context)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return answers;
  }

  Finder sheet() => find.byType(ManagerContactSheet);

  testWidgets('shows the heading, its message, and both ways to reach the '
      'manager with their contact — and no Цуцлах (Issue #239)', (
    tester,
  ) async {
    await openSheet(tester);

    expect(sheet(), findsOneWidget);
    expect(find.text('Бид танд туслахад бэлэн'), findsOneWidget);
    // The Login card's own title is not reused as the heading.
    expect(
      find.descendant(
        of: sheet(),
        matching: find.text(LoginStrings.contactManager),
      ),
      findsNothing,
    );
    expect(
      find.text(
        'Асуух зүйл байвал доорх утас, имэйлээр бидэнтэй холбогдоорой.',
      ),
      findsOneWidget,
    );
    expect(find.text('Утасдах'), findsOneWidget);
    expect(find.text('+976 7505 1055'), findsOneWidget);
    expect(find.text('Email бичих'), findsOneWidget);
    expect(find.text('info@ai-academy.asia'), findsOneWidget);
    expect(find.text('Цуцлах'), findsNothing);
    expect(
      find.descendant(of: sheet(), matching: find.byType(AppButton)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('heads with Login\'s heading over the dialog\'s message style', (
    tester,
  ) async {
    await openSheet(tester);

    final heading = tester.widget<Text>(
      find.text(LoginStrings.contactSheetTitle),
    );
    expect(heading.style, AppTypography.heading);
    expect(heading.textAlign, TextAlign.center);
    final message = tester.widget<Text>(find.text(LoginStrings.contactMessage));
    expect(message.style, AppTypography.statLabel);
    expect(
      tester.getTopLeft(find.text(LoginStrings.contactMessage)).dy,
      greaterThan(
        tester.getBottomLeft(find.text(LoginStrings.contactSheetTitle)).dy,
      ),
    );
  });

  testWidgets('each option is a Login contact card: blue glyph on a pale '
      'blue round tile, the action over its contact', (tester) async {
    await openSheet(tester);

    for (final (glyph, label, value) in [
      (AppIcons.phone, 'Утасдах', '+976 7505 1055'),
      (AppIcons.envelope, 'Email бичих', 'info@ai-academy.asia'),
    ]) {
      expect(tester.widget<Icon>(find.byIcon(glyph)).color, AppColors.blue);
      final tile = tester.widget<Container>(
        find
            .ancestor(of: find.byIcon(glyph), matching: find.byType(Container))
            .first,
      );
      final fill = tile.decoration! as BoxDecoration;
      expect(fill.shape, BoxShape.circle);
      expect(fill.color, AppColors.blue.withValues(alpha: 0.12));
      expect(
        tester.getSize(
          find
              .ancestor(
                of: find.byIcon(glyph),
                matching: find.byType(Container),
              )
              .first,
        ),
        const Size.square(AppDimens.statIconTile),
      );
      expect(
        tester.widget<Text>(find.text(label)).style,
        AppTypography.cardHeading,
      );
      expect(
        tester.widget<Text>(find.text(value)).style,
        AppTypography.statLabel,
      );
      final card = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.maxHeight == AppDimens.cardHeight,
        ),
      );
      expect(tester.getSize(card).height, AppDimens.cardHeight);
    }
  });

  testWidgets('keeps Login\'s side margins', (tester) async {
    await openSheet(tester);

    final sheetLeft = tester.getTopLeft(sheet()).dx;
    final cardLeft = tester
        .getTopLeft(
          find.ancestor(
            of: find.text('Утасдах'),
            matching: find.byType(InkWell),
          ),
        )
        .dx;
    expect(cardLeft - sheetLeft, AppDimens.screenPadding);
  });

  testWidgets('draws each option with its Phosphor glyph and the card caret', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.byIcon(AppIcons.phone), findsOneWidget);
    expect(find.byIcon(AppIcons.envelope), findsOneWidget);
    expect(find.byIcon(AppIcons.caretRight), findsNWidgets(2));
  });

  testWidgets('sits on the white surface, capped at the content width', (
    tester,
  ) async {
    await openSheet(tester);

    final bottomSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(bottomSheet.backgroundColor, AppColors.surface);
    expect(tester.getSize(sheet()).width, lessThanOrEqualTo(480));
  });

  testWidgets('Утасдах completes with the phone link', (tester) async {
    final answers = await openSheet(tester);

    await tester.tap(find.text('Утасдах'));
    await tester.pumpAndSettle();

    expect(answers, [ManagerContact.phone]);
    expect(sheet(), findsNothing);
  });

  testWidgets('Email бичих completes with the email link', (tester) async {
    final answers = await openSheet(tester);

    await tester.tap(find.text('Email бичих'));
    await tester.pumpAndSettle();

    expect(answers, [ManagerContact.email]);
    expect(sheet(), findsNothing);
  });

  testWidgets('the barrier, a drag down and system back all complete with '
      'null', (tester) async {
    for (final close in <Future<void> Function()>[
      () => tester.tapAt(const Offset(196, 40)),
      () => tester.drag(
        find.text(LoginStrings.contactSheetTitle),
        const Offset(0, 500),
      ),
      () => tester.binding.handlePopRoute(),
    ]) {
      final answers = await openSheet(tester);
      await close();
      await tester.pumpAndSettle();

      expect(answers, [null]);
      expect(sheet(), findsNothing);
      expect(find.text('open'), findsOneWidget);
    }
  });

  testWidgets('only the first tap counts — a second does not pop the page '
      'underneath', (tester) async {
    final answers = await openSheet(tester);

    await tester.tap(find.text('Утасдах'));
    await tester.tap(find.text('Email бичих'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(answers, [ManagerContact.phone]);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('each option is announced as one button with its contact', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.bySemanticsLabel('Утасдах, +976 7505 1055'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Email бичих, info@ai-academy.asia'),
      findsOneWidget,
    );
  });
}
