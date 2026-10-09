import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_teacher_gradebook_repository.dart';
import 'fake_teacher_schedule_repository.dart';
import 'teacher_home_screen_test.dart' show sampleClass;

/// Teacher states no reference-frame golden draws, captured ahead of the
/// Dark Mode Phase 8 colour migration (Issue #274) so it can be proved
/// pixel-identical there too. Each was captured from the code *before* the
/// migration, then held unchanged through it:
///
///  * Teacher Schedule loading — the blue band over the spinner;
///  * Teacher Schedule failure — the message and retry under the band;
///  * Gradebook loading and failure.
///
/// Requests are held with the fakes' own gates; no sleeps or real timers.
const Duration _spinnerFrame = Duration(milliseconds: 300);

void main() {
  setUpAll(loadAppFonts);

  Future<void> shot(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../goldens/teacher_state_$name.png'),
  );

  Widget app(Widget home) => MaterialApp(
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    home: home,
  );

  DateTime clock() => DateTime(2026, 10, 7, 13, 30);

  group('Teacher Schedule', () {
    testWidgets('loading', (tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      final repository = FakeTeacherScheduleRepository(
        classes: [sampleClass()],
        hold: true,
      );
      await tester.pumpWidget(
        app(TeacherScheduleScreen(repository: repository, clock: clock)),
      );
      await tester.pump(_spinnerFrame);
      await shot(tester, 'schedule_loading');
      repository.release();
      await tester.pumpAndSettle();
    });

    testWidgets('failure', (tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      await tester.pumpWidget(
        app(
          TeacherScheduleScreen(
            repository: FakeTeacherScheduleRepository(
              classes: [sampleClass()],
              failure: const TeacherFailure(TeacherFailureKind.network),
            ),
            clock: clock,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await shot(tester, 'schedule_failure');
    });
  });

  group('Gradebook', () {
    testWidgets('loading', (tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      final repository = FakeTeacherGradebookRepository(
        classes: [sampleClass()],
        hold: true,
      );
      await tester.pumpWidget(
        app(TeacherGradebookScreen(repository: repository)),
      );
      await tester.pump(_spinnerFrame);
      await shot(tester, 'gradebook_loading');
      repository.release();
      await tester.pumpAndSettle();
    });

    testWidgets('failure', (tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      await tester.pumpWidget(
        app(
          TeacherGradebookScreen(
            repository: FakeTeacherGradebookRepository(
              classes: [sampleClass()],
              failure: const TeacherFailure(TeacherFailureKind.network),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await shot(tester, 'gradebook_failure');
    });
  });
}
