import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:aia_mobile/features/contracts/presentation/widgets/contract_pdf_renderer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfx/pdfx.dart';

/// The `pdfx` adapter (Issue #310), against fakes of `pdfx`'s own exported
/// document, page and image types — no native renderer is reached.
void main() {
  final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]);

  late _FakeDocument document;
  late List<Uint8List> opened;
  late PdfxContractPdfRenderer renderer;

  setUp(() {
    document = _FakeDocument(pagesCount: 2);
    opened = [];
    renderer = PdfxContractPdfRenderer(
      openData: (bytes) async {
        opened.add(bytes);
        return document;
      },
    );
  });

  test('opens the bytes in memory and reports the page count', () async {
    final pdf = await renderer.open(pdfBytes);

    expect(opened.single, same(pdfBytes));
    expect(pdf.pageCount, 2);
  });

  test('draws a page as a PNG on white, at the asked width and the page\'s '
      'proportion, then closes the page', () async {
    final pdf = await renderer.open(pdfBytes);

    final image = await pdf.renderPage(2, width: 900);

    final page = document.pages.single;
    expect(page.pageNumber, 2);
    expect(page.renders.single, (
      width: 900.0,
      height: (900 * 842 / 595).roundToDouble(),
      format: PdfPageImageFormat.png,
      background: '#FFFFFF',
    ));
    expect(page.isClosed, isTrue);
    expect(image.bytes, page.output);
    expect(image.width, 900);
  });

  test('a page that fails to draw is still closed, and the failure '
      'reaches the caller', () async {
    document.renderError = StateError('native failure');
    final pdf = await renderer.open(pdfBytes);

    await expectLater(pdf.renderPage(1, width: 300), throwsStateError);
    expect(document.pages.single.isClosed, isTrue);
  });

  test('a page that renders no image is a failure, and is closed', () async {
    document.renderNothing = true;
    final pdf = await renderer.open(pdfBytes);

    await expectLater(pdf.renderPage(1, width: 300), throwsStateError);
    expect(document.pages.single.isClosed, isTrue);
  });

  test('renders one page at a time — the next page opens only after the '
      'previous one closed', () async {
    final gate = Completer<void>();
    document.renderGate = gate;
    final pdf = await renderer.open(pdfBytes);

    final first = pdf.renderPage(1, width: 300);
    final second = pdf.renderPage(2, width: 300);
    await pumpEventQueue();

    expect(document.pages, hasLength(1));

    gate.complete();
    await Future.wait([first, second]);

    expect(document.pages.map((p) => p.pageNumber), [1, 2]);
    expect(document.maxOpenPages, 1);
  });

  test('a failed render does not stall the queue', () async {
    document.renderError = StateError('once');
    final pdf = await renderer.open(pdfBytes);

    await expectLater(pdf.renderPage(1, width: 300), throwsStateError);
    document.renderError = null;

    final image = await pdf.renderPage(2, width: 300);
    expect(image.width, 300);
  });

  test('close waits for a render in flight, then closes once', () async {
    final gate = Completer<void>();
    document.renderGate = gate;
    final pdf = await renderer.open(pdfBytes);

    final rendering = pdf.renderPage(1, width: 300);
    await pumpEventQueue();
    final closing = pdf.close();
    await pumpEventQueue();
    expect(document.isClosed, isFalse);

    gate.complete();
    await rendering;
    await closing;
    await pdf.close();

    expect(document.isClosed, isTrue);
    expect(document.closeCalls, 1);
    expect(document.pages.single.isClosed, isTrue);
  });

  test('drawing after close fails', () async {
    final pdf = await renderer.open(pdfBytes);
    await pdf.close();

    await expectLater(pdf.renderPage(1, width: 300), throwsStateError);
  });

  test('an open that fails reaches the caller', () async {
    final failing = PdfxContractPdfRenderer(
      openData: (_) async => throw const FormatException('not a PDF'),
    );

    await expectLater(failing.open(pdfBytes), throwsFormatException);
  });
}

class _FakeDocument extends PdfDocument {
  _FakeDocument({required super.pagesCount})
    : super(sourceName: 'memory', id: 'doc');

  final List<_FakePage> pages = [];
  Completer<void>? renderGate;
  Object? renderError;
  bool renderNothing = false;
  int closeCalls = 0;
  int maxOpenPages = 0;

  int get _openPages => pages.where((page) => !page.isClosed).length;

  @override
  Future<PdfPage> getPage(
    int pageNumber, {
    bool autoCloseAndroid = false,
  }) async {
    final page = _FakePage(this, pageNumber);
    pages.add(page);
    if (_openPages > maxOpenPages) maxOpenPages = _openPages;
    return page;
  }

  @override
  Future<void> close() async {
    closeCalls++;
    isClosed = true;
  }

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}

class _FakePage extends PdfPage {
  _FakePage(_FakeDocument document, int pageNumber)
    : _document = document,
      super(
        document: document,
        id: 'page-$pageNumber',
        pageNumber: pageNumber,
        width: 595,
        height: 842,
        autoCloseAndroid: false,
      );

  final _FakeDocument _document;
  final Uint8List output = Uint8List.fromList([1, 2, 3]);
  final List<
    ({
      double width,
      double height,
      PdfPageImageFormat format,
      String? background,
    })
  >
  renders = [];

  @override
  Future<PdfPageImage?> render({
    required double width,
    required double height,
    PdfPageImageFormat format = PdfPageImageFormat.jpeg,
    String? backgroundColor,
    Rect? cropRect,
    int quality = 100,
    bool forPrint = false,
    bool removeTempFile = true,
  }) async {
    renders.add((
      width: width,
      height: height,
      format: format,
      background: backgroundColor,
    ));
    if (_document.renderGate case final gate?) await gate.future;
    if (_document.renderError case final error?) throw error;
    if (_document.renderNothing) return null;
    return _FakeImage(
      pageNumber: pageNumber,
      width: width.toInt(),
      height: height.toInt(),
      bytes: output,
      format: format,
    );
  }

  @override
  Future<PdfPageTexture> createTexture() => throw UnimplementedError();

  @override
  Future<void> close() async => isClosed = true;

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}

class _FakeImage extends PdfPageImage {
  const _FakeImage({
    required super.pageNumber,
    required super.width,
    required super.height,
    required super.bytes,
    required super.format,
  }) : super(id: 'image', quality: 100);

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}
