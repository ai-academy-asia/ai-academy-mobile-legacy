import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/course_quiz.dart';
import 'course_learning_strings.dart';
import 'course_quiz_result_screen.dart';
import 'widgets/exercise_submit_button.dart';
import 'widgets/quiz_answer_card.dart';
import 'widgets/quiz_feedback_card.dart';
import 'widgets/quiz_progress_header.dart';

/// The Quiz question flow — its own full screen, pushed from
/// `QuizPreviewCard`'s "Start quiz"/"Дахин quiz өгөх", not part of Exercise
/// Detail's tab card. One question at a time: pick an option, see whether it
/// was right, "Үргэлжлүүлэх" (Continue) to the next one, and on the last
/// question, on to `CourseQuizResultScreen` instead.
///
/// **Sample/local state only** — there is no quiz backend to grade against;
/// [quizScore] is the sole "grading key", read entirely on-device.
///
/// Closing with the header's "X" pops back to Exercise Detail with no
/// result, leaving whatever the preview card showed before untouched — only
/// finishing the quiz (via the Result screen's own "Дуусгах") reports a
/// score back up, through [Navigator.pushReplacement]'s `result`, which
/// completes *this* route's own popped future the moment the last question
/// is answered, not whenever the Result screen later pops itself. That is
/// invisible to the student either way, since Exercise Detail sits hidden
/// beneath both screens the entire time.
class CourseQuizScreen extends StatefulWidget {
  const CourseQuizScreen({required this.quiz, super.key});

  final CourseQuiz quiz;

  @override
  State<CourseQuizScreen> createState() => _CourseQuizScreenState();
}

class _CourseQuizScreenState extends State<CourseQuizScreen> {
  int _index = 0;

  /// Question index → chosen option index, for every question answered so
  /// far — carried into `CourseQuizResultScreen` once the quiz finishes.
  final Map<int, int> _answers = {};

  QuizQuestion get _question => widget.quiz.questions[_index];
  int? get _selected => _answers[_index];
  bool get _isLastQuestion => _index == widget.quiz.questions.length - 1;

  void _select(int optionIndex) {
    if (_selected != null) return;
    setState(() => _answers[_index] = optionIndex);
  }

  void _continue() {
    if (_isLastQuestion) {
      Navigator.of(context).pushReplacement<void, ({int correct, int total})>(
        MaterialPageRoute(
          builder: (_) =>
              CourseQuizResultScreen(quiz: widget.quiz, answers: _answers),
        ),
        result: (
          correct: quizScore(widget.quiz, _answers),
          total: widget.quiz.questions.length,
        ),
      );
      return;
    }
    setState(() => _index += 1);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            QuizProgressHeader(
              current: _index + 1,
              total: widget.quiz.questions.length,
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  16,
                  AppDimens.screenPadding,
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _question.prompt,
                      style: AppTypography.heading.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < _question.options.length; i++) ...[
                      if (i != 0) const SizedBox(height: 12),
                      QuizAnswerCard(
                        letter: String.fromCharCode(65 + i),
                        label: _question.options[i],
                        state: switch (selected) {
                          null => QuizAnswerState.normal,
                          _ when selected != i => QuizAnswerState.normal,
                          _ when i == _question.correctOptionIndex =>
                            QuizAnswerState.selectedCorrect,
                          _ => QuizAnswerState.selectedWrong,
                        },
                        onTap: selected == null ? () => _select(i) : null,
                      ),
                    ],
                    if (selected != null) ...[
                      const SizedBox(height: 16),
                      QuizFeedbackCard(
                        correct: selected == _question.correctOptionIndex,
                        correctLetter: String.fromCharCode(
                          65 + _question.correctOptionIndex,
                        ),
                        explanation: _question.explanation,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Center(
                child: ExerciseSubmitButton(
                  label: CourseLearningStrings.quizContinue,
                  onPressed: selected == null ? null : _continue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
