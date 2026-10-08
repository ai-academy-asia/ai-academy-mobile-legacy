import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_learning_back_button.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/home/presentation/widgets/home_header.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_center.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:aia_mobile/features/profile/presentation/widgets/profile_parts.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:aia_mobile/shared/widgets/app_svg_icon.dart';
import 'package:aia_mobile/shared/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/notifications/fake_notification_repository.dart';

/// Dark Mode Phase 3 (Issue #258): the shared components draw their colours
/// from the active theme's `AppPalette`, not from constants.
///
/// Each is pumped under a palette whose roles are unmistakable sentinels —
/// not a dark palette, which is not approved — and must draw those. Light
/// mode itself is held pixel-identical by the existing goldens.
void main() {
  const surface = Color(0xFF010101);
  const textPrimary = Color(0xFF020202);
  const textSecondary = Color(0xFF030303);
  const primary = Color(0xFF040404);
  const onPrimary = Color(0xFFFEFEFE);
  const border = Color(0xFF050505);
  const outline = Color(0xFF060606);
  const divider = Color(0xFF070707);
  const accent = Color(0xFF080808);
  const accentText = Color(0xFF090909);
  const iconInk = Color(0xFF0A0A0A);
  const wordmark = Color(0xFF0B0B0B);
  const linkInk = Color(0xFF0C0C0C);
  const surfaceMuted = Color(0xFF0D0D0D);

  final sentinel = AppPalette.light.copyWith(
    surface: surface,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    primary: primary,
    onPrimary: onPrimary,
    border: border,
    outline: outline,
    divider: divider,
    accent: accent,
    accentText: accentText,
    iconInk: iconInk,
    wordmark: wordmark,
    linkInk: linkInk,
    surfaceMuted: surfaceMuted,
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light.copyWith(extensions: [sentinel]),
        home: Scaffold(body: child),
      ),
    );
    await tester.pump();
  }

  Color? textColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  /// The `srcIn` tint `AppSvgIcon` (and the wordmark) apply.
  ColorFilter tint(Color color) => ColorFilter.mode(color, BlendMode.srcIn);

  group('AppButton', () {
    testWidgets('filled: primary fill, onPrimary label', (tester) async {
      await pump(tester, AppButton(label: 'Go', onPressed: () {}));

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, primary);
      expect(textColor(tester, 'Go'), onPrimary);
    });

    testWidgets('outlined: surface fill, border edge, textPrimary label', (
      tester,
    ) async {
      await pump(
        tester,
        AppButton(
          label: 'Go',
          onPressed: () {},
          variant: AppButtonVariant.outlined,
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, surface);
      expect(textColor(tester, 'Go'), textPrimary);
      final ink = tester.widget<Ink>(find.byType(Ink));
      expect(
        ((ink.decoration! as BoxDecoration).border! as Border).top.color,
        border,
      );
    });
  });

  testWidgets('AppTextField: surface fill, border edge, palette text', (
    tester,
  ) async {
    await pump(
      tester,
      AppTextField(controller: TextEditingController(), placeholder: 'Email'),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    final decoration = field.decoration!;
    expect(decoration.fillColor, surface);
    expect(
      (decoration.enabledBorder! as OutlineInputBorder).borderSide.color,
      border,
    );
    expect(decoration.labelStyle?.color, textSecondary);
    expect(field.style?.color, textPrimary);
  });

  testWidgets('AppBottomNav: surface bar, divider rule, accentText '
      'selection, textSecondary otherwise', (tester) async {
    await pump(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: AppBottomNav(
          currentIndex: 0,
          items: const [
            AppBottomNavItem(icon: AppIcons.house, label: 'Home'),
            AppBottomNavItem(icon: AppIcons.user, label: 'Profile'),
          ],
        ),
      ),
    );

    final bar = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(AppBottomNav),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = bar.decoration as BoxDecoration;
    expect(decoration.color, surface);
    expect((decoration.border! as Border).top.color, divider);
    expect(textColor(tester, 'Home'), accentText);
    expect(textColor(tester, 'Profile'), textSecondary);
  });

  testWidgets('CourseLearningBackButton: surface disc, outline ring, '
      'textPrimary glyph', (tester) async {
    await pump(tester, const CourseLearningBackButton());

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(CourseLearningBackButton),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, surface);
    expect((material.shape! as CircleBorder).side.color, outline);
    expect(tester.widget<Icon>(find.byType(Icon)).color, textPrimary);
  });

  testWidgets('HomeHeader: surface band, iconInk bell, wordmark tint, '
      'accent unread dot', (tester) async {
    final center = NotificationCenter(
      repository: FakeNotificationRepository(
        notifications: [sampleNotification(id: 1)],
      ),
    );
    await pump(tester, HomeHeader(notifications: center));
    await tester.pumpAndSettle();

    final band = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(HomeHeader),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(band.color, surface);

    final bell = tester.widget<SvgPicture>(
      find.descendant(
        of: find.byType(AppSvgIcon),
        matching: find.byType(SvgPicture),
      ),
    );
    expect(bell.colorFilter, tint(iconInk));

    final wordmarkSvg = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .firstWhere((svg) => svg != bell);
    expect(wordmarkSvg.colorFilter, tint(wordmark));

    final dot = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(HomeHeader.unreadBadgeKey),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((dot.decoration as BoxDecoration).color, accent);
    expect(
      find.bySemanticsLabel(RegExp(HomeStrings.notifications)),
      findsOneWidget,
    );
  });

  group('profile parts', () {
    testWidgets('row: iconInk icon, textPrimary label; caption textSecondary; '
        'rule divider', (tester) async {
      await pump(
        tester,
        const Column(
          children: [
            ProfileCaption(ProfileStrings.appSettingsSection),
            ProfileRow(
              icon: ProfileIcons.notification,
              label: ProfileStrings.notification,
            ),
            ProfileRule(),
          ],
        ),
      );

      expect(
        tester
            .widget<SvgPicture>(
              find.descendant(
                of: find.byType(AppSvgIcon),
                matching: find.byType(SvgPicture),
              ),
            )
            .colorFilter,
        tint(iconInk),
      );
      expect(textColor(tester, ProfileStrings.notification), textPrimary);
      expect(
        textColor(tester, ProfileStrings.appSettingsSection),
        textSecondary,
      );
      final rule = tester.widget<Container>(
        find.descendant(
          of: find.byType(ProfileRule),
          matching: find.byType(Container),
        ),
      );
      expect(rule.color, divider);
    });

    testWidgets('switch: accent when on, outline when off', (tester) async {
      await pump(
        tester,
        const Column(
          children: [
            ProfileSwitch(value: true, onChanged: null, semanticLabel: 'on'),
            ProfileSwitch(value: false, onChanged: null, semanticLabel: 'off'),
          ],
        ),
      );

      final tracks = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toList();
      expect(tracks, [accent, outline]);
    });

    testWidgets('MN/EN: accent capsule, linkInk on the selected half, '
        'onPrimary on the other', (tester) async {
      await pump(
        tester,
        const ProfileLanguageToggle(english: false, onChanged: null),
      );

      expect(textColor(tester, ProfileStrings.languageMn), linkInk);
      expect(textColor(tester, ProfileStrings.languageEn), onPrimary);
    });

    testWidgets('log out: surface pill, outline edge, textPrimary label', (
      tester,
    ) async {
      await pump(tester, ProfileLogOutButton(onPressed: () {}));

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(ProfileLogOutButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, surface);
      expect((material.shape! as RoundedRectangleBorder).side.color, outline);
      expect(textColor(tester, ProfileStrings.logOut), textPrimary);
    });

    testWidgets('avatar: surfaceMuted disc, outline ring', (tester) async {
      await pump(tester, const ProfileAvatar());

      final disc = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ProfileAvatar),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = disc.decoration! as BoxDecoration;
      expect(decoration.color, surfaceMuted);
      expect((decoration.border! as Border).top.color, outline);
    });
  });

  testWidgets('in light mode the icons and wordmark draw untinted, exactly '
      'as authored (a same-colour tint still moves edge pixels)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              HomeHeader(
                notifications: NotificationCenter(
                  repository: FakeNotificationRepository(),
                ),
              ),
              const ProfileRow(
                icon: ProfileIcons.notification,
                label: ProfileStrings.notification,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final filters = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .map((svg) => svg.colorFilter)
        .toList();
    // The wordmark, the bell and the row icon.
    expect(filters, hasLength(3));
    expect(filters, everyElement(isNull));
  });

  testWidgets('AppSvgIcon: defaults to iconInk, or takes a colour', (
    tester,
  ) async {
    await pump(
      tester,
      const Column(
        children: [
          AppSvgIcon(ProfileIcons.notification, size: 20),
          AppSvgIcon(
            ProfileIcons.notification,
            size: 20,
            color: Color(0xFF123456),
          ),
        ],
      ),
    );

    final tints = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .map((svg) => svg.colorFilter)
        .toList();
    expect(tints, [tint(iconInk), tint(const Color(0xFF123456))]);
  });
}
