import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_strings.dart';
import 'package:aia_mobile/features/contracts/presentation/widgets/contract_pdf_renderer.dart';
import 'package:aia_mobile/features/contracts/presentation/widgets/contract_pdf_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The in-app contract PDF viewer (Issue #310), through a hand-driven
/// renderer — no native PDF rendering, no API. Test values only.
void main() {
  /// A real 1×1 PNG, so `Image.memory` gets decodable bytes.
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );
  final pdf = Uint8List.fromList(utf8.encode('%PDF-1.7 test'));

  late _FakeRenderer renderer;
  late List<Object> errors;

  setUp(() {
    renderer = _FakeRenderer(png);
    errors = [];
  });

  /// The viewer in a 300×600 box at [pixelRatio].
  Future<void> pump(
    WidgetTester tester, {
    Uint8List? bytes,
    double pixelRatio = 3,
  }) async {
    tester.view.devicePixelRatio = pixelRatio;
    tester.view.physicalSize = const Size(400, 800) * pixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 600,
              child: ContractPdfView(
                bytes: bytes ?? pdf,
                renderer: renderer,
                onError: errors.add,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows a spinner while the document opens', (tester) async {
    renderer.openGate = Completer<void>();
    await pump(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(renderer.opened.single, same(pdf));

    renderer.openGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('draws every page at the box width in device pixels', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpAndSettle();

    final document = renderer.documents.single;
    expect(document.renders, [(page: 1, width: 900), (page: 2, width: 900)]);
    expect(find.bySemanticsLabel('1 / 2'), findsOneWidget);
    expect(find.bySemanticsLabel('2 / 2'), findsOneWidget);
    expect(errors, isEmpty);
  });

  testWidgets('a very dense screen draws pages at most 2048 pixels wide', (
    tester,
  ) async {
    await pump(tester, pixelRatio: 10);
    await tester.pumpAndSettle();

    expect(renderer.documents.single.renders.first.width, 2048);
  });

  testWidgets('a drawn page is not drawn again on rebuild', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await pump(tester);
    await tester.pumpAndSettle();

    expect(renderer.documents, hasLength(1));
    expect(renderer.documents.single.renders, hasLength(2));
  });

  group('failures', () {
    testWidgets('an open that fails says so, reports it, and retry opens '
        'again', (tester) async {
      final failure = StateError('not a PDF');
      renderer.openError = failure;
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.text(ContractStrings.previewFailed), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(errors, [same(failure)]);

      renderer.openError = null;
      await tester.tap(find.text(ContractStrings.retry));
      await tester.pumpAndSettle();

      expect(renderer.opened, hasLength(2));
      expect(find.text(ContractStrings.previewFailed), findsNothing);
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('a page that fails shows its own retry; the others stay', (
      tester,
    ) async {
      final failure = StateError('page 2');
      renderer.pageErrors[2] = failure;
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('1 / 2'), findsOneWidget);
      expect(find.text(ContractStrings.previewFailed), findsOneWidget);
      expect(errors, [same(failure)]);

      renderer.pageErrors.clear();
      // Page 2 starts low in the box: scroll its retry in, as a student would.
      await tester.ensureVisible(find.text(ContractStrings.retry));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ContractStrings.retry));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('2 / 2'), findsOneWidget);
      // Only page 2 is drawn again.
      expect(renderer.documents.single.renders.map((r) => r.page), [1, 2, 2]);
    });
  });

  group('resources', () {
    testWidgets('the document is closed when the viewer goes', (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(renderer.documents.single.closeCalls, 1);
    });

    testWidgets('new bytes close the old document and open the new one', (
      tester,
    ) async {
      await pump(tester);
      await tester.pumpAndSettle();

      final newer = Uint8List.fromList(utf8.encode('%PDF-1.7 newer'));
      await pump(tester, bytes: newer);
      await tester.pumpAndSettle();

      expect(renderer.opened, [same(pdf), same(newer)]);
      expect(renderer.documents.first.closeCalls, 1);
      expect(renderer.documents.last.closeCalls, 0);
    });

    testWidgets('an open that finishes after the viewer is gone is closed at '
        'once, and reports nothing', (tester) async {
      renderer.openGate = Completer<void>();
      await pump(tester);

      await tester.pumpWidget(const SizedBox());
      renderer.openGate!.complete();
      await tester.pumpAndSettle();

      expect(renderer.documents.single.closeCalls, 1);
      expect(renderer.documents.single.renders, isEmpty);
      expect(errors, isEmpty);
    });

    testWidgets('an open overtaken by newer bytes is closed, never shown', (
      tester,
    ) async {
      renderer.openGate = Completer<void>();
      await pump(tester);

      final newer = Uint8List.fromList(utf8.encode('%PDF-1.7 newer'));
      final firstGate = renderer.openGate!;
      renderer.openGate = null;
      await pump(tester, bytes: newer);
      await tester.pumpAndSettle();

      firstGate.complete();
      await tester.pumpAndSettle();

      final stale = renderer.documents.firstWhere((d) => d.source == pdf);
      expect(stale.closeCalls, 1);
      expect(stale.renders, isEmpty);
    });

    testWidgets('a failure to close is reported, not swallowed', (
      tester,
    ) async {
      final failure = StateError('close');
      renderer.closeError = failure;
      await pump(tester);
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(errors, [same(failure)]);
    });
  });
}

class _FakeRenderer implements ContractPdfRenderer {
  _FakeRenderer(this.png);

  final Uint8List png;
  final List<Uint8List> opened = [];
  final List<_FakeDocument> documents = [];
  final Map<int, Object> pageErrors = {};
  Completer<void>? openGate;
  Object? openError;
  Object? closeError;

  @override
  Future<ContractPdfDocument> open(Uint8List bytes) async {
    opened.add(bytes);
    final gate = openGate;
    if (gate != null) await gate.future;
    if (openError case final error?) throw error;
    final document = _FakeDocument(this, bytes);
    documents.add(document);
    return document;
  }
}

class _FakeDocument implements ContractPdfDocument {
  _FakeDocument(this._renderer, this.source);

  final _FakeRenderer _renderer;
  final Uint8List source;
  final List<({int page, int width})> renders = [];
  int closeCalls = 0;

  @override
  int get pageCount => 2;

  @override
  Future<ContractPdfPageImage> renderPage(
    int pageNumber, {
    required int width,
  }) async {
    renders.add((page: pageNumber, width: width));
    if (_renderer.pageErrors[pageNumber] case final error?) throw error;
    return ContractPdfPageImage(
      bytes: _renderer.png,
      width: width,
      height: (width * 1.414).round(),
    );
  }

  @override
  Future<void> close() async {
    closeCalls++;
    if (_renderer.closeError case final error?) throw error;
  }
}
