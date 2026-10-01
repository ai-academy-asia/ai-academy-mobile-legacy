import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../data/http_course_learning_repository.dart';
import '../domain/course_learning_repository.dart';
import '../domain/course_quiz.dart';
import 'course_learning_strings.dart';
import 'course_quiz_controller.dart';
import 'course_quiz_result_screen.dart';
import 'widgets/course_learning_back_button.dart';
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
/// Runs against §2.7 through [CourseQuizController]: opening the screen
/// starts (or resumes) an attempt at [quiz], each pick is sent as that
/// attempt's answer and its feedback is the server's reply, and the last
/// "Үргэлжлүүлэх" finishes the attempt. Nothing is graded on the device.
///
/// Closing with the header's "X" pops back to Exercise Detail, leaving the
/// attempt unfinished on the server — starting again resumes it. Finishing
/// replaces this screen with `CourseQuizResultScreen` through
/// [Navigator.pushReplacement], whose `result` — the server's
/// [QuizAttemptResult] — completes *this* route's own popped future the
/// moment the attempt is graded, not whenever the Result screen later pops
/// itself. That is invisible to the student either way, since Exercise
/// Detail sits hidden beneath both screens the entire time.
///
/// The Figma Quiz pack draws no loading or error state, and none for an
/// answer in flight. Loading and a failed start reuse the feature's own
/// pattern — the shared back button over a centred spinner, or over the
/// failure's copy and an outlined retry (`CourseExerciseDetailScreen`'s
/// `_ErrorView`). An answer in flight leaves the options inert until the
/// server replies; a failed answer or finish shows its copy in
/// [AppTypography.fieldError], as the Note and Assignment tabs do.
/// Sampled off the Quiz frames at 1:1. The page is a shade lighter than the
/// app-wide [AppColors.background], and the CTA runs the full content column
/// rather than the 329 the Exercise frames inset it to.
const Color _page = Color(0xFFF9FAFB);
const Color _titleInk = Color(0xFF191919);
const double _titleSize = 18;
const double _titleToOptions = 15;

/// 12 of layout between the boxes; the 4 of band under each one overlaps it,
/// leaving the 8 of white the frames draw.
const double _optionGap = 12;
const double _optionsToFeedback = 22;
const double _ctaWidth = 361;
const double _toError = 12;

class CourseQuizScreen extends StatefulWidget {
  const CourseQuizScreen({required this.quiz, super.key, this.repository});

  /// The lesson's quiz summary — its `id` is what the attempt is started
  /// with, its `resultTitle` what the Result screen is headed with.
  final CourseQuiz quiz;

  /// Defaults to `HttpCourseLearningRepository`. Exercise Detail passes its
  /// own; tests inject one.
  final CourseLearningRepository? repository;

  @override
  State<CourseQuizScreen> createState() => _CourseQuizScreenState();
}

class _CourseQuizScreenState extends State<CourseQuizScreen> {
  late final CourseQuizController _controller;
  bool _showingResult = false;

  @override
  void initState() {
    super.initState();
    _controller = CourseQuizController(
      repository: widget.repository ?? HttpCourseLearningRepository(),
      quizId: widget.quiz.id,
    )..addListener(_onChanged);
    _controller.start();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  /// Hands over to the Result screen once the server has graded the attempt.
  void _onChanged() {
    final result = _controller.result;
    if (result == null || _showingResult || !mounted) return;
    _showingResult = true;
    Navigator.of(context).pushReplacement<void, QuizAttemptResult>(
      MaterialPageRoute(
        builder: (_) => CourseQuizResultScreen(
          title: widget.quiz.resultTitle,
          result: result,
        ),
      ),
      result: result,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.errorMessage case final message?) {
      return _StartFailedView(message: message, onRetry: _controller.start);
    }
    final attempt = _controller.attempt;
    final question = _controller.question;
    if (attempt == null || question == null) return const _StartingView();

    final answer = _controller.answerFor(question.id);
    final answerError = _controller.answerErrorMessage;
    final finishError = _controller.finishErrorMessage;
    final canAnswer = !_controller.questionAnswered && !_controller.answering;

    return Column(
      children: [
        QuizProgressHeader(
          current: _controller.index + 1,
          total: attempt.questions.length,
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
                  question.prompt,
                  style: AppTypography.heading.copyWith(
                    fontSize: _titleSize,
                    color: _titleInk,
                  ),
                ),
                const SizedBox(height: _titleToOptions),
                for (final (i, option) in question.options.indexed) ...[
                  if (i != 0) const SizedBox(height: _optionGap),
                  QuizAnswerCard(
                    letter: _letter(i),
                    label: option.text,
                    state: switch (answer) {
                      null => QuizAnswerState.normal,
                      _ when answer.optionId != option.id =>
                        QuizAnswerState.normal,
                      _ when answer.correct => QuizAnswerState.selectedCorrect,
                      _ => QuizAnswerState.selectedWrong,
                    },
                    onTap: canAnswer
                        ? () => _controller.answer(option.id)
                        : null,
                  ),
                ],
                if (answerError != null) ...[
                  const SizedBox(height: _toError),
                  Text(answerError, style: AppTypography.fieldError),
                ],
                if (answer != null) ...[
                  const SizedBox(height: _optionsToFeedback),
                  QuizFeedbackCard(
                    correct: answer.correct,
                    correctLetter: _correctLetter(question, answer),
                    explanation: answer.explanation,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (finishError != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.screenPadding,
            ),
            child: Text(
              finishError,
              style: AppTypography.fieldError,
              textAlign: TextAlign.center,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Center(
            child: ExerciseSubmitButton(
              label: CourseLearningStrings.quizContinue,
              onPressed: _controller.questionAnswered && !_controller.finishing
                  ? _controller.next
                  : null,
              width: _ctaWidth,
            ),
          ),
        ),
      ],
    );
  }

  /// A, B, C, D — derived from the option's position, as §2.7 says.
  static String _letter(int index) => String.fromCharCode(65 + index);

  /// The letter of the option the server named correct. Empty if the server
  /// named an option this question does not list — the feedback card then
  /// still shows the server's verdict and explanation.
  static String _correctLetter(QuizQuestion question, QuizAnswerResult answer) {
    final index = question.options.indexWhere(
      (option) => option.id == answer.correctOptionId,
    );
    return index < 0 ? '' : _letter(index);
  }
}

class _StartingView extends StatelessWidget {
  const _StartingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CourseLearningBackButton(),
        Expanded(
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.blue,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StartFailedView extends StatelessWidget {
  const _StartFailedView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CourseLearningBackButton(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.screenPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: AppTypography.cardSupporting,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: CourseLearningStrings.retry,
                    variant: AppButtonVariant.outlined,
                    onPressed: onRetry,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
