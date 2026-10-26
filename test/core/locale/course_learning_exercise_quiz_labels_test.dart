import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/data/sample_course_learning_repository.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/domain/course_quiz.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_quiz_result_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/course_learning/fake_course_learning_repository.dart';
import '../../support/screenshot.dart';

/// Issue #539 (L16): Course Learning's Exercise Detail and Quiz in the
/// selected language. Mongolian reads exactly as before — "Хариул зөв
/// байна." keeps its existing spelling (D2) — and the reference's own
/// English ("Submit", "Start quiz", …) is untouched.
void main() {
  setUpAll(loadAppFonts);
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  /// Every plain key: the Mongolian exactly as the screens showed it before,
  /// and the approved English (D1).
  const copy = <String, ({String mongolian, String english})>{
    'learningLinkPlaceholder': (
      mongolian: 'Link оруулна уу',
      english: 'Enter a link',
    ),
    'learningDescriptionLabel': (mongolian: 'Тайлбар', english: 'Description'),
    'learningDescriptionPlaceholder': (
      mongolian: 'Энд бичнэ үү...',
      english: 'Write here...',
    ),
    'learningEditNote': (mongolian: 'Засах', english: 'Edit'),
    'learningVideoUnavailable': (
      mongolian: 'Бичлэг хараахан оруугүй байна',
      english: "The recording isn't available yet",
    ),
    'learningMaterialNotFound': (
      mongolian: 'Файл олдсонгүй',
      english: 'File not found',
    ),
    'learningAssignmentNotFound': (
      mongolian: 'Даалгавар олдсонгүй',
      english: 'Assignment not found',
    ),
    'learningNoteRequired': (
      mongolian: 'Тэмдэглэлээ оруулна уу',
      english: 'Enter your note',
    ),
    'learningNoteTooLong': (
      mongolian: 'Тэмдэглэл 5000 тэмдэгтээс ихгүй байх ёстой',
      english: 'Your note must be 5,000 characters or fewer',
    ),
    'learningInvalidLink': (
      mongolian: 'Зөв link оруулна уу',
      english: 'Enter a valid link',
    ),
    'learningDescriptionTooLong': (
      mongolian: 'Тайлбар 5000 тэмдэгтээс ихгүй байх ёстой',
      english: 'Your description must be 5,000 characters or fewer',
    ),
    'learningPastDue': (
      mongolian: 'Даалгавар илгээх хугацаа дууссан',
      english: 'The submission deadline has passed',
    ),
    'learningUnsupportedFileType': (
      mongolian: 'Энэ төрлийн файл оруулах боломжгүй',
      english: "This file type can't be uploaded",
    ),
    'learningFileTooLarge': (
      mongolian: 'Файлын хэмжээ 20 MB-аас ихгүй байх ёстой',
      english: 'The file must be 20 MB or smaller',
    ),
    'quizRetake': (mongolian: 'Дахин quiz өгөх', english: 'Retake quiz'),
    'quizYourScore': (mongolian: 'Таны оноо', english: 'Your score'),
    'quizContinue': (mongolian: 'Үргэлжлүүлэх', english: 'Continue'),
    'quizCorrectTitle': (
      mongolian: 'Хариул зөв байна.',
      english: 'Correct answer.',
    ),
    'quizWrongTitle': (
      mongolian: 'Хариулт буруу байна.',
      english: 'Wrong answer.',
    ),
    'quizResultQuestion': (mongolian: 'Асуулт', english: 'Question'),
    'quizFinish': (mongolian: 'Дуусгах', english: 'Finish'),
    'quizNotFound': (mongolian: 'Quiz олдсонгүй', english: 'Quiz not found'),
    'quizNoAttemptsLeft': (
      mongolian: 'Quiz өгөх оролдлого дууссан',
      english: 'No quiz attempts left',
    ),
  };

  String text(String key, LocalePreference language) =>
      language == LocalePreference.mongolian
      ? copy[key]!.mongolian
      : copy[key]!.english;
  String en(String key) => text(key, LocalePreference.english);
  String mn(String key) => text(key, LocalePreference.mongolian);

  String correctAnswerIs(String letter, LocalePreference language) =>
      language == LocalePreference.mongolian
      ? "Зөв хариулт нь '$letter'."
      : "The correct answer is '$letter'.";

  /// `quizResultSummary`, exactly (D3): an English plural on the total.
  String summary(int total, int correct, LocalePreference language) =>
      language == LocalePreference.mongolian
      ? 'Та $total асуултаас $correct-д зөв хариуллаа'
      : total == 1
      ? 'You answered $correct of 1 question correctly'
      : 'You answered $correct of $total questions correctly';

  group('the keys', () {
    for (final language in LocalePreference.values) {
      test(language.name, () {
        final s = L10n.of(language);
        expect(
          {
            'learningLinkPlaceholder': s.learningLinkPlaceholder,
            'learningDescriptionLabel': s.learningDescriptionLabel,
            'learningDescriptionPlaceholder': s.learningDescriptionPlaceholder,
            'learningEditNote': s.learningEditNote,
            'learningVideoUnavailable': s.learningVideoUnavailable,
            'learningMaterialNotFound': s.learningMaterialNotFound,
            'learningAssignmentNotFound': s.learningAssignmentNotFound,
            'learningNoteRequired': s.learningNoteRequired,
            'learningNoteTooLong': s.learningNoteTooLong,
            'learningInvalidLink': s.learningInvalidLink,
            'learningDescriptionTooLong': s.learningDescriptionTooLong,
            'learningPastDue': s.learningPastDue,
            'learningUnsupportedFileType': s.learningUnsupportedFileType,
            'learningFileTooLarge': s.learningFileTooLarge,
            'quizRetake': s.quizRetake,
            'quizYourScore': s.quizYourScore,
            'quizContinue': s.quizContinue,
            'quizCorrectTitle': s.quizCorrectTitle,
            'quizWrongTitle': s.quizWrongTitle,
            'quizResultQuestion': s.quizResultQuestion,
            'quizFinish': s.quizFinish,
            'quizNotFound': s.quizNotFound,
            'quizNoAttemptsLeft': s.quizNoAttemptsLeft,
          },
          {for (final key in copy.keys) key: text(key, language)},
        );
        for (final letter in ['A', 'C']) {
          expect(
            s.quizCorrectAnswerIs(letter),
            correctAnswerIs(letter, language),
          );
        }
      });

      test('the result summary in ${language.name}: total 1 and more (D3)', () {
        final s = L10n.of(language);
        for (final (total, correct) in [(1, 0), (1, 1), (2, 1), (4, 2)]) {
          expect(
            s.quizResultSummary(total, correct),
            summary(total, correct, language),
            reason: '$total/$correct',
          );
        }
        if (language == LocalePreference.english) {
          expect(
            s.quizResultSummary(1, 1),
            'You answered 1 of 1 question correctly',
          );
          expect(
            s.quizResultSummary(4, 2),
            'You answered 2 of 4 questions correctly',
          );
        }
      });

      test('CourseLearningStrings in ${language.name}', () async {
        await locale.setPreference(language);
        final members = <String, String>{
          'learningLinkPlaceholder': CourseLearningStrings.linkPlaceholder,
          'learningDescriptionLabel':
              CourseLearningStrings.descriptionFloatingLabel,
          'learningDescriptionPlaceholder':
              CourseLearningStrings.descriptionPlaceholder,
          'learningEditNote': CourseLearningStrings.editNote,
          'learningVideoUnavailable': CourseLearningStrings.videoUnavailable,
          'learningMaterialNotFound': CourseLearningStrings.materialNotFound,
          'learningAssignmentNotFound':
              CourseLearningStrings.assignmentNotFound,
          'learningNoteRequired': CourseLearningStrings.noteContentRequired,
          'learningNoteTooLong': CourseLearningStrings.noteContentTooLong,
          'learningInvalidLink': CourseLearningStrings.invalidLink,
          'learningDescriptionTooLong':
              CourseLearningStrings.descriptionTooLong,
          'learningPastDue': CourseLearningStrings.pastDue,
          'learningUnsupportedFileType':
              CourseLearningStrings.unsupportedFileType,
          'learningFileTooLarge': CourseLearningStrings.fileTooLarge,
          'quizRetake': CourseLearningStrings.retakeQuiz,
          'quizYourScore': CourseLearningStrings.yourScoreLabel,
          'quizContinue': CourseLearningStrings.quizContinue,
          'quizCorrectTitle': CourseLearningStrings.quizCorrectTitle,
          'quizWrongTitle': CourseLearningStrings.quizWrongTitle,
          'quizResultQuestion': CourseLearningStrings.quizResultQuestionLabel,
          'quizFinish': CourseLearningStrings.quizFinish,
          'quizNotFound': CourseLearningStrings.quizNotFound,
          'quizNoAttemptsLeft': CourseLearningStrings.quizNoAttemptsLeft,
        };
        for (final MapEntry(:key, :value) in members.entries) {
          expect(value, text(key, language), reason: key);
        }
        // The alias reads its target.
        expect(
          CourseLearningStrings.submissionEmpty,
          text('learningLinkPlaceholder', language),
        );
        expect(
          CourseLearningStrings.quizCorrectAnswerIs('B'),
          correctAnswerIs('B', language),
        );
        expect(
          CourseLearningStrings.quizResultSummary(1, 1),
          summary(1, 1, language),
        );
        // The failure kinds that read these lines, through messageFor.
        for (final (kind, key) in [
          (CourseLearningFailureKind.contentRequired, 'learningNoteRequired'),
          (CourseLearningFailureKind.contentTooLong, 'learningNoteTooLong'),
          (
            CourseLearningFailureKind.submissionEmpty,
            'learningLinkPlaceholder',
          ),
          (CourseLearningFailureKind.invalidLink, 'learningInvalidLink'),
          (
            CourseLearningFailureKind.descriptionTooLong,
            'learningDescriptionTooLong',
          ),
          (CourseLearningFailureKind.pastDue, 'learningPastDue'),
          (CourseLearningFailureKind.noAttemptsLeft, 'quizNoAttemptsLeft'),
          (
            CourseLearningFailureKind.unsupportedFileType,
            'learningUnsupportedFileType',
          ),
          (CourseLearningFailureKind.fileTooLarge, 'learningFileTooLarge'),
        ]) {
          expect(
            CourseLearningStrings.messageFor(kind),
            text(key, language),
            reason: kind.name,
          );
        }
        // The reference's own English is untouched.
        expect(CourseLearningStrings.startQuiz, 'Start quiz');
        expect(CourseLearningStrings.submit, 'Submit');
      });
    }
  });

  // --- Exercise Detail ------------------------------------------------------

  Future<void> pumpExercise(
    WidgetTester tester,
    FakeCourseLearningRepository repository, {
    Size size = const Size(393, 852),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: CourseExerciseDetailScreen(
            lessonId: 204,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A lesson as the backend answers it: real content, no simulated writes.
  FakeCourseLearningRepository lesson({
    Object? note,
    bool hasVideo = true,
    CourseQuiz? quiz,
  }) => FakeCourseLearningRepository(
    exercise: sampleExercise(
      lessonId: 204,
      title: 'Давталт',
      note: note,
      hasVideo: hasVideo,
      quiz: quiz,
      assignmentFeedback: const [],
      simulatesWrites: false,
    ),
  );

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('Exercise Detail in English', () {
    setUp(() => locale.setEnglish(true));

    testWidgets('a saved note offers Edit', (tester) async {
      await pumpExercise(tester, lesson(note: sampleNote()));
      await openTab(tester, CourseLearningStrings.noteTab);

      expect(find.text(en('learningEditNote')), findsOneWidget);
      expect(find.text(mn('learningEditNote')), findsNothing);
    });

    testWidgets('an empty note: Description and Write here...', (tester) async {
      await pumpExercise(tester, lesson(note: null));
      await openTab(tester, CourseLearningStrings.noteTab);

      expect(find.text(en('learningDescriptionLabel')), findsOneWidget);
      expect(find.text(en('learningDescriptionPlaceholder')), findsOneWidget);
      expect(find.text(mn('learningDescriptionLabel')), findsNothing);
    });

    testWidgets('the assignment: Enter a link, Description, Write here...', (
      tester,
    ) async {
      await pumpExercise(tester, lesson(note: null));
      await openTab(tester, CourseLearningStrings.assignmentTab);

      for (final key in [
        'learningLinkPlaceholder',
        'learningDescriptionLabel',
        'learningDescriptionPlaceholder',
      ]) {
        expect(find.text(en(key)), findsOneWidget, reason: key);
        expect(find.text(mn(key)), findsNothing, reason: key);
      }
    });

    testWidgets('no recording yet: "The recording isn\'t available yet"', (
      tester,
    ) async {
      await pumpExercise(tester, lesson(hasVideo: false));

      expect(find.text(en('learningVideoUnavailable')), findsOneWidget);
      expect(find.text(mn('learningVideoUnavailable')), findsNothing);
    });

    testWidgets('a note the server refuses as too long says why, in English', (
      tester,
    ) async {
      final repository = lesson(note: null)
        ..saveFailure = const CourseLearningFailure(
          CourseLearningFailureKind.contentTooLong,
        );
      await pumpExercise(tester, repository);
      await openTab(tester, CourseLearningStrings.noteTab);

      await tester.enterText(
        find.byType(TextField),
        'Too long, says the server.',
      );
      await tester.pump();
      await tester.tap(find.text(CourseLearningStrings.submit));
      await tester.pumpAndSettle();

      expect(find.text(en('learningNoteTooLong')), findsOneWidget);
      expect(find.text(mn('learningNoteTooLong')), findsNothing);
      expect(repository.saveCalls, hasLength(1));
    });

    testWidgets('a taken quiz: Your score and Retake quiz', (tester) async {
      await pumpExercise(
        tester,
        lesson(
          quiz: sampleQuiz(
            attemptsLeft: 2,
            lastResult: const QuizLastResult(
              attemptId: 1,
              correct: 1,
              total: 2,
              percent: 50,
              passed: false,
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text(en('quizRetake')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text(en('quizYourScore')), findsOneWidget);
      expect(find.text(en('quizRetake')), findsOneWidget);
      expect(find.text(mn('quizRetake')), findsNothing);
    });
  });

  testWidgets('switching language on Exercise Detail: the labels change at '
      'once; a stored save error keeps its language until the next save (D4)', (
    tester,
  ) async {
    final repository = lesson(note: null)
      ..saveFailure = const CourseLearningFailure(
        CourseLearningFailureKind.contentTooLong,
      );
    await pumpExercise(tester, repository);
    await openTab(tester, CourseLearningStrings.noteTab);
    await tester.enterText(find.byType(TextField), 'Too long.');
    await tester.pump();
    await tester.tap(find.text(CourseLearningStrings.submit));
    await tester.pumpAndSettle();
    expect(find.text(mn('learningNoteTooLong')), findsOneWidget);
    final state = tester.state(find.byType(CourseExerciseDetailScreen));
    final loads = repository.exerciseCalls.length;

    await locale.setEnglish(true);
    await tester.pump();

    // Drawn now: switched.
    expect(find.text(en('learningDescriptionLabel')), findsOneWidget);
    expect(find.text(mn('learningDescriptionLabel')), findsNothing);
    // Stored when the save failed: unchanged until the next save.
    expect(find.text(mn('learningNoteTooLong')), findsOneWidget);
    expect(tester.state(find.byType(CourseExerciseDetailScreen)), same(state));
    expect(repository.exerciseCalls.length, loads);

    await tester.tap(find.text(CourseLearningStrings.submit));
    await tester.pumpAndSettle();
    expect(find.text(en('learningNoteTooLong')), findsOneWidget);
  });

  // --- Quiz -------------------------------------------------------------------

  late CourseQuiz sampleQuizFlow;
  setUpAll(() async {
    final exercise = await SampleCourseLearningRepository().getExercise(2);
    sampleQuizFlow = exercise.quiz!;
  });

  Future<void> pumpQuiz(
    WidgetTester tester, {
    Size size = const Size(393, 852),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: CourseQuizScreen(
            quiz: sampleQuizFlow,
            repository: SampleCourseLearningRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const result = QuizAttemptResult(
    attemptId: 1,
    correct: 2,
    total: 4,
    percent: 50,
    passed: false,
    questions: [
      QuizQuestionResult(questionId: 1, order: 1, correct: true),
      QuizQuestionResult(questionId: 2, order: 2, correct: false),
      QuizQuestionResult(questionId: 3, order: 3, correct: true),
      QuizQuestionResult(questionId: 4, order: 4, correct: false),
    ],
  );

  Future<void> pumpResult(
    WidgetTester tester, {
    QuizAttemptResult attempt = result,
    Size size = const Size(393, 852),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: CourseQuizResultScreen(
            title: sampleQuizFlow.resultTitle,
            result: attempt,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Quiz in English', () {
    setUp(() => locale.setEnglish(true));

    testWidgets('a correct answer: "Correct answer." and Continue', (
      tester,
    ) async {
      await pumpQuiz(tester);
      await tester.tap(find.text('Хиймэл оюун'));
      await tester.pumpAndSettle();

      expect(find.text(en('quizCorrectTitle')), findsOneWidget);
      expect(find.text(en('quizContinue')), findsOneWidget);
      expect(find.text(mn('quizCorrectTitle')), findsNothing);
      expect(find.text(mn('quizContinue')), findsNothing);
    });

    testWidgets('a wrong answer: "Wrong answer." and the correct letter', (
      tester,
    ) async {
      await pumpQuiz(tester);
      await tester.tap(find.text('Тоглоом'));
      await tester.pumpAndSettle();

      expect(find.text(en('quizWrongTitle')), findsOneWidget);
      expect(find.textContaining("The correct answer is '"), findsOneWidget);
      expect(find.textContaining('Зөв хариулт нь'), findsNothing);
    });

    testWidgets('the result: the summary, Your score, Question and Finish', (
      tester,
    ) async {
      await pumpResult(tester);

      expect(
        find.text(summary(4, 2, LocalePreference.english)),
        findsOneWidget,
      );
      expect(find.text(en('quizYourScore')), findsOneWidget);
      expect(find.text(en('quizResultQuestion')), findsNWidgets(4));
      expect(find.text(en('quizFinish')), findsOneWidget);
      expect(find.text(mn('quizResultQuestion')), findsNothing);
    });

    testWidgets('a one-question result reads "1 question" (D3)', (
      tester,
    ) async {
      await pumpResult(
        tester,
        attempt: const QuizAttemptResult(
          attemptId: 1,
          correct: 1,
          total: 1,
          percent: 100,
          passed: true,
          questions: [
            QuizQuestionResult(questionId: 1, order: 1, correct: true),
          ],
        ),
      );

      expect(
        find.text('You answered 1 of 1 question correctly'),
        findsOneWidget,
      );
    });
  });

  testWidgets('switching language on the quiz result: every line changes, '
      'the screen stays', (tester) async {
    await pumpResult(tester);
    expect(
      find.text(summary(4, 2, LocalePreference.mongolian)),
      findsOneWidget,
    );
    final screen = find.byType(CourseQuizResultScreen);
    final element = tester.element(screen);

    await locale.setEnglish(true);
    await tester.pump();

    expect(find.text(summary(4, 2, LocalePreference.english)), findsOneWidget);
    expect(find.text(en('quizFinish')), findsOneWidget);
    expect(find.text(mn('quizFinish')), findsNothing);
    expect(tester.element(screen), same(element));
  });

  // --- Large text -------------------------------------------------------------

  const width = 320.0;
  const height = 2400.0;

  /// Each state: how to reach it, and the labels it draws by language.
  final states =
      <
        ({
          String name,
          Future<void> Function(WidgetTester) reach,
          List<String Function(LocalePreference)> labels,
        })
      >[
        (
          name: 'Exercise Detail, a saved note',
          reach: (tester) async {
            await pumpExercise(
              tester,
              lesson(note: sampleNote()),
              size: const Size(width, height),
            );
            await openTab(tester, CourseLearningStrings.noteTab);
          },
          labels: [(l) => text('learningEditNote', l)],
        ),
        (
          name: 'Exercise Detail, the assignment',
          reach: (tester) async {
            await pumpExercise(
              tester,
              lesson(note: null),
              size: const Size(width, height),
            );
            await openTab(tester, CourseLearningStrings.assignmentTab);
          },
          labels: [
            (l) => text('learningLinkPlaceholder', l),
            (l) => text('learningDescriptionLabel', l),
            (l) => text('learningDescriptionPlaceholder', l),
          ],
        ),
        (
          name: 'Exercise Detail, no recording yet',
          reach: (tester) => pumpExercise(
            tester,
            lesson(hasVideo: false),
            size: const Size(width, height),
          ),
          labels: [(l) => text('learningVideoUnavailable', l)],
        ),
        (
          name: 'Exercise Detail, a taken quiz',
          reach: (tester) => pumpExercise(
            tester,
            lesson(
              quiz: sampleQuiz(
                attemptsLeft: 2,
                lastResult: const QuizLastResult(
                  attemptId: 1,
                  correct: 1,
                  total: 2,
                  percent: 50,
                  passed: false,
                ),
              ),
            ),
            size: const Size(width, height),
          ),
          labels: [
            (l) => text('quizYourScore', l),
            (l) => text('quizRetake', l),
          ],
        ),
        (
          name: 'Quiz, a correct answer',
          reach: (tester) async {
            await pumpQuiz(tester, size: const Size(width, height));
            await tester.tap(find.text('Хиймэл оюун'));
            await tester.pumpAndSettle();
          },
          labels: [
            (l) => text('quizCorrectTitle', l),
            (l) => text('quizContinue', l),
          ],
        ),
        (
          name: 'Quiz, a wrong answer',
          reach: (tester) async {
            await pumpQuiz(tester, size: const Size(width, height));
            await tester.tap(find.text('Тоглоом'));
            await tester.pumpAndSettle();
          },
          labels: [(l) => text('quizWrongTitle', l)],
        ),
        (
          name: 'Quiz result',
          reach: (tester) =>
              pumpResult(tester, size: const Size(width, height)),
          labels: [
            (l) => summary(4, 2, l),
            (l) => text('quizYourScore', l),
            (l) => text('quizFinish', l),
          ],
        ),
      ];

  for (final state in states) {
    for (final language in LocalePreference.values) {
      testWidgets('${state.name}, ${language.name}, 2.0× text on a 320 pt '
          'phone: no overflow, every line whole and inside the screen, '
          'nothing cut short', (tester) async {
        await locale.setPreference(language);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await state.reach(tester);
        expect(tester.takeException(), isNull);

        for (final labelOf in state.labels) {
          final value = labelOf(language);
          final label = find.text(value);
          expect(label, findsOneWidget, reason: value);
          await tester.ensureVisible(label);
          await tester.pumpAndSettle();
          final rect = tester.getRect(label);
          expect(rect.left, greaterThanOrEqualTo(0), reason: value);
          expect(rect.right, lessThanOrEqualTo(width), reason: value);
          expect(rect.top, greaterThanOrEqualTo(0), reason: value);
          expect(rect.bottom, lessThanOrEqualTo(height), reason: value);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: label, matching: find.byType(RichText)).first,
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: value);
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(
              paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
            ),
            reason: value,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
