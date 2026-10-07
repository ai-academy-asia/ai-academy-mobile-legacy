import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/quiz_answer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// The shared quiz option row (Adult and Junior): at least the frames' 56,
/// and taller for a long answer, never clipping it (Issue #225).
void main() {
  setUpAll(loadAppFonts);

  const short = 'Хиймэл оюун';
  const long =
      'Machine learning is a field of artificial intelligence that lets '
      'computers learn patterns from data and improve at a task with '
      'experience, without being explicitly programmed for every rule.';

  Future<void> pumpCard(
    WidgetTester tester, {
    required String label,
    QuizAnswerState state = QuizAnswerState.normal,
    double width = 393,
  }) async {
    useLogicalViewport(tester, Size(width, 852));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: QuizAnswerCard(
                letter: 'A',
                label: label,
                state: state,
                onTap: null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect cardRect(WidgetTester tester) =>
      tester.getRect(find.byType(QuizAnswerCard));
  Rect labelRect(WidgetTester tester, String label) =>
      tester.getRect(find.text(label));
  Finder stateIcon() => find.byType(SvgPicture);

  /// The label sits wholly inside the card's padding — nothing clipped.
  void expectLabelInside(WidgetTester tester, String label) {
    final card = cardRect(tester);
    final text = labelRect(tester, label);
    expect(text.top, greaterThanOrEqualTo(card.top + 1));
    expect(text.bottom, lessThanOrEqualTo(card.bottom - 1));
    expect(text.right, lessThanOrEqualTo(card.right - 1));
  }

  testWidgets('a short answer keeps the frames\' 56', (tester) async {
    await pumpCard(tester, label: short);

    expect(cardRect(tester).height, 56);
    expectLabelInside(tester, short);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long answer wraps in full and grows the card', (tester) async {
    await pumpCard(tester, label: long);

    final card = cardRect(tester);
    final text = labelRect(tester, long);
    // Several 20pt lines, all of them laid out — no ellipsis, no max lines.
    expect(text.height, greaterThanOrEqualTo(60));
    expect(tester.widget<Text>(find.text(long)).maxLines, isNull);
    expect(card.height, greaterThan(56));
    expectLabelInside(tester, long);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the letter sits on the answer\'s first line', (tester) async {
    await pumpCard(tester, label: long);

    final letter = tester.getRect(find.text('A'));
    final text = labelRect(tester, long);
    // Shared baseline: the letter's line box starts with the first line's,
    // not centred against the whole block.
    expect((letter.top - text.top).abs(), lessThanOrEqualTo(2));
  });

  testWidgets('a selected-correct short answer stays 56, its icon inside', (
    tester,
  ) async {
    await pumpCard(
      tester,
      label: short,
      state: QuizAnswerState.selectedCorrect,
    );

    final card = cardRect(tester);
    expect(card.height, 56);
    expect(stateIcon(), findsOneWidget);
    final icon = tester.getRect(stateIcon());
    expect(icon.center.dy, closeTo(card.center.dy, 0.5));
  });

  testWidgets('a long selected-correct answer grows, keeps clear of the '
      'icon, and the icon stays centred on it', (tester) async {
    await pumpCard(tester, label: long, state: QuizAnswerState.selectedCorrect);

    final card = cardRect(tester);
    final text = labelRect(tester, long);
    final icon = tester.getRect(stateIcon());
    expect(card.height, greaterThan(56));
    expectLabelInside(tester, long);
    expect(text.right, lessThanOrEqualTo(icon.left));
    expect(icon.center.dy, closeTo(card.center.dy, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long selected-wrong answer behaves the same', (tester) async {
    await pumpCard(tester, label: long, state: QuizAnswerState.selectedWrong);

    expect(cardRect(tester).height, greaterThan(56));
    expectLabelInside(tester, long);
    expect(stateIcon(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a very long answer on a small phone still fits, with no '
      'overflow', (tester) async {
    final veryLong = List.filled(4, long).join(' ');
    await pumpCard(
      tester,
      label: veryLong,
      state: QuizAnswerState.selectedCorrect,
      width: 320,
    );

    expectLabelInside(tester, veryLong);
    expect(tester.takeException(), isNull);
  });
}
