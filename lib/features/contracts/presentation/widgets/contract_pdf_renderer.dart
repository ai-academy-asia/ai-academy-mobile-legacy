import 'dart:async';
import 'dart:typed_data';

import 'package:pdfx/pdfx.dart';

/// Opens PDF bytes for [ContractPdfView](contract_pdf_view.dart) (Issue
/// #310) — the seam that keeps the widget, and its tests, off native
/// rendering. [PdfxContractPdfRenderer] is the real one.
abstract interface class ContractPdfRenderer {
  /// The document in [bytes]. Throws when they cannot be opened.
  Future<ContractPdfDocument> open(Uint8List bytes);
}

/// An open PDF. Close it when done: it holds native resources.
abstract interface class ContractPdfDocument {
  /// How many pages it has; the first is 1.
  int get pageCount;

  /// Page [pageNumber] (1-based) drawn [width] pixels wide, its height in
  /// the page's own proportion. Throws when it cannot be drawn.
  Future<ContractPdfPageImage> renderPage(int pageNumber, {required int width});

  /// Releases the document. Safe to call more than once.
  Future<void> close();
}

/// One drawn page: encoded image bytes and their pixel size.
class ContractPdfPageImage {
  const ContractPdfPageImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

/// The renderer on `pdfx`: `PdfDocument.openData` straight from memory — no
/// file, no URL — and each page rendered to a PNG on white, the PDF's own
/// paper, whatever the app theme.
///
/// **One page at a time.** Each render opens its page, draws it and closes
/// it before the next starts: Android's native `PdfRenderer` allows a single
/// open page, so renders are queued rather than run side by side.
class PdfxContractPdfRenderer implements ContractPdfRenderer {
  PdfxContractPdfRenderer({
    Future<PdfDocument> Function(Uint8List bytes)? openData,
  }) : _openData = openData ?? PdfDocument.openData;

  final Future<PdfDocument> Function(Uint8List bytes) _openData;

  @override
  Future<ContractPdfDocument> open(Uint8List bytes) async =>
      _PdfxDocument(await _openData(bytes));
}

class _PdfxDocument implements ContractPdfDocument {
  _PdfxDocument(this._document);

  final PdfDocument _document;

  /// The tail of the render queue — see [PdfxContractPdfRenderer].
  Future<void> _queue = Future.value();

  @override
  int get pageCount => _document.pagesCount;

  @override
  Future<ContractPdfPageImage> renderPage(
    int pageNumber, {
    required int width,
  }) {
    final result = _queue.then((_) => _render(pageNumber, width));
    // The next render waits for this one to finish, success or not.
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<ContractPdfPageImage> _render(int pageNumber, int width) async {
    if (_document.isClosed) {
      throw StateError('the document is closed');
    }
    final page = await _document.getPage(pageNumber);
    try {
      final height = (width * page.height / page.width).round();
      final image = await page.render(
        width: width.toDouble(),
        height: height.toDouble(),
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      if (image == null) {
        throw StateError('page $pageNumber rendered no image');
      }
      return ContractPdfPageImage(
        bytes: image.bytes,
        width: image.width ?? width,
        height: image.height ?? height,
      );
    } finally {
      if (!page.isClosed) await page.close();
    }
  }

  @override
  Future<void> close() async {
    if (_document.isClosed) return;
    // Let a render in flight finish with its page before the document goes.
    await _queue;
    if (!_document.isClosed) await _document.close();
  }
}
