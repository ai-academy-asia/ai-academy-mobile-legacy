import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

enum QuizAnswerState { normal, selectedCorrect, selectedWrong }

/// Sampled off the Quiz frames at 1:1. An unanswered row is outlined in
/// [_border] and carries a flat band of the same colour beneath it, the same
/// depth idiom the Course Learning cards use; a row the student has picked
/// swaps the outline for its state colour and drops the band.
const Color _border = Color(0xFFEAEDF0);
const Color _correct = Color(0xFF14AE5C);
const Color _wrong = Color(0xFFEF4444);
const Color _letterInk = Color(0xFF8A8A8A);
const Color _labelInk = Color(0xFF1A1A1A);
const double _depthOffset = 4;
const double _letterToLabel = 23;
const double _stateIconBox = 24;

/// The frames' row is 56 tall; that is now the card's *minimum*, so a long
/// answer grows the card instead of being clipped (Issue #225).
///
/// The vertical padding leaves exactly the 24 state icon inside the 56, the
/// 1pt outline included — (56 − 24) / 2 − 1 = 15 — so an answered one-line
/// row stays 56, and a one-line answer stays centred where the frames draw
/// it. The horizontal 16 is the frames' own inset.
const double _minHeight = 56;
const double _horizontalPadding = 16;
const double _verticalPadding =
    (_minHeight - _stateIconBox) / 2 - AppDimens.borderWidth;

/// One option row on `CourseQuizScreen`, 361 wide and at least 56 tall: a
/// letter (A/B/C/D), the option's own text — wrapped in full, never cut
/// short — and, once the student has answered, a state icon on the trailing
/// edge. Shared by the Adult and Junior quiz. The option that was *not*
/// picked stays in [QuizAnswerState.normal] even when the pick was wrong,
/// matching the reference (it does not also highlight the correct answer).
class QuizAnswerCard extends StatelessWidget {
  const QuizAnswerCard({
    required this.letter,
    required this.label,
    required this.state,
    required this.onTap,
    super.key,
  });

  final String letter;
  final String label;
  final QuizAnswerState state;

  /// Null once an answer has been locked in for this question — the row no
  /// longer responds to taps.
  final VoidCallback? onTap;

  Color get _color => switch (state) {
    QuizAnswerState.normal => _border,
    QuizAnswerState.selectedCorrect => _correct,
    QuizAnswerState.selectedWrong => _wrong,
  };

  bool get _answered => state != QuizAnswerState.normal;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: state != QuizAnswerState.normal,
      label: label,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: _minHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: _horizontalPadding,
              vertical: _verticalPadding,
            ),
            decoration: BoxDecoration(
              // Repeated here, not left to the `Material` behind: the band
              // below is a zero-blur shadow, which paints the card's whole
              // silhouette shifted down, so without an opaque background on
              // this same decoration it covers the card itself.
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _color, width: AppDimens.borderWidth),
              // Only the unanswered rows sit on a band; the frames draw the
              // picked one flat against the page.
              boxShadow: _answered
                  ? null
                  : const [
                      BoxShadow(
                        color: _border,
                        offset: Offset(0, _depthOffset),
                      ),
                    ],
            ),
            // Centres a short answer in the 56 minimum without ever
            // growing past its content: `heightFactor: 1` keeps the card as
            // tall as the answer, whatever height its parent offers.
            child: Align(
              alignment: Alignment.centerLeft,
              heightFactor: 1,
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      // The letter sits on the answer's first line, however
                      // many lines the answer wraps to.
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          letter,
                          // The letter stays grey in every state — the frames
                          // do not tint it with the answer's own colour.
                          style: AppTypography.cardHeading.copyWith(
                            color: _letterInk,
                          ),
                        ),
                        const SizedBox(width: _letterToLabel),
                        Expanded(
                          child: Text(
                            label,
                            style: AppTypography.settingsRowLabel.copyWith(
                              color: _labelInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // The design's own state glyphs, drawn at their natural 24
                  // box (the stroked artwork inside spans the 20 the frames
                  // measure). They carry their own ink, so no tint. Centred on
                  // the answer, with its own gap so a long answer never runs
                  // under it.
                  if (_answered) ...[
                    const SizedBox(width: 12),
                    SvgPicture.asset(
                      state == QuizAnswerState.selectedCorrect
                          ? 'assets/images/course_learning/quiz_correct.svg'
                          : 'assets/images/course_learning/quiz_incorrect.svg',
                      width: _stateIconBox,
                      height: _stateIconBox,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
