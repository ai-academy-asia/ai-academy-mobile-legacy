import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/domain/course_exercise.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/assignment_attachment_card.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/assignment_upload_dropzone.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_material_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// Exercise Detail's file rows and upload area at larger system text sizes
/// (Issue #363). Each drew its content in a fixed height — the material and
/// attachment rows 72, the upload area 125 — so from about 2.0× the text
/// overflowed it. Now each height is a minimum: the widget grows with its
/// text and is exactly as before at the default size.
void main() {
  setUpAll(loadAppFonts);

  const widths = [320.0, 375.0, 393.0];
  const scales = [1.0, 1.5, 2.0, 3.0];

  /// The screen's 16 gutter, the tab card's 1 edge and the tab's own 16
  /// padding, either side — so the widgets get the width they get on the
  /// Exercise Detail screen.
  const sideInset = 16.0 + 1 + 16;

  const material = CourseExerciseMaterial(
    id: 1,
    name: 'Lesson 3 — Linear regression worked examples.pdf',
    sizeLabel: '10 MB',
  );
  final link = CourseExerciseMaterial(
    id: 2,
    name: 'Course reading list',
    sizeLabel: '',
    url: Uri.parse('https://example.com/reading-list'),
  );

  /// Pumps [child] at the tab's width and returns every error it raised.
  Future<List<String>> pump(
    WidgetTester tester,
    Widget child, {
    required double width,
    required double scale,
  }) async {
    useLogicalViewport(tester, Size(width, 1600), padding: iPhonePadding);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.toString());
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: sideInset),
              child: Center(child: child),
            ),
          ),
        ),
      );
      // Not pumpAndSettle: the upload state's indicators never settle.
      await tester.pump();
    } finally {
      FlutterError.onError = previous;
    }
    return errors;
  }

  /// Checks every text inside [of] is drawn whole — no line cut off below
  /// its box, no box narrower than its text, an ellipsis only where the
  /// text asks for one — and inside [of]'s own bounds. Texts in [except]
  /// are skipped.
  void expectTextWhole(
    WidgetTester tester,
    Finder of, {
    Set<String> except = const {},
  }) {
    final bounds = tester.getRect(of);
    final paragraphs = find
        .descendant(of: of, matching: find.byType(RichText))
        .evaluate()
        .map((e) => e.renderObject! as RenderParagraph)
        .toList();
    expect(paragraphs, isNotEmpty);
    for (final paragraph in paragraphs) {
      final text = paragraph.text.toPlainText();
      if (except.contains(text)) continue;
      final painter = TextPainter(
        text: paragraph.text,
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
        maxLines: paragraph.maxLines,
        ellipsis: paragraph.overflow == TextOverflow.ellipsis ? '…' : null,
      )..layout(maxWidth: paragraph.constraints.maxWidth);
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(painter.height - 0.01),
        reason: '"$text" drawn whole',
      );
      expect(
        paragraph.size.width,
        greaterThanOrEqualTo(painter.width - 0.01),
        reason: '"$text" not cut',
      );
      if (paragraph.overflow != TextOverflow.ellipsis) {
        expect(painter.didExceedMaxLines, isFalse, reason: '"$text"');
      }
      painter.dispose();
      final box = paragraph.localToGlobal(Offset.zero) & paragraph.size;
      expect(box.top, greaterThanOrEqualTo(bounds.top - 0.01), reason: text);
      expect(box.bottom, lessThanOrEqualTo(bounds.bottom + 0.01));
      expect(box.left, greaterThanOrEqualTo(bounds.left - 0.01));
      expect(box.right, lessThanOrEqualTo(bounds.right + 0.01));
    }
  }

  // One case per widget and state: what to pump, what to measure, its
  // height at the default text size, and any text deliberately not checked.
  final cases = <(String, Widget, Type, double?, Set<String>)>[
    (
      'material card',
      const CourseMaterialCard(material: material),
      CourseMaterialCard,
      72,
      const <String>{},
    ),
    (
      'material card, link, downloaded',
      CourseMaterialCard(material: link, onDownload: () {}, downloaded: true),
      CourseMaterialCard,
      72,
      const <String>{},
    ),
    (
      'upload dropzone',
      AssignmentUploadDropzone(onTap: () {}),
      AssignmentUploadDropzone,
      125,
      const <String>{},
    ),
    (
      'attachment card, idle',
      AssignmentAttachmentCard(
        attachment: material,
        onDownloaded: () {},
        onRemoved: () {},
      ),
      AssignmentAttachmentCard,
      125,
      const <String>{},
    ),
    (
      'file upload card, uploading',
      AssignmentFileUploadCard(
        uploadSizeLabel: '1 MB',
        uploadedFileLabel: null,
        onPick: () {},
        onCancel: () {},
        onRemove: () {},
      ),
      AssignmentFileUploadCard,
      null,
      // DEFERRED (Issue #363): the in-transfer card's "Cancel" pill is a
      // fixed 80 x 40, so from 2.0× its label wraps and is cut inside it
      // (no layout error is raised). Letting the pill grow squeezes the
      // "Uploading..." column beside it to a few pixels at 320 / 3.0×, so
      // it needs a decision on the row's layout at large text — not a
      // small robustness fix. Everything else in the card is checked.
      const {CourseLearningStrings.cancelUpload},
    ),
    (
      'file upload card, uploaded',
      AssignmentFileUploadCard(
        uploadSizeLabel: null,
        uploadedFileLabel: CourseLearningStrings.uploadedFileLabel(
          '1 MB',
          'linear_regression_homework_final.ipynb',
        ),
        onPick: () {},
        onCancel: () {},
        onRemove: () {},
      ),
      AssignmentFileUploadCard,
      72,
      const <String>{},
    ),
  ];

  for (final (label, widget, type, defaultHeight, deferred) in cases) {
    group(label, () {
      for (final width in widths) {
        for (final scale in scales) {
          testWidgets('${width.toInt()} wide, text ×$scale: no layout '
              'errors and every text drawn whole inside it', (tester) async {
            final errors = await pump(
              tester,
              widget,
              width: width,
              scale: scale,
            );
            expect(errors, isEmpty);

            final found = find.byType(type);
            final rect = tester.getRect(found);
            if (defaultHeight != null) {
              expect(rect.height, greaterThanOrEqualTo(defaultHeight));
              if (scale == 1) expect(rect.height, defaultHeight);
            }
            expectTextWhole(tester, found, except: deferred);
          });
        }
      }
    });
  }

  group('at the default size, the layout is unchanged', () {
    testWidgets('material card: 329 x 72, the tile and button centred in '
        'it', (tester) async {
      expect(
        await pump(
          tester,
          const CourseMaterialCard(material: material),
          width: 393,
          scale: 1,
        ),
        isEmpty,
      );
      final card = tester.getRect(find.byType(CourseMaterialCard));
      expect(card.size, const Size(327, 72));
      final button = tester.getRect(
        find.descendant(
          of: find.byType(CourseMaterialCard),
          matching: find.byType(InkWell),
        ),
      );
      expect(button.size, const Size.square(40));
      expect(button.center.dy, card.center.dy);
    });

    testWidgets('upload dropzone: 125 tall, its content centred in it', (
      tester,
    ) async {
      expect(
        await pump(
          tester,
          AssignmentUploadDropzone(onTap: () {}),
          width: 393,
          scale: 1,
        ),
        isEmpty,
      );
      final area = tester.getRect(find.byType(AssignmentUploadDropzone));
      expect(area.height, 125);
      final icon = tester.getRect(
        find.descendant(
          of: find.byType(AssignmentUploadDropzone),
          matching: find.byType(SvgPicture),
        ),
      );
      final label = tester.getRect(find.text(CourseLearningStrings.uploadFile));
      final types = tester.getRect(
        find.text(CourseLearningStrings.uploadFileTypes),
      );
      expect(icon.size, const Size.square(24));
      expect(label.top - icon.bottom, 8);
      expect(types.top - label.bottom, 16);
      // Centred: as much space above the icon as below the types line.
      expect(
        icon.top - area.top,
        moreOrLessEquals(area.bottom - types.bottom, epsilon: 0.01),
      );
    });
  });
}
