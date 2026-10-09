import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/domain/course_exercise.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/assignment_attachment_card.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/assignment_upload_dropzone.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_material_card.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_materials_tab.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/exercise_submit_button.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/exercise_tabs.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/exercise_text_field.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/exercise_video_header.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/mentor_feedback_card.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/note_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_course_learning_repository.dart';

/// Dark Mode Phase 6b (Issue #268): Exercise Detail draws its colours from
/// the active theme's `AppPalette`, each by its meaning.
///
/// Pumped under a palette whose roles are unmistakable sentinels — not a
/// dark palette, which is not approved. The pairs that share a light value
/// but not a meaning get distinct sentinels, so each must be read where it
/// belongs: the video's media roles against `surface`, `outline`,
/// `textPrimary` and `onPrimary`; the tab's `accentText` label against its `accent`
/// underline; the transfer's `progressTrack` against `border` and
/// `outline`. Light mode itself is held pixel-identical by the goldens.
void main() {
  // Real font metrics, as the other Exercise Detail tests use.
  setUpAll(loadAppFonts);

  const surface = Color(0xFF010101);
  const surfaceSubtle = Color(0xFF020202);
  const surfaceTile = Color(0xFF030303);
  const videoSurface = Color(0xFF040404);
  const mediaControl = Color(0xFF050505);
  const onMediaControl = Color(0xFF060606);
  const onMedia = Color(0xFF070707);
  const textPrimary = Color(0xFF080808);
  const textSecondary = Color(0xFF090909);
  const onPrimary = Color(0xFF0A0A0A);
  const accent = Color(0xFF0B0B0B);
  const accentText = Color(0xFF0C0C0C);
  const primary = Color(0xFF0D0D0D);
  const primaryDepth = Color(0xFF0E0E0E);
  const border = Color(0xFF0F0F0F);
  const outline = Color(0xFF101010);
  const outlineSubtle = Color(0xFF111111);
  const outlineFaint = Color(0xFF121212);
  const divider = Color(0xFF131313);
  const progressTrack = Color(0xFF141414);
  const disabledInk = Color(0xFF151515);
  const neutralDepth = Color(0xFF161616);
  const success = Color(0xFF171717);
  const error = Color(0xFF181818);
  const borderFocused = Color(0xFF191919);
  const mediaControlOutline = Color(0xFF1A1A1A);

  final sentinel = AppPalette.light.copyWith(
    surface: surface,
    surfaceSubtle: surfaceSubtle,
    surfaceTile: surfaceTile,
    videoSurface: videoSurface,
    mediaControl: mediaControl,
    onMediaControl: onMediaControl,
    onMedia: onMedia,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    onPrimary: onPrimary,
    accent: accent,
    accentText: accentText,
    primary: primary,
    primaryDepth: primaryDepth,
    border: border,
    outline: outline,
    outlineSubtle: outlineSubtle,
    outlineFaint: outlineFaint,
    divider: divider,
    progressTrack: progressTrack,
    disabledInk: disabledInk,
    neutralDepth: neutralDepth,
    success: success,
    error: error,
    borderFocused: borderFocused,
    mediaControlOutline: mediaControlOutline,
  );

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light.copyWith(extensions: [sentinel]),
        home: home,
      ),
    );
    await tester.pump();
  }

  Widget body(Widget child) => Scaffold(
    body: Center(child: SingleChildScrollView(child: child)),
  );

  Color? textColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  Iterable<T> under<T extends Widget>(WidgetTester tester, Finder of) =>
      tester.widgetList<T>(find.descendant(of: of, matching: find.byType(T)));

  /// Every distinct [BoxDecoration] under [of] — a `Container` builds a
  /// `DecoratedBox` with its own decoration, so each is counted once.
  Iterable<BoxDecoration> decorations(WidgetTester tester, Finder of) => {
    for (final b in under<DecoratedBox>(tester, of))
      if (b.decoration case final BoxDecoration d) d,
  };

  Color? edge(BoxDecoration d) => (d.border as Border?)?.top.color;

  Color? circleEdge(Material m) => (m.shape as CircleBorder?)?.side.color;

  group('ExerciseVideoHeader: media roles, not page roles', () {
    testWidgets('videoSurface ground, onMedia text and pill, mediaControl '
        'discs, mediaControlOutline ring, onMediaControl glyph', (
      tester,
    ) async {
      await pump(
        tester,
        const Scaffold(
          body: ExerciseVideoHeader(
            durationLabel: '12:00',
            recordingBadgeLabel: 'Live Classroom Recording',
          ),
        ),
      );
      final header = find.byType(ExerciseVideoHeader);

      expect(under<ColoredBox>(tester, header).first.color, videoSurface);
      expect(textColor(tester, '12:00'), onMedia);
      expect(textColor(tester, 'Live Classroom Recording'), onMedia);
      expect(
        decorations(tester, header).map((d) => d.color),
        contains(onMedia.withValues(alpha: 0.16)),
      );

      final discs = under<Material>(
        tester,
        header,
      ).where((m) => m.shape is CircleBorder).toList();
      expect(discs, hasLength(2));
      expect(discs.map((m) => m.color), everyElement(mediaControl));

      // Only the back disc is ringed, and its ring is the media control's
      // own, not the page's `outline`.
      final rings = [
        for (final disc in discs)
          if ((disc.shape! as CircleBorder).side case final side
              when side.style != BorderStyle.none)
            side.color,
      ];
      expect(rings, [mediaControlOutline]);
      expect(rings, isNot(contains(outline)));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.arrow_back)).color,
        onMediaControl,
      );
    });

    testWidgets('no recording: the centred pill is onMedia too', (
      tester,
    ) async {
      await pump(
        tester,
        const Scaffold(
          body: ExerciseVideoHeader(
            durationLabel: '',
            recordingBadgeLabel: '',
            hasVideo: false,
          ),
        ),
      );
      expect(
        textColor(tester, CourseLearningStrings.videoUnavailable),
        onMedia,
      );
    });
  });

  testWidgets('ExerciseTabs: accentText label, accent underline, textPrimary '
      'otherwise, divider rule', (tester) async {
    await pump(
      tester,
      body(ExerciseTabs(selected: ExerciseTab.note, onSelected: (_) {})),
    );
    expect(textColor(tester, CourseLearningStrings.noteTab), accentText);
    expect(textColor(tester, CourseLearningStrings.assignmentTab), textPrimary);

    final underlines = under<Container>(
      tester,
      find.byType(ExerciseTabs),
    ).map((c) => (c.decoration as BoxDecoration?)?.color ?? c.color);
    expect(underlines.where((c) => c == accent), hasLength(1));
    expect(underlines.where((c) => c == accentText), isEmpty);
    expect(tester.widget<Divider>(find.byType(Divider)).color, divider);
  });

  group('ExerciseSubmitButton', () {
    // The pill's own decoration: the one carrying the depth band.
    BoxDecoration pill(WidgetTester tester) => decorations(
      tester,
      find.byType(ExerciseSubmitButton),
    ).singleWhere((d) => d.boxShadow != null);

    testWidgets('enabled: accent on primaryDepth, onPrimary label', (
      tester,
    ) async {
      await pump(tester, body(ExerciseSubmitButton(onPressed: () {})));
      expect(pill(tester).color, accent);
      expect(pill(tester).border, isNull);
      expect(pill(tester).boxShadow!.single.color, primaryDepth);
      expect(textColor(tester, CourseLearningStrings.submit), onPrimary);
    });

    testWidgets('disabled: the Phase 5 muted set', (tester) async {
      await pump(tester, body(const ExerciseSubmitButton()));
      expect(pill(tester).color, surfaceSubtle);
      expect(edge(pill(tester)), divider);
      expect(pill(tester).boxShadow!.single.color, neutralDepth);
      expect(textColor(tester, CourseLearningStrings.submit), disabledInk);
    });
  });

  testWidgets('ExerciseTextField: surface fill, outline edge, borderFocused '
      'focus, palette text', (tester) async {
    final controller = TextEditingController(text: 'typed');
    addTearDown(controller.dispose);
    await pump(
      tester,
      body(
        ExerciseTextField(
          controller: controller,
          placeholder: 'Placeholder',
          floatingLabel: 'Label',
          height: 104,
          multiline: true,
        ),
      ),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    final decoration = field.decoration!;
    expect(decoration.fillColor, surface);
    expect(
      (decoration.enabledBorder! as OutlineInputBorder).borderSide.color,
      outline,
    );
    expect(
      (decoration.focusedBorder! as OutlineInputBorder).borderSide.color,
      borderFocused,
    );
    expect(field.style!.color, textPrimary);
    expect(decoration.hintStyle!.color, textSecondary);
    expect(decoration.floatingLabelStyle!.color, textSecondary);
    expect(field.cursorColor, borderFocused);
  });

  group('transfers', () {
    testWidgets('uploading: primary ring and bar on progressTrack — not '
        'border, not outline', (tester) async {
      await pump(
        tester,
        body(
          const AssignmentFileUploadCard(
            uploadSizeLabel: '1 MB',
            uploadedFileLabel: null,
            onPick: null,
            onCancel: null,
            onRemove: null,
          ),
        ),
      );
      final ring = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(ring.color, primary);
      expect(ring.backgroundColor, progressTrack);
      expect(bar.color, primary);
      expect(bar.backgroundColor, progressTrack);
      final card = decorations(
        tester,
        find.byType(AssignmentFileUploadCard),
      ).first;
      expect(card.color, surface);
      expect(edge(card), outline);
      expect(
        textColor(tester, CourseLearningStrings.uploadStarted),
        textPrimary,
      );
    });

    testWidgets('drop area: outline dashes, palette text', (tester) async {
      await pump(tester, body(const AssignmentUploadDropzone()));
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(AssignmentUploadDropzone),
          matching: find.byType(CustomPaint),
        ),
      );
      expect((paint.painter! as dynamic).color, outline);
      expect(textColor(tester, CourseLearningStrings.uploadFile), textPrimary);
      expect(
        textColor(tester, CourseLearningStrings.uploadFileTypes),
        textSecondary,
      );
    });

    testWidgets('material downloaded: success ring, wash and tick; surfaceTile '
        'glyph tile; outline card', (tester) async {
      await pump(
        tester,
        body(
          CourseMaterialCard(
            material: const CourseExerciseMaterial(
              id: 1,
              name: 'Slides.pdf',
              sizeLabel: '1 MB',
            ),
            onDownload: () {},
            downloaded: true,
          ),
        ),
      );
      final card = find.byType(CourseMaterialCard);
      final decorationsOfCard = decorations(tester, card).toList();
      expect(decorationsOfCard.first.color, surface);
      expect(edge(decorationsOfCard.first), outline);
      expect(decorationsOfCard.map((d) => d.color), contains(surfaceTile));

      final button = under<Material>(
        tester,
        card,
      ).singleWhere((m) => m.shape is CircleBorder);
      expect(button.color, success.withValues(alpha: 0.12));
      expect(circleEdge(button), success);
      expect(textColor(tester, 'Slides.pdf'), textPrimary);
      expect(textColor(tester, '1 MB'), textSecondary);
    });
  });

  group('messages', () {
    const note = CourseExerciseNote(
      authorInitials: 'AB',
      authorName: 'Author',
      authorLabel: 'Student',
      message: 'A note',
      timestampLabel: 'Today',
    );

    testWidgets('Note card: outlineSubtle edge, primary avatar, palette '
        'text; Edit is the muted pill', (tester) async {
      await pump(tester, body(const NoteTab(note: note)));
      final card = decorations(
        tester,
        find.byType(NoteTab),
      ).firstWhere((d) => d.color == surface);
      expect(edge(card), outlineSubtle);
      expect(
        tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundColor,
        primary,
      );
      expect(textColor(tester, 'AB'), onPrimary);
      expect(textColor(tester, 'Author'), textPrimary);
      expect(textColor(tester, 'Student'), textSecondary);
      expect(textColor(tester, 'A note'), textPrimary);
      expect(textColor(tester, 'Today'), textSecondary);
      expect(textColor(tester, CourseLearningStrings.editNote), disabledInk);
    });

    testWidgets('Mentor Feedback: textPrimary heading, outlineSubtle card', (
      tester,
    ) async {
      await pump(
        tester,
        body(
          const MentorFeedbackCard(
            feedback: AssignmentMentorFeedback(
              mentorInitials: 'MN',
              mentorName: 'Mentor',
              mentorRole: 'Mentor role',
              message: 'Well done',
              timestampLabel: 'Yesterday',
            ),
          ),
        ),
      );
      expect(
        textColor(tester, CourseLearningStrings.mentorFeedbackTitle),
        textPrimary,
      );
      final card = decorations(
        tester,
        find.byType(MentorFeedbackCard),
      ).singleWhere((d) => d.border != null);
      expect(edge(card), outlineSubtle);
      expect(textColor(tester, 'Mentor role'), textSecondary);
    });
  });

  testWidgets('screen: surfaceSubtle page, outlineFaint tab card — an edge, '
      'not the divider rule under the tabs', (tester) async {
    await pump(
      tester,
      CourseExerciseDetailScreen(
        lessonId: 1,
        repository: FakeCourseLearningRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      surfaceSubtle,
    );
    final tabCard = find.ancestor(
      of: find.byType(ExerciseTabs),
      matching: find.byType(Container),
    );
    final edges = [
      for (final c in tester.widgetList<Container>(tabCard))
        if (c.decoration case final BoxDecoration d) edge(d),
    ];
    expect(edges, contains(outlineFaint));
    expect(edges, isNot(contains(divider)));
  });

  testWidgets('screen loading: primary spinner', (tester) async {
    final repository = FakeCourseLearningRepository(holdExercise: true);
    await pump(
      tester,
      CourseExerciseDetailScreen(lessonId: 1, repository: repository),
    );
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .color,
      primary,
    );
    repository.releaseExercise();
    await tester.pumpAndSettle();
  });

  testWidgets('material error: fieldError in error', (tester) async {
    await pump(
      tester,
      body(
        CourseMaterialsTab(
          materials: const [
            CourseExerciseMaterial(
              id: 1,
              name: 'Slides.pdf',
              sizeLabel: '1 MB',
            ),
          ],
          onDownload: (_) {},
          errorMessageFor: (_) => 'Could not open',
        ),
      ),
    );
    expect(textColor(tester, 'Could not open'), error);
  });
}
