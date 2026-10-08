import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/core/utils/pick_local_file.dart';
import 'package:aia_mobile/features/course_learning/domain/course_exercise.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/domain/course_quiz.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_quiz_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/lesson_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/assignment_tab.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/assignment_upload_dropzone.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_progress_cta_row.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_course_learning_repository.dart';

/// Dark Mode Phase 6.0 (Issue #264): light-mode captures of the Learning
/// Flow states no other screenshot covers — loading, error, empty, the
/// material download cycle, assignment edge states and the quiz preview's
/// results — so the Phase 6a/6b/6c colour migrations can prove every one
/// stays pixel-identical. Coverage only: nothing here changes the app.
///
/// The Learning Flow is one implementation for Adult and Junior (no role
/// branching), so each state is captured once.
///
/// **Determinism.** Loading states hold the fake's request (its `hold*`
/// gates) and capture after a fixed `pump()` — an indeterminate spinner's
/// frame is a function of elapsed fake time, which is identical every run.
/// No sleeps, no real timers, no network: downloads open through an injected
/// `openUrl`, files come from an injected `pickFile`.
///
/// States the existing goldens already draw are not repeated: the link form
/// with a disabled Submit (`exercise_01`, `exercise_04`), the attachment's
/// complete tile and a focused, filled field (`exercise_05`), the "Start
/// quiz" preview, and materials at rest (`exercise_08`).
/// How far into its turn an indeterminate spinner is captured: past its
/// near-empty first frame, so its arc — and its colour — is drawn. Fake
/// time, so the frame is identical on every run.
const Duration _spinnerFrame = Duration(milliseconds: 300);

void main() {
  setUpAll(loadAppFonts);

  Future<void> shot(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../goldens/learning_$name.png'),
  );

  Widget app(Widget home) => MaterialApp(
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    home: home,
  );

  group('Module list', () {
    Widget screen(FakeCourseLearningRepository repository) => app(
      CourseModuleListScreen(
        courseSlug: 'how-ai-works',
        repository: repository,
      ),
    );

    testWidgets('loading', (tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      await tester.pumpWidget(screen(FakeCourseLearningRepository(hold: true)));
      await tester.pump(_spinnerFrame);
      await shot(tester, 'module_list_loading');
    });

    testWidgets('error, with retry', (tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      await tester.pumpWidget(
        screen(
          FakeCourseLearningRepository(
            failure: const CourseLearningFailure(
              CourseLearningFailureKind.network,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(CourseLearningStrings.retry), findsOneWidget);
      await shot(tester, 'module_list_error');
    });

    testWidgets('"Continue learning" held down', (tester) async {
      // The reference frame's height, as `course_module_list.png`.
      useLogicalViewport(tester, const Size(393, 1392), padding: iPhonePadding);
      // A path with somewhere to continue to — as the screen tests' — so the
      // button is live; with the default sample it is inert and draws no
      // press at all.
      await tester.pumpWidget(
        screen(
          FakeCourseLearningRepository(
            path: samplePath(continueModuleId: 2, continueLessonId: 204),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await precacheImages(tester);

      // The certification panel's own button (the second of the two rows):
      // its press draws `Colors.white24`/`white10`, which Phase 6a moves.
      final button = find.byType(ContinueLearningButton).last;
      final gesture = await tester.startGesture(tester.getCenter(button));
      // Inside a scroll view the tap-down waits out `kPressTimeout` (100 ms);
      // then a fixed slice of the highlight's fade-in. Fake time, so the
      // frame is the same every run.
      await tester.pump(kPressTimeout);
      await tester.pump(const Duration(milliseconds: 150));
      await shot(tester, 'module_list_continue_pressed');
      await gesture.cancel();
      await tester.pumpAndSettle();
    });
  });

  group('Lesson list', () {
    Widget screen(FakeCourseLearningRepository repository) => app(
      LessonListScreen(
        moduleId: 2,
        moduleOrder: 2,
        moduleTitle: 'Language Model Training',
        repository: repository,
      ),
    );

    testWidgets('loading', (tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      await tester.pumpWidget(
        screen(FakeCourseLearningRepository(holdLessons: true)),
      );
      // No `precacheImages`: its closing `pumpAndSettle` never settles while
      // the spinner turns, and the header's artwork is SVG, not raster.
      await tester.pump(_spinnerFrame);
      await shot(tester, 'lesson_list_loading');
    });

    testWidgets('error, with retry', (tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      await tester.pumpWidget(
        screen(
          FakeCourseLearningRepository(
            lessonsFailure: const CourseLearningFailure(
              CourseLearningFailureKind.server,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await precacheImages(tester);
      expect(find.text(CourseLearningStrings.retry), findsOneWidget);
      await shot(tester, 'lesson_list_error');
    });

    testWidgets('empty', (tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      await tester.pumpWidget(
        screen(FakeCourseLearningRepository(lessons: const [])),
      );
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await shot(tester, 'lesson_list_empty');
    });
  });

  group('Exercise detail', () {
    /// A lesson as the backend sends it (no simulated writes), as the
    /// screen tests' own `backendLesson()`.
    FakeCourseLearningRepository backendLesson({
      CourseAssignment? assignment,
      CourseQuiz? quiz,
    }) => FakeCourseLearningRepository(
      exercise: sampleExercise(
        lessonId: 204,
        title: 'Давталт',
        assignmentFeedback: const [],
        simulatesWrites: false,
        assignment: assignment,
        quiz: quiz,
      ),
      // 1 MB exactly, as the screen tests use.
      uploadedFile: sampleUploadedFile(id: 501, sizeBytes: 1048576),
    );

    Future<void> pump(
      WidgetTester tester,
      FakeCourseLearningRepository repository, {
      double height = 852,
      AssignmentForm? assignmentForm,
      bool settle = true,
    }) async {
      useLogicalViewport(tester, Size(393, height), padding: iPhonePadding);
      await tester.pumpWidget(
        app(
          CourseExerciseDetailScreen(
            lessonId: 204,
            repository: repository,
            // Never the platform: a download "opens" here, a file is "picked"
            // here.
            openUrl: (_) async => true,
            pickFile: () async =>
                const PickedFile(name: 'report.pdf', bytes: [1, 2, 3]),
            assignmentForm: assignmentForm,
          ),
        ),
      );
      if (settle) await tester.pumpAndSettle();
    }

    Future<void> openTab(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await precacheImages(tester);
    }

    testWidgets('loading', (tester) async {
      await pump(
        tester,
        FakeCourseLearningRepository(holdExercise: true),
        settle: false,
      );
      await tester.pump(_spinnerFrame);
      await shot(tester, 'exercise_loading');
    });

    testWidgets('error, with retry', (tester) async {
      await pump(
        tester,
        FakeCourseLearningRepository(
          exerciseFailure: const CourseLearningFailure(
            CourseLearningFailureKind.notFound,
          ),
        ),
      );
      expect(find.text(CourseLearningStrings.retry), findsOneWidget);
      await shot(tester, 'exercise_error');
    });

    group('materials', () {
      testWidgets('downloading', (tester) async {
        final repository = backendLesson()..holdDownload = true;
        await pump(tester, repository, height: 917);
        await openTab(tester, CourseLearningStrings.courseMaterialsTab);
        await tester.tap(find.bySemanticsLabel('Download').first);
        await tester.pump();
        expect(find.bySemanticsLabel('Downloading'), findsOneWidget);
        await shot(tester, 'exercise_material_downloading');
        repository.releaseDownload();
        await tester.pumpAndSettle();
      });

      testWidgets('downloaded', (tester) async {
        await pump(tester, backendLesson(), height: 917);
        await openTab(tester, CourseLearningStrings.courseMaterialsTab);
        await tester.tap(find.bySemanticsLabel('Download').first);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Downloaded'), findsOneWidget);
        await shot(tester, 'exercise_material_downloaded');
      });

      testWidgets('download failed', (tester) async {
        final repository = backendLesson()
          ..downloadFailure = const CourseLearningFailure(
            CourseLearningFailureKind.server,
          );
        await pump(tester, repository, height: 917);
        await openTab(tester, CourseLearningStrings.courseMaterialsTab);
        await tester.tap(find.bySemanticsLabel('Download').first);
        await tester.pumpAndSettle();
        expect(find.text(CourseLearningStrings.serverError), findsOneWidget);
        await shot(tester, 'exercise_material_download_error');
      });
    });

    group('assignment', () {
      const assignment = CourseAssignment(id: 17);

      testWidgets('unavailable: no assignment, fields and Submit disabled', (
        tester,
      ) async {
        await pump(tester, backendLesson(), height: 1088);
        await openTab(tester, 'Assignment');
        await shot(tester, 'exercise_assignment_unavailable');
      });

      testWidgets('submit failed: the reason under the form', (tester) async {
        final repository = backendLesson(assignment: assignment)
          ..submitFailure = const CourseLearningFailure(
            CourseLearningFailureKind.invalidLink,
          );
        await pump(tester, repository, height: 1088);
        await openTab(tester, 'Assignment');
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'not-a-link');
        await tester.enterText(fields.at(1), 'Тайлбар');
        await tester.pump();
        // Dismiss the keyboard focus, so the capture shows the error, not a
        // caret.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.tap(find.text(CourseLearningStrings.submit));
        await tester.pumpAndSettle();
        expect(find.text(CourseLearningStrings.invalidLink), findsOneWidget);
        await shot(tester, 'exercise_assignment_submit_failed');
      });

      // The file form: wired end to end, but no backend assignment selects
      // it yet (`_formFor` keeps the link form — a BACKEND GAP), so it is
      // reached the way the screen tests reach it, through `assignmentForm`.
      group('file form', () {
        Future<void> openFileForm(
          WidgetTester tester,
          FakeCourseLearningRepository repository,
        ) async {
          await pump(
            tester,
            repository,
            height: 1088,
            assignmentForm: AssignmentForm.file,
          );
          await openTab(tester, 'Assignment');
        }

        Future<void> pickAFile(WidgetTester tester) async {
          final dropzone = find.byType(AssignmentUploadDropzone);
          await tester.ensureVisible(dropzone);
          await tester.tap(dropzone);
          // Not `pumpAndSettle`: a held upload's indicators never settle.
          await tester.pump();
          await tester.pump();
        }

        testWidgets('idle', (tester) async {
          await openFileForm(tester, backendLesson(assignment: assignment));
          await shot(tester, 'exercise_file_form_idle');
        });

        testWidgets('uploading', (tester) async {
          final repository = backendLesson(assignment: assignment)
            ..holdUpload = true;
          await openFileForm(tester, repository);
          await pickAFile(tester);
          await shot(tester, 'exercise_file_form_uploading');
          repository.releaseUpload();
          await tester.pumpAndSettle();
        });

        testWidgets('uploaded', (tester) async {
          await openFileForm(tester, backendLesson(assignment: assignment));
          await pickAFile(tester);
          await tester.pumpAndSettle();
          await shot(tester, 'exercise_file_form_uploaded');
        });

        testWidgets('upload failed: the reason under the file area', (
          tester,
        ) async {
          final repository = backendLesson(assignment: assignment)
            ..uploadFailure = const CourseLearningFailure(
              CourseLearningFailureKind.fileTooLarge,
            );
          await openFileForm(tester, repository);
          await pickAFile(tester);
          await tester.pumpAndSettle();
          await shot(tester, 'exercise_file_form_upload_error');
        });
      });
    });

    group('quiz preview card', () {
      // The card sits under the tabs, at the foot of the page: a frame tall
      // enough to hold the whole scroll body, as the exercise goldens use.
      testWidgets('a finished attempt, retake available', (tester) async {
        await pump(
          tester,
          backendLesson(
            quiz: sampleQuiz(lastResult: sampleLastResult(), attemptsLeft: 2),
          ),
          height: 1224,
        );
        await precacheImages(tester);
        await shot(tester, 'exercise_quiz_preview_retake');
      });

      testWidgets('a finished attempt, no attempts left', (tester) async {
        await pump(
          tester,
          backendLesson(
            quiz: sampleQuiz(
              lastResult: sampleLastResult(percent: 40, correct: 2),
              attemptsLeft: 0,
            ),
          ),
          height: 1224,
        );
        await precacheImages(tester);
        await shot(tester, 'exercise_quiz_preview_no_retake');
      });
    });
  });

  group('Quiz', () {
    Widget screen(FakeCourseLearningRepository repository) =>
        app(CourseQuizScreen(quiz: sampleQuiz(), repository: repository));

    testWidgets('starting', (tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      await tester.pumpWidget(
        screen(FakeCourseLearningRepository(holdStartQuiz: true)),
      );
      await tester.pump(_spinnerFrame);
      await shot(tester, 'quiz_starting');
    });

    testWidgets('start failed, with retry', (tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      await tester.pumpWidget(
        screen(
          FakeCourseLearningRepository(
            startQuizFailure: const CourseLearningFailure(
              CourseLearningFailureKind.network,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(CourseLearningStrings.retry), findsOneWidget);
      await shot(tester, 'quiz_start_failed');
    });
  });
}
