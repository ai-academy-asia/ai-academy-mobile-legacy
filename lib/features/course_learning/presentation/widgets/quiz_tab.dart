import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_quiz.dart';
import '../course_learning_strings.dart';
import 'exercise_submit_button.dart';
import 'exercise_tabs.dart' show exercisePrimaryColor;
import 'exercise_text_field.dart' show exerciseBorderColor;

enum _QuizStage { card, inProgress, result }

/// The Quiz tab: an intro card ("Start Quiz"), the sample questions with
/// single-select answers, a result once submitted, and "Retry Quiz", which
/// clears every answer and starts the questions over.
///
/// **Sample/local state only.** There is no quiz backend to call — each
/// [QuizQuestion.correctOptionIndex] is the sole "grading key", read
/// entirely on-device; see `CourseExerciseDetailScreen`'s own doc comment.
/// [quiz] is null for an exercise with no quiz, in which case this tab
/// renders nothing.
///
/// State lives entirely inside this widget, not lifted to
/// `CourseExerciseDetailScreen` — the same choice `AssignmentTab` already
/// makes for its own progress, for the same reason: switching to another tab
/// and back starts this one over. That is a pre-existing characteristic of
/// how every tab except Note is built here (see `_CourseExerciseDetailScreenState._note`'s
/// own doc comment for why Note alone is the exception), not something this
/// change set was asked to fix.
class QuizTab extends StatefulWidget {
  const QuizTab({required this.quiz, super.key});

  final CourseQuiz? quiz;

  @override
  State<QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<QuizTab> {
  _QuizStage _stage = _QuizStage.card;

  /// Question index → chosen option index.
  final Map<int, int> _selectedOptions = {};

  bool get _allAnswered {
    final quiz = widget.quiz;
    return quiz != null && _selectedOptions.length == quiz.questions.length;
  }

  int get _score {
    final quiz = widget.quiz;
    if (quiz == null) return 0;
    var correct = 0;
    for (var i = 0; i < quiz.questions.length; i++) {
      if (_selectedOptions[i] == quiz.questions[i].correctOptionIndex) {
        correct++;
      }
    }
    return correct;
  }

  void _start() => setState(() => _stage = _QuizStage.inProgress);

  void _selectOption(int questionIndex, int optionIndex) =>
      setState(() => _selectedOptions[questionIndex] = optionIndex);

  void _submit() => setState(() => _stage = _QuizStage.result);

  void _retry() => setState(() {
    _selectedOptions.clear();
    _stage = _QuizStage.inProgress;
  });

  @override
  Widget build(BuildContext context) {
    final quiz = widget.quiz;
    if (quiz == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: switch (_stage) {
        _QuizStage.card => _QuizIntroCard(quiz: quiz, onStart: _start),
        _QuizStage.inProgress => _QuizQuestions(
          quiz: quiz,
          selectedOptions: _selectedOptions,
          onSelect: _selectOption,
          onSubmit: _allAnswered ? _submit : null,
        ),
        _QuizStage.result => _QuizResult(
          score: _score,
          total: quiz.questions.length,
          onRetry: _retry,
        ),
      },
    );
  }
}

/// The sample quiz card: title, question count/estimate, "Start Quiz".
class _QuizIntroCard extends StatelessWidget {
  const _QuizIntroCard({required this.quiz, required this.onStart});

  final CourseQuiz quiz;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 329,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: exerciseBorderColor,
          width: AppDimens.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quiz.title,
            style: AppTypography.cardHeading.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${CourseLearningStrings.quizQuestionCount(quiz.questions.length)} '
            '· ${quiz.estimatedMinutesLabel}',
            style: AppTypography.cardSupporting,
          ),
          const SizedBox(height: 16),
          Center(
            child: ExerciseSubmitButton(
              label: CourseLearningStrings.startQuiz,
              onPressed: onStart,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizQuestions extends StatelessWidget {
  const _QuizQuestions({
    required this.quiz,
    required this.selectedOptions,
    required this.onSelect,
    required this.onSubmit,
  });

  final CourseQuiz quiz;
  final Map<int, int> selectedOptions;
  final void Function(int questionIndex, int optionIndex) onSelect;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < quiz.questions.length; i++) ...[
          _QuizQuestionCard(
            index: i,
            question: quiz.questions[i],
            selectedOption: selectedOptions[i],
            onSelect: (option) => onSelect(i, option),
          ),
          const SizedBox(height: 12),
        ],
        Center(
          child: ExerciseSubmitButton(
            label: CourseLearningStrings.submitQuiz,
            onPressed: onSubmit,
          ),
        ),
      ],
    );
  }
}

class _QuizQuestionCard extends StatelessWidget {
  const _QuizQuestionCard({
    required this.index,
    required this.question,
    required this.selectedOption,
    required this.onSelect,
  });

  final int index;
  final QuizQuestion question;
  final int? selectedOption;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 329,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: exerciseBorderColor,
          width: AppDimens.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${CourseLearningStrings.quizQuestionLabel} ${index + 1}',
            style: AppTypography.catalogSectionLabel,
          ),
          const SizedBox(height: 4),
          Text(
            question.prompt,
            style: AppTypography.cardHeading.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < question.options.length; i++) ...[
            _QuizOptionRow(
              label: question.options[i],
              selected: selectedOption == i,
              onTap: () => onSelect(i),
            ),
            if (i != question.options.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _QuizOptionRow extends StatelessWidget {
  const _QuizOptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? exercisePrimaryColor.withValues(alpha: 0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? exercisePrimaryColor : exerciseBorderColor,
              width: AppDimens.borderWidth,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected
                    ? exercisePrimaryColor
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.cardSupporting.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizResult extends StatelessWidget {
  const _QuizResult({
    required this.score,
    required this.total,
    required this.onRetry,
  });

  final int score;
  final int total;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final passed = total == 0 || score / total >= 0.6;

    return Container(
      width: 329,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: exerciseBorderColor,
          width: AppDimens.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CourseLearningStrings.quizScore(score, total),
            style: AppTypography.cardHeading.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            passed
                ? CourseLearningStrings.quizPassed
                : CourseLearningStrings.quizNeedsReview,
            style: AppTypography.cardSupporting,
          ),
          const SizedBox(height: 16),
          Center(
            child: ExerciseSubmitButton(
              label: CourseLearningStrings.retryQuiz,
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}
