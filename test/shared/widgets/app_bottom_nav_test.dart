import 'dart:ui' show Tristate;

import 'package:aia_mobile/core/theme/app_dimens.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/presentation/student_tabs.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/home/presentation/widgets/adult_bottom_nav.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_bottom_nav.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_bottom_nav.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_tabs.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// The shared tab bar at every width and text size (Issue #341), through each
/// role's bar. It used to be a fixed 72 tall, so at 320 wide and 2.0× text its
/// labels overflowed it by 23 and were clipped on every tabbed screen. It
/// now grows with the text; at the default size it is still exactly 72.
void main() {
  setUpAll(loadAppFonts);

  /// A miss is a failure here, not a warning: every tab must be hit as
  /// itself.
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  /// Each role's bar with its first tab current, its labels in tab order,
  /// and every switch recorded by tab index.
  final bars = <String, (List<String>, Widget Function(List<int>))>{
    'adult': (
      const [
        HomeStrings.navHome,
        HomeStrings.navCourses,
        HomeStrings.navProfile,
      ],
      (selected) => AdultBottomNav(
        current: StudentTab.home,
        onSelect: (tab) => selected.add(tab.index),
      ),
    ),
    'junior': (
      const [
        JuniorHomeStrings.navHome,
        JuniorHomeStrings.navProgress,
        JuniorHomeStrings.navProfile,
      ],
      (selected) => JuniorBottomNav(
        current: StudentTab.home,
        onSelect: (tab) => selected.add(tab.index),
      ),
    ),
    'teacher': (
      // Three tabs, Хуваарь first (Issue #370).
      const [
        TeacherHomeStrings.navSchedule,
        TeacherHomeStrings.navGrades,
        TeacherHomeStrings.navProfile,
      ],
      (selected) => TeacherBottomNav(
        current: TeacherTab.schedule,
        onSelect: (tab) => selected.add(tab.index),
      ),
    ),
  };

  const viewHeight = 700.0;

  /// Pumps [bar] as the screens draw it — a `Scaffold`'s
  /// `bottomNavigationBar`, above the home indicator — and returns the
  /// recorded switches.
  Future<List<int>> pump(
    WidgetTester tester,
    Widget Function(List<int>) bar, {
    required double width,
    required double scale,
  }) async {
    useLogicalViewport(tester, Size(width, viewHeight), padding: iPhonePadding);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final selected = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(bottomNavigationBar: bar(selected)),
      ),
    );
    await tester.pumpAndSettle();
    return selected;
  }

  /// One tab's tappable ink.
  Finder tab(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(InkWell));

  for (final MapEntry(key: role, value: (labels, bar)) in bars.entries) {
    for (final width in const [320.0, 393.0]) {
      for (final scale in const [1.0, 1.3, 1.5, 2.0, 2.5, 3.0]) {
        group('$role bar, ${width.toInt()} wide, text ×$scale', () {
          testWidgets('lays out without overflow, every label inside the '
              'bar and on screen', (tester) async {
            await pump(tester, bar, width: width, scale: scale);
            expect(tester.takeException(), isNull);

            final barRect = tester.getRect(find.byType(AppBottomNav));
            expect(barRect.top, greaterThanOrEqualTo(0));
            expect(
              barRect.height,
              greaterThanOrEqualTo(
                AppDimens.bottomNavHeight + iPhonePadding.bottom,
              ),
            );
            for (final label in labels) {
              final text = tester.getRect(find.text(label));
              final ink = tester.getRect(tab(label));
              expect(text.left, greaterThanOrEqualTo(0), reason: label);
              expect(text.right, lessThanOrEqualTo(width), reason: label);
              // Inside its own tab, so nothing is clipped by the bar.
              expect(text.top, greaterThanOrEqualTo(ink.top), reason: label);
              expect(text.bottom, lessThanOrEqualTo(ink.bottom), reason: label);
              expect(
                ink.bottom,
                lessThanOrEqualTo(barRect.bottom - iPhonePadding.bottom),
                reason: '$label stays above the home indicator',
              );
            }
          });

          testWidgets('every tab is hit as itself, and the others switch', (
            tester,
          ) async {
            final selected = await pump(
              tester,
              bar,
              width: width,
              scale: scale,
            );
            for (var i = 0; i < labels.length; i++) {
              // Fatal on a miss: the label is visible and takes the tap.
              await tester.tap(find.text(labels[i]));
              await tester.pump();
            }
            // The current tab (index 0) is inert; every other one switches.
            expect(selected, [for (var i = 1; i < labels.length; i++) i]);
          });

          testWidgets('every tab is a button with its label and selected '
              'state', (tester) async {
            final semantics = tester.ensureSemantics();
            await pump(tester, bar, width: width, scale: scale);
            for (var i = 0; i < labels.length; i++) {
              expect(
                tester.getSemantics(
                  find.descendant(
                    of: find.byType(AppBottomNav),
                    matching: find.bySemanticsLabel(labels[i]),
                  ),
                ),
                isSemantics(
                  label: labels[i],
                  isButton: true,
                  hasSelectedState: true,
                  isSelected: i == 0,
                  hasTapAction: i != 0,
                ),
                reason: labels[i],
              );
            }
            semantics.dispose();
          });
        });
      }
    }

    for (final width in const [320.0, 393.0]) {
      testWidgets('$role bar, ${width.toInt()} wide, default size: exactly '
          '72 tall above the home indicator, every tab the full height', (
        tester,
      ) async {
        await pump(tester, bar, width: width, scale: 1);

        expect(
          tester.getSize(find.byType(AppBottomNav)).height,
          AppDimens.bottomNavHeight + iPhonePadding.bottom,
        );
        for (final label in labels) {
          expect(
            tester.getSize(tab(label)).height,
            AppDimens.bottomNavHeight,
            reason: label,
          );
        }
      });
    }

    for (final scale in const [1.0, 3.0]) {
      testWidgets('$role bar, text ×$scale: each label is announced once, '
          'and activating a tab by assistive tech switches to it', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        final selected = await pump(tester, bar, width: 320, scale: scale);

        for (var i = 0; i < labels.length; i++) {
          // Every node that mentions the label: exactly one, carrying it
          // once — the tab's own. Before Issue #341 the visible text merged
          // into it and a screen reader read "Нүүр\nНүүр".
          final mentions = find.semantics.byPredicate(
            (node) => node.label.contains(labels[i]),
          );
          expect(mentions.evaluate(), hasLength(1), reason: labels[i]);
          final node = mentions.evaluate().single;
          expect(node.label, labels[i]);
          expect(
            node.flagsCollection.isSelected,
            i == 0 ? Tristate.isTrue : Tristate.isFalse,
          );

          if (i != 0) {
            tester.semantics.performAction(mentions, SemanticsAction.tap);
            await tester.pump();
          }
        }
        expect(selected, [for (var i = 1; i < labels.length; i++) i]);
        semantics.dispose();
      });
    }
  }

  /// The label's first line, as laid out.
  String firstLine(WidgetTester tester, String label) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(label), matching: find.byType(RichText)),
    );
    // The first character whose caret sits below the first one starts the
    // second line.
    double top(int offset) =>
        paragraph.getOffsetForCaret(TextPosition(offset: offset), Rect.zero).dy;
    final second = List.generate(
      label.length,
      (i) => i,
    ).firstWhere((i) => top(i) > top(0), orElse: () => label.length);
    return label.substring(0, second).trim();
  }

  // A label wraps between its words wherever each word fits its tab. Where a
  // single word is wider than its tab — e.g. "Профайл", 106pt at 2.0× in a
  // 96pt tab on a 320 phone — no break between words can fit it, so it
  // breaks inside the word: the cost of never capping the text scale.
  for (final (role, label, width) in const [
    ('junior', JuniorHomeStrings.navProgress, 393.0),
    ('teacher', TeacherHomeStrings.navGrades, 393.0),
  ]) {
    testWidgets('$role bar, ${width.toInt()} wide, text ×2.0: "$label" wraps '
        'between its words', (tester) async {
      final (_, bar) = bars[role]!;
      await pump(tester, bar, width: width, scale: 2);
      expect(firstLine(tester, label), label.split(' ').first);
    });
  }

  testWidgets('grows with the text, rather than capping it', (tester) async {
    final (_, bar) = bars['teacher']!;
    await pump(tester, bar, width: 320, scale: 3);
    expect(
      tester.getSize(find.byType(AppBottomNav)).height,
      greaterThan(AppDimens.bottomNavHeight + iPhonePadding.bottom),
    );
    // The label is drawn at the user's size, not shrunk to fit.
    final text = tester.widget<RichText>(
      find.descendant(
        of: find.text(TeacherHomeStrings.navGrades),
        matching: find.byType(RichText),
      ),
    );
    expect(text.textScaler.scale(10), 30);
  });
}
