import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../course_learning_strings.dart';

const String _correctAsset = 'assets/images/course_learning/quiz_correct.svg';
const String _incorrectAsset =
    'assets/images/course_learning/quiz_incorrect.svg';
const double _stateIconBox = 24;

/// One 56pt-tall row in `CourseQuizResultScreen`'s question list: the
/// question's 1-based number, the reference's own generic "Асуулт" label
/// (not each question's own prompt — the reference shows this same label for
/// every row), and a correct/incorrect state icon.
class QuizResultQuestionRow extends StatelessWidget {
  const QuizResultQuestionRow({
    required this.number,
    required this.correct,
    super.key,
  });

  final int number;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 55 here plus the 1pt divider between rows is the reference's 56
      // pitch; at 56 the divider pushed each row a pixel further down.
      height: 55,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text(
                '$number',
                style: AppTypography.cardSupporting.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                CourseLearningStrings.quizResultQuestionLabel,
                style: AppTypography.settingsRowLabel.copyWith(
                  color: context.palette.textPrimary,
                ),
              ),
            ),
            // The design's own state glyphs — the same two assets the quiz
            // answer rows use. They carry their own ink, so no tint.
            SvgPicture.asset(
              correct ? _correctAsset : _incorrectAsset,
              width: _stateIconBox,
              height: _stateIconBox,
            ),
          ],
        ),
      ),
    );
  }
}
