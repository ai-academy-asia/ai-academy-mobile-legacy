import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/quiz_result_question_row.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/presentation/widgets/program_card.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_profile_screen.dart';
import 'package:aia_mobile/features/profile/presentation/profile_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_profile_screen.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/profile/fake_current_user_repository.dart';
import '../support/screenshot.dart';

/// Text inside a box that grows with the system text size is drawn whole
/// (DESIGN_SYSTEM §3: "fixed heights around text are minimums"; Issue #406).
/// Clipping raises no error, so every line is measured: a paragraph given
/// less height than its own text needs has been cut.
void main() {
  setUpAll(loadAppFonts);

  Future<List<String>> pump(
    WidgetTester tester,
    Widget home, {
    required double width,
    required double scale,
  }) async {
    useLogicalViewport(tester, Size(width, 2400), padding: iPhonePadding);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.toString());
    try {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: home));
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previous;
    }
    return errors;
  }

  /// Every line of text under [of] gets the height its text needs.
  List<String> clipped(WidgetTester tester, Finder of) => [
    for (final element
        in find.descendant(of: of, matching: find.byType(RichText)).evaluate())
      if (element.renderObject case final RenderParagraph p
          when p.size.height < p.getMaxIntrinsicHeight(p.size.width) - 0.01)
        '"${p.text.toPlainText()}": ${p.size.height.toStringAsFixed(1)} of '
            '${p.getMaxIntrinsicHeight(p.size.width).toStringAsFixed(1)}',
  ];

  Widget card(Widget child) => Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  );

  final lesson = DateTime(2026, 10, 15, 18, 30);
  final cases = <String, Widget Function()>{
    'Adult Home — the next-lesson heading': () => card(
      ProgramCard(
        program: EnrolledProgram(
          cohortId: 1,
          cohortName: 'Cohort 01',
          courseTitle: 'AI Engineer',
          courseSlug: 'ai-engineer',
          status: 'active',
          uiMode: 'adult',
          nextLesson: NextLesson(
            startsAt: lesson,
            endsAt: lesson.add(const Duration(hours: 3)),
          ),
        ),
      ),
    ),
    'Adult Home — the heading beside "Live"': () => card(
      ProgramCard(
        live: true,
        program: EnrolledProgram(
          cohortId: 1,
          cohortName: 'Cohort 01',
          courseTitle: 'AI Engineer',
          courseSlug: 'ai-engineer',
          status: 'active',
          uiMode: 'adult',
          nextLesson: NextLesson(
            startsAt: lesson,
            endsAt: lesson.add(const Duration(hours: 3)),
          ),
        ),
      ),
    ),
    'Teacher Profile': () =>
        TeacherProfileScreen(repository: FakeCurrentUserRepository()),
    'Adult Profile': () => ProfileScreen(
      repository: FakeCurrentUserRepository(),
      showBottomNav: false,
    ),
    'Junior Profile': () => JuniorProfileScreen(
      repository: FakeCurrentUserRepository(),
      showBottomNav: false,
    ),
    'AppButton — filled, outlined, loading': () => card(
      const Column(
        children: [
          AppButton(label: 'Нэвтрэх', onPressed: null),
          SizedBox(height: 12),
          AppButton(
            label: 'Дахин оролдох',
            onPressed: null,
            variant: AppButtonVariant.outlined,
          ),
        ],
      ),
    ),
    'Quiz result rows — questions 9, 10 and 12': () => card(
      const Column(
        children: [
          QuizResultQuestionRow(number: 9, correct: true),
          QuizResultQuestionRow(number: 10, correct: false),
          QuizResultQuestionRow(number: 12, correct: true),
        ],
      ),
    ),
  };

  testWidgets('quiz result numbers 10 and up stay on one line at 2.0×, '
      '320 wide', (tester) async {
    await pump(
      tester,
      cases['Quiz result rows — questions 9, 10 and 12']!(),
      width: 320,
      scale: 2,
    );
    for (final number in ['9', '10', '12']) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text(number), matching: find.byType(RichText)),
      );
      // One line: the paragraph is as wide as its text unwrapped.
      expect(
        paragraph.size.width,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicWidth(double.infinity) - 0.01,
        ),
        reason: '"$number" broke across lines',
      );
    }
  });

  for (final MapEntry(key: name, value: build) in cases.entries) {
    group(name, () {
      for (final (width, scale) in const [
        (393.0, 1.0),
        (393.0, 2.0),
        (320.0, 2.0),
      ]) {
        testWidgets('${width.toInt()} wide, text ×$scale: every line whole, '
            'no overflow', (tester) async {
          final errors = await pump(
            tester,
            build(),
            width: width,
            scale: scale,
          );
          expect(errors, isEmpty);
          expect(clipped(tester, find.byType(MaterialApp)), isEmpty);
        });
      }
    });
  }
}
