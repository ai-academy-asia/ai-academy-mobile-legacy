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
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// The contact sheet (Issue #186) on its own: what it shows, and what each
/// way out of it answers.
void main() {
  setUpAll(loadAppFonts);

  /// Opens the sheet from a bare page and records what it completes with.
  Future<List<Uri?>> openSheet(
    WidgetTester tester, {
    Size size = const Size(393, 852),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
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
    expect(find.text('Танд асуух зүйл байна уу?'), findsOneWidget);
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
        'Сургалт болон бүртгэлтэй холбоотой мэдээлэл авах бол бидэнтэй '
        'холбогдоорой.',
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

  testWidgets('heads with a blue chat cue over a section heading and a '
      'readable message', (tester) async {
    await openSheet(tester);

    // The cue: Phosphor ChatCircleDots, blue, on the options' pale-blue
    // round tile at the larger avatar size — above the heading.
    final cue = find.byIcon(AppIcons.chatCircleDots);
    expect(tester.widget<Icon>(cue).color, AppColors.blue);
    final tile = find.ancestor(of: cue, matching: find.byType(Container)).first;
    final fill = tester.widget<Container>(tile).decoration! as BoxDecoration;
    expect(fill.shape, BoxShape.circle);
    expect(fill.color, AppColors.blue.withValues(alpha: 0.12));
    expect(tester.getSize(tile), const Size.square(AppDimens.avatarSize));
    expect(
      tester.getBottomLeft(tile).dy,
      lessThan(tester.getTopLeft(find.text(LoginStrings.contactSheetTitle)).dy),
    );
    expect(
      tester.getCenter(tile).dx,
      moreOrLessEquals(tester.getCenter(sheet()).dx),
    );

    final heading = tester.widget<Text>(
      find.text(LoginStrings.contactSheetTitle),
    );
    expect(heading.style, AppTypography.catalogTitle);
    expect(heading.textAlign, TextAlign.center);
    final message = tester.widget<Text>(find.text(LoginStrings.contactMessage));
    expect(
      message.style,
      AppTypography.statLabel.copyWith(color: AppColors.textPrimary),
    );
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
      // 80 is the card's minimum since Issue #343; at the default size it
      // is exactly 80.
      final card = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.minHeight == AppDimens.cardHeight,
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

  group('every option stays reachable on small screens and at larger text '
      'sizes (Issue #343)', () {
    /// A miss is a failure here, not a warning.
    setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
    tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

    const options = [
      ('Утасдах', '+976 7505 1055'),
      ('Email бичих', 'info@ai-academy.asia'),
    ];
    final links = [ManagerContact.phone, ManagerContact.email];

    /// One option's card — its tappable ink.
    Finder card(String label) =>
        find.ancestor(of: find.text(label), matching: find.byType(InkWell));

    for (final size in const [Size(320, 568), Size(375, 667), Size(393, 852)]) {
      for (final scale in const [1.0, 1.3, 1.5, 2.0, 3.0]) {
        final name =
            '${size.width.toInt()}×${size.height.toInt()}, '
            'text ×$scale';

        Future<List<Uri?>> open(WidgetTester tester) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          return openSheet(tester, size: size);
        }

        group(name, () {
          testWidgets('lays out without overflow, at the user\'s text size, '
              'below the status bar', (tester) async {
            await open(tester);

            expect(tester.takeException(), isNull);
            expect(
              tester.getTopLeft(sheet()).dy,
              greaterThanOrEqualTo(iPhonePadding.top),
            );
            final title = tester.widget<RichText>(
              find.descendant(
                of: find.text(LoginStrings.contactSheetTitle),
                matching: find.byType(RichText),
              ),
            );
            expect(title.textScaler.scale(10), moreOrLessEquals(10 * scale));
          });

          for (final (i, (label, value)) in options.indexed) {
            testWidgets('"$label" can be scrolled to, is fully on screen, '
                'and answers its link', (tester) async {
              final answers = await open(tester);

              await tester.ensureVisible(card(label));
              await tester.pumpAndSettle();
              final rect = tester.getRect(card(label));
              expect(rect.top, greaterThanOrEqualTo(iPhonePadding.top));
              expect(
                rect.bottom,
                lessThanOrEqualTo(size.height - iPhonePadding.bottom),
              );
              // Not cut short: the whole contact is drawn.
              expect(find.text(value), findsOneWidget);

              await tester.tap(find.text(label));
              await tester.pumpAndSettle();

              expect(answers, [links[i]]);
              expect(sheet(), findsNothing);
              expect(tester.takeException(), isNull);
            });
          }

          testWidgets('each option is one button, announced with its '
              'contact', (tester) async {
            final semantics = tester.ensureSemantics();
            final answers = await open(tester);

            for (final (label, value) in options) {
              await tester.ensureVisible(card(label));
              await tester.pumpAndSettle();
              expect(
                tester.getSemantics(find.bySemanticsLabel('$label, $value')),
                isSemantics(
                  label: '$label, $value',
                  isButton: true,
                  hasTapAction: true,
                ),
              );
              // Its text is not read again on its own.
              expect(find.bySemanticsLabel(label), findsNothing);
            }

            // Activated as a screen reader does, the button answers its link.
            final (label, value) = options.last;
            tester.semantics.performAction(
              find.semantics.byLabel('$label, $value'),
              SemanticsAction.tap,
            );
            await tester.pumpAndSettle();
            expect(answers, [ManagerContact.email]);
            semantics.dispose();
          });

          testWidgets('the barrier, a drag down on the cue and system back '
              'all complete with null', (tester) async {
            for (final close in <Future<void> Function()>[
              // The strip above the sheet, under the status bar.
              () => tester.tapAt(Offset(size.width / 2, 20)),
              // The cue never scrolls, so this dismisses at every size.
              () => tester.drag(
                find.byIcon(AppIcons.chatCircleDots),
                Offset(0, size.height),
              ),
              () => tester.binding.handlePopRoute(),
            ]) {
              final answers = await open(tester);
              await close();
              await tester.pumpAndSettle();

              expect(answers, [null]);
              expect(sheet(), findsNothing);
            }
          });
        });
      }
    }

    testWidgets('scrolls when even the full height cannot fit it', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openSheet(tester, size: const Size(320, 568));

      final scroll = tester.state<ScrollableState>(
        find.descendant(of: sheet(), matching: find.byType(Scrollable)),
      );
      expect(scroll.position.maxScrollExtent, greaterThan(0));
    });

    testWidgets('at the default size on the reference phone, the sheet is '
        'only as tall as before and nothing scrolls', (tester) async {
      await openSheet(tester);

      final scroll = tester.state<ScrollableState>(
        find.descendant(of: sheet(), matching: find.byType(Scrollable)),
      );
      expect(scroll.position.maxScrollExtent, 0);
      // Well under Flutter's former 9/16 cap, so lifting it changed nothing.
      expect(tester.getSize(sheet()).height, lessThan(852 * 9 / 16));
    });
  });
}
