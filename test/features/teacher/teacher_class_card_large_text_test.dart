import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';
import 'package:aia_mobile/features/contracts/presentation/widgets/contract_card.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_class.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/gradebook_widgets.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_class_card.dart';
import 'package:aia_mobile/shared/widgets/track_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../cohorts/fake_cohort_repository.dart';
import 'fake_teacher_home_repository.dart';
import 'teacher_home_screen_test.dart' show tuesday;

/// The Teacher class card and the shared [CardCapsule] / [TrackBadge] at
/// larger system text sizes (Issue #351). A long room name used to run off
/// the card from 1.3× on a 320-wide phone, and the capsule and badge — fixed
/// at 24 and 32 — clipped their labels from 1.5× and 2.0×. Now the room
/// line wraps, the capsule and badge grow with their labels, and the count
/// wraps under the badge when both no longer fit on one line.
void main() {
  setUpAll(loadAppFonts);

  const widths = [320.0, 375.0, 393.0];
  const scales = [1.0, 1.5, 2.0, 3.0];

  const room = 'Төв байр, 3-р давхар, 304 тоот';
  const students = '124 Students';

  /// Realistic long content: a Mongolian course title, cohort and room,
  /// and a three-digit count.
  TeacherClass longClass({String? track = 'junior'}) => TeacherClass(
    cohort: sampleCohort(
      id: 2,
      name: '2026 оны намрын улирлын 03-р бүлэг',
      course: const CohortCourse(
        id: 8,
        slug: 'ai-engineering',
        title: LocalizedText(
          mn: 'Хиймэл оюун ухааны инженерчлэлийн ахисан түвшний сургалт',
          en: 'Advanced AI Engineering',
        ),
      ),
      classroom: const CohortClassroom(id: 3, name: room, centerName: 'Төв'),
      enrolledCount: 124,
      startTime: '09:00',
      endTime: '10:00',
      startDate: '2026-09-01',
      endDate: '2026-12-20',
      meetingDays: const ['tue'],
    ),
    track: track,
  );

  /// Pumps [child] and returns every error it raised.
  Future<List<String>> pump(
    WidgetTester tester,
    Widget child, {
    required double width,
    required double scale,
  }) async {
    useLogicalViewport(tester, Size(width, 1600), padding: iPhonePadding);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.toString());
    try {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: child));
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previous;
    }
    return errors;
  }

  /// Every line under [of] is drawn at its full height and inside [bounds].
  void expectWhole(WidgetTester tester, Finder of, Rect bounds) {
    for (final element
        in find
            .descendant(of: of, matching: find.byType(RichText))
            .evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      final text = paragraph.text.toPlainText();
      // Through every transform above it — the contract card scales its
      // pill down to fit (a `FittedBox`), by design.
      final box = MatrixUtils.transformRect(
        paragraph.getTransformTo(null),
        Offset.zero & paragraph.size,
      );
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
        ),
        reason: '"$text" is drawn at its full height',
      );
      expect(box.left, greaterThanOrEqualTo(bounds.left - 0.01), reason: text);
      expect(box.right, lessThanOrEqualTo(bounds.right + 0.01), reason: text);
      expect(box.top, greaterThanOrEqualTo(bounds.top - 0.01), reason: text);
      expect(box.bottom, lessThanOrEqualTo(bounds.bottom + 0.01), reason: text);
    }
  }

  for (final width in widths) {
    for (final scale in scales) {
      final name = '${width.toInt()} wide, text ×$scale';

      testWidgets('$name: the card holds a long room name, title and cohort '
          'and a three-digit count whole, without overflow', (tester) async {
        final errors = await pump(
          tester,
          TeacherHomeScreen(
            clock: tuesday,
            repository: FakeTeacherHomeRepository(classes: [longClass()]),
          ),
          width: width,
          scale: scale,
        );
        expect(errors, isEmpty);

        final card = find.byType(TeacherClassCard);
        final cardRect = tester.getRect(card);
        expectWhole(tester, card, cardRect);
        expect(find.text(room), findsOneWidget);
        expect(find.text(students), findsOneWidget);

        final capsule = tester.getRect(find.byType(CardCapsule));
        final badge = tester.getRect(find.byType(TrackBadge));
        expect(capsule.height, greaterThanOrEqualTo(24));
        expect(badge.height, greaterThanOrEqualTo(32));
        if (scale == 1.0) {
          // The one 32-tall row it always was: the badge left, the count
          // right, centred on it.
          expect(capsule.height, 24);
          expect(badge.height, 32);
          expect(capsule.center.dy, moreOrLessEquals(badge.center.dy));
          expect(capsule.right, moreOrLessEquals(cardRect.right - 16));
        }
      });
    }
  }

  testWidgets('with no track, the count keeps the right end of a 32-tall row', (
    tester,
  ) async {
    final errors = await pump(
      tester,
      TeacherHomeScreen(
        clock: tuesday,
        repository: FakeTeacherHomeRepository(
          classes: [longClass(track: null)],
        ),
      ),
      width: 393,
      scale: 1,
    );
    expect(errors, isEmpty);
    expect(find.byType(TrackBadge), findsNothing);
    final cardRect = tester.getRect(find.byType(TeacherClassCard));
    final capsule = tester.getRect(find.byType(CardCapsule));
    expect(capsule.right, moreOrLessEquals(cardRect.right - 16));
    // Centred in the 32 the badge would have taken: 24 from the card's
    // 24 inset, (32 - 24) / 2 further down.
    expect(capsule.top, moreOrLessEquals(cardRect.top + 24 + 4));
  });

  group('CardCapsule', () {
    Widget capsule() => const CardCapsule(
      label: students,
      outline: Colors.green,
      fill: Colors.white,
      ink: Colors.green,
      horizontalPadding: 15,
    );

    for (final scale in scales) {
      testWidgets('text ×$scale: at least 24 tall, as tall as its label '
          'needs, and only as wide as its label — in a Row or a bounded box', (
        tester,
      ) async {
        for (final parent in <Widget Function(Widget)>[
          (child) => Row(children: [child]),
          // Bounded but loose: a box may offer room, not demand it.
          (child) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300, maxHeight: 200),
            child: child,
          ),
        ]) {
          final errors = await pump(
            tester,
            Scaffold(body: Center(child: parent(capsule()))),
            width: 393,
            scale: scale,
          );
          expect(errors, isEmpty);

          final rect = tester.getRect(find.byType(CardCapsule));
          final label = tester.getRect(find.text(students));
          expectWhole(tester, find.byType(CardCapsule), rect);
          expect(rect.height, greaterThanOrEqualTo(24));
          if (scale == 1.0) expect(rect.height, 24);
          // Never stretched: the label, its padding and the 1pt edge.
          expect(rect.width, moreOrLessEquals(label.width + 2 * 15 + 2));
          expect(
            rect.height,
            moreOrLessEquals(label.height + 2 > 24 ? label.height + 2 : 24),
          );
        }
      });
    }

    for (final scale in scales) {
      testWidgets('text ×$scale: the consumers — a contract card and a '
          'gradebook stat card — show their capsule labels whole', (
        tester,
      ) async {
        const contract = StudentContract(
          id: '12',
          status: StudentContractStatus.pending,
          canSign: true,
          canView: true,
          isCurrent: true,
          course: ContractCourse(titleEn: 'Test Course', level: 'adult'),
          cohort: ContractCohort(name: 'Test Cohort'),
        );
        final errors = await pump(
          tester,
          const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  ContractCard(contract: contract),
                  SizedBox(height: 16),
                  GradebookStatCard(title: 'Даалгавар', value: '124 / 240'),
                ],
              ),
            ),
          ),
          width: 393,
          scale: scale,
        );
        expect(errors, isEmpty);
        for (final element in find.byType(CardCapsule).evaluate()) {
          final finder = find.byElementPredicate((e) => e == element);
          expectWhole(tester, finder, tester.getRect(finder));
        }
      });
    }
  });
}
