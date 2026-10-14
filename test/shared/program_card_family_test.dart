import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/cohorts/presentation/widgets/cohort_card.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/presentation/widgets/program_card.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/program_widgets.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_class_card.dart';
import 'package:aia_mobile/shared/widgets/track_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/cohorts/fake_cohort_repository.dart' show sampleCohort;
import '../features/teacher/teacher_home_screen_test.dart' show sampleClass;
import '../support/screenshot.dart';

/// The program/cohort card family (Issue #404): Adult Home's `ProgramCard`,
/// the Courses tab's `CohortCard`, Teacher Schedule's `TeacherClassCard` and
/// Teacher Programs' `TeacherProgramCard` share one badge row, one badge, one
/// capsule and one inset — whatever content each then draws.
void main() {
  setUpAll(loadAppFonts);

  /// Each card, with realistic long content where it has a top-row capsule.
  final cards = <String, (Type, Widget)>{
    'Adult Home': (
      ProgramCard,
      const ProgramCard(
        program: EnrolledProgram(
          cohortId: 1,
          cohortName: 'Corporate Leaders — 2026 намар',
          courseTitle: 'AI for Corporate Leaders',
          courseSlug: 'ai-corporate-leaders',
          status: 'finished',
          uiMode: 'adult',
        ),
      ),
    ),
    'Courses': (
      CohortCard,
      CohortCard(cohort: sampleCohort(status: 'finished'), enrolled: true),
    ),
    'Teacher Schedule': (
      TeacherClassCard,
      TeacherClassCard(teacherClass: sampleClass()),
    ),
    'Teacher Programs': (
      TeacherProgramCard,
      TeacherProgramCard(teacherClass: sampleClass(), onDetails: () {}),
    ),
  };

  Future<List<String>> pump(
    WidgetTester tester,
    Widget card, {
    double width = 393,
    double scale = 1,
  }) async {
    useLogicalViewport(tester, Size(width, 1600), padding: iPhonePadding);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.toString());
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: card,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previous;
    }
    return errors;
  }

  /// Every line under [of] is drawn at its full height — clipping raises no
  /// error, so it is measured.
  void expectWhole(WidgetTester tester, Finder of) {
    for (final element
        in find
            .descendant(of: of, matching: find.byType(RichText))
            .evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
        ),
        reason: '"${paragraph.text.toPlainText()}" is clipped',
      );
    }
  }

  for (final MapEntry(key: screen, value: (type, card)) in cards.entries) {
    group(screen, () {
      testWidgets('draws the shared row, badge and inset', (tester) async {
        expect(await pump(tester, card), isEmpty);
        final cardRect = tester.getRect(find.byType(type));
        expect(find.byType(CardBadgeRow), findsOneWidget);

        // The family's inset: the badge 16 in from the side, 24 down.
        final badge = tester.getRect(find.byType(TrackBadge));
        expect(badge.topLeft - cardRect.topLeft, const Offset(16, 24));
        expect(badge.height, trackBadgeHeight);

        // A top-row capsule hangs from the badge's top, flush with the inset
        // — every frame that draws the pair (Issue #404).
        final capsule = find.descendant(
          of: find.byType(CardBadgeRow),
          matching: find.byType(CardCapsule),
        );
        if (capsule.evaluate().isNotEmpty) {
          final rect = tester.getRect(capsule);
          expect(rect.height, cardCapsuleHeight);
          expect(rect.top, moreOrLessEquals(badge.top));
          expect(rect.right, moreOrLessEquals(cardRect.right - 16));
        }
      });

      testWidgets('3.0× text on a 320-wide phone: nothing clipped, the '
          'capsule never over the badge', (tester) async {
        expect(await pump(tester, card, width: 320, scale: 3), isEmpty);
        expectWhole(tester, find.byType(type));
        final badge = tester.getRect(find.byType(TrackBadge));
        final capsule = find.descendant(
          of: find.byType(CardBadgeRow),
          matching: find.byType(CardCapsule),
        );
        if (capsule.evaluate().isNotEmpty) {
          expect(tester.getRect(capsule).overlaps(badge), isFalse);
        }
      });
    });
  }

  group('the family pattern', () {
    for (final screen in ['Adult Home', 'Courses']) {
      testWidgets('$screen: the one artwork, 1:1 from the top-left at full '
          'strength', (tester) async {
        final (type, card) = cards[screen]!;
        await pump(tester, card);
        final pattern = find.descendant(
          of: find.byType(type),
          matching: find.byType(CardPattern),
        );
        expect(pattern, findsOneWidget);
        final svg = tester.widget<SvgPicture>(
          find.descendant(of: pattern, matching: find.byType(SvgPicture)),
        );
        expect(svg.fit, BoxFit.none);
        expect(svg.alignment, Alignment.topLeft);
        expect(
          find.ancestor(of: pattern, matching: find.byType(Opacity)),
          findsNothing,
        );
      });
    }

    testWidgets('Teacher Programs keeps its own drawing until the designer '
        'decides (its frame scales the artwork)', (tester) async {
      final (type, card) = cards['Teacher Programs']!;
      await pump(tester, card);
      expect(
        find.descendant(
          of: find.byType(type),
          matching: find.byType(CardPattern),
        ),
        findsNothing,
      );
    });
  });

  group('CardBadgeRow', () {
    const capsule = CardCapsule(
      label: '124 Students',
      outline: Colors.green,
      fill: Colors.white,
      ink: Colors.green,
      horizontalPadding: 15,
    );

    testWidgets(
      'no track: the capsule keeps the top-right corner of a 32 row',
      (tester) async {
        await pump(tester, const CardBadgeRow(trailing: capsule));
        final row = tester.getRect(find.byType(CardBadgeRow));
        final rect = tester.getRect(find.byType(CardCapsule));
        expect(row.height, trackBadgeHeight);
        expect(rect.right, moreOrLessEquals(row.right));
        expect(rect.top, moreOrLessEquals(row.top));
      },
    );

    testWidgets('neither part: nothing is drawn', (tester) async {
      await pump(tester, const CardBadgeRow());
      expect(tester.getSize(find.byType(CardBadgeRow)), Size.zero);
    });

    testWidgets('where both no longer fit, the capsule wraps under the badge', (
      tester,
    ) async {
      await pump(
        tester,
        const CardBadgeRow(track: 'junior', trailing: capsule),
        width: 320,
        scale: 3,
      );
      final badge = tester.getRect(find.byType(TrackBadge));
      final rect = tester.getRect(find.byType(CardCapsule));
      expect(rect.top, greaterThanOrEqualTo(badge.bottom));
      expect(rect.overlaps(badge), isFalse);
    });
  });
}
