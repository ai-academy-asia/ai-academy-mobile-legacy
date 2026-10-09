import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../course_learning_strings.dart';

/// Shown under the answer list once the student has picked one: a green
/// "correct" title, or a red "wrong" title with the correct letter spelled
/// out, either way followed by the question's own explanation.
/// Sampled off the Quiz frames at 1:1: a 24-padded card with an
/// `AppPalette.outlineFaint` edge, its heading in the state's own ink
/// (`successInk` / `errorInk`), the correct answer in `textStrong` and the
/// explanation in `textMuted`.
const double _padding = 24;
const double _titleToAnswer = 6;

/// The heading sits closer to the body when there is no "the answer was X"
/// line between them — the frames draw the two cases differently rather than
/// sharing one gap.
const double _titleToExplanation = 4;
const double _answerToExplanation = 12;

class QuizFeedbackCard extends StatelessWidget {
  const QuizFeedbackCard({
    required this.correct,
    required this.correctLetter,
    required this.explanation,
    super.key,
  });

  final bool correct;

  /// e.g. "A" — only shown when [correct] is false.
  final String correctLetter;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = correct ? palette.successInk : palette.errorInk;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.outlineFaint,
          width: AppDimens.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correct
                ? CourseLearningStrings.quizCorrectTitle
                : CourseLearningStrings.quizWrongTitle,
            style: AppTypography.heading.copyWith(fontSize: 20, color: color),
          ),
          if (!correct) ...[
            const SizedBox(height: _titleToAnswer),
            Text(
              CourseLearningStrings.quizCorrectAnswerIs(correctLetter),
              style: AppTypography.settingsRowLabel.copyWith(
                color: palette.textStrong,
              ),
            ),
            const SizedBox(height: _answerToExplanation),
          ] else
            const SizedBox(height: _titleToExplanation),
          Text(
            explanation,
            style: AppTypography.settingsRowLabel.copyWith(
              color: palette.textMuted,
              height: 20 / 14,
            ),
          ),
        ],
      ),
    );
  }
}
