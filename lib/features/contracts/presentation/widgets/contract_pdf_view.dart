import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../contract_strings.dart';
import 'contract_pdf_renderer.dart';

/// The widest a page is drawn, in pixels — a phone at 3× is ~1080; this
/// keeps a tablet's page sharp without an outsized bitmap per page.
const int _maxPageWidthPx = 2048;

/// Before a page has drawn, its slot takes A4's proportion (1 : √2) so the
/// list does not jump as most contract pages arrive. A placeholder guess —
/// the drawn page then takes its real proportion.
const double _placeholderAspect = 1 / 1.4142;

/// The gap between two pages. The design draws no pages (see
/// [ContractPdfView]), so this is the app's own field gap.
const double _pageGap = AppDimens.fieldGap;

/// The unsigned E-Contract PDF inside the app (Issue #310): every page of
/// the in-memory [bytes] — `getContractPreview`'s answer — drawn one under
/// the other in a scrollable, rounded box.
///
/// **Design.** The box is the signing screen export's document area
/// (`e-contract2.png`): white, the light-grey card edge, 16 radius; its size
/// is the caller's. That export draws plain text there, not PDF pages, so
/// page spacing, zoom and the loading/error presentation are not designed:
/// the pages are fitted to the box's width with the app's field gap between
/// them, and the states use the app's existing spinner and generic copy
/// until a design gives them their own.
///
/// **States.** Opening: a spinner. Failed to open: the generic error line
/// and a retry that opens the bytes again. Each page draws lazily as it
/// scrolls in, at the box's width in device pixels; a page that fails shows
/// its own retry while the others stay. Every failure is also handed to
/// [onError] — it is never only swallowed. Nothing is logged here, and no
/// PDF content leaves the widget.
///
/// **Resources.** The document is closed on dispose and whenever [bytes]
/// change; an open that finishes after either is closed at once instead of
/// shown. Pages are closed by the renderer as soon as they are drawn.
///
/// Independent of the contract form and the signing controller: it shows
/// bytes, nothing more. Pass [renderer] in tests to keep off native
/// rendering; it defaults to [PdfxContractPdfRenderer].
class ContractPdfView extends StatefulWidget {
  const ContractPdfView({
    super.key,
    required this.bytes,
    this.renderer,
    this.onError,
  });

  /// The PDF, in memory.
  final Uint8List bytes;

  final ContractPdfRenderer? renderer;

  /// Told about every open, render and close failure, for the caller to
  /// report as it sees fit. The widget already shows the open and render
  /// ones.
  final ValueChanged<Object>? onError;

  @override
  State<ContractPdfView> createState() => _ContractPdfViewState();
}

class _ContractPdfViewState extends State<ContractPdfView> {
  late ContractPdfRenderer _renderer =
      widget.renderer ?? PdfxContractPdfRenderer();

  /// Bumped by every open and by dispose; an open whose number is no longer
  /// current closes its document instead of showing it.
  int _generation = 0;

  ContractPdfDocument? _document;
  Object? _openError;
  final Map<int, _PageSlot> _pages = {};

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(ContractPdfView old) {
    super.didUpdateWidget(old);
    final rendererChanged = widget.renderer != old.renderer;
    if (rendererChanged) {
      _renderer = widget.renderer ?? PdfxContractPdfRenderer();
    }
    if (rendererChanged || !identical(widget.bytes, old.bytes)) _open();
  }

  @override
  void dispose() {
    _generation++;
    _release(_document);
    _document = null;
    super.dispose();
  }

  Future<void> _open() async {
    final generation = ++_generation;
    _release(_document);
    setState(() {
      _document = null;
      _openError = null;
      _pages.clear();
    });

    final ContractPdfDocument document;
    try {
      document = await _renderer.open(widget.bytes);
    } catch (error) {
      if (generation != _generation) return;
      setState(() => _openError = error);
      widget.onError?.call(error);
      return;
    }
    if (generation != _generation) {
      // Superseded by newer bytes or disposed while opening.
      _release(document);
      return;
    }
    setState(() => _document = document);
  }

  /// Closes [document] without waiting; a failure goes to [onError].
  void _release(ContractPdfDocument? document) {
    if (document == null) return;
    final onError = widget.onError;
    unawaited(
      document.close().catchError((Object error) => onError?.call(error)),
    );
  }

  /// Starts drawing [pageNumber] at [width] unless it is drawn, drawing, or
  /// failed at that width. Safe to call from build: the slot is marked
  /// before the render starts, and its result lands through setState.
  void _ensurePage(ContractPdfDocument document, int pageNumber, int width) {
    final existing = _pages[pageNumber];
    if (existing != null && existing.width == width) return;

    final slot = _pages[pageNumber] = _PageSlot(width);
    final generation = _generation;
    document
        .renderPage(pageNumber, width: width)
        .then(
          (image) {
            if (!_current(generation, pageNumber, slot)) return;
            setState(() => slot.image = image);
          },
          onError: (Object error) {
            if (!_current(generation, pageNumber, slot)) return;
            setState(() => slot.error = error);
            widget.onError?.call(error);
          },
        );
  }

  bool _current(int generation, int pageNumber, _PageSlot slot) =>
      mounted &&
      generation == _generation &&
      identical(_pages[pageNumber], slot);

  void _retryPage(int pageNumber) => setState(() => _pages.remove(pageNumber));

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppDimens.homeCardRadius);
    return Semantics(
      container: true,
      label: ContractStrings.title,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: radius,
          border: Border.all(
            color: palette.outline,
            width: AppDimens.borderWidth,
          ),
        ),
        child: ClipRRect(borderRadius: radius, child: _content(context)),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final error = _openError;
    if (error != null) {
      return _Failure(onRetry: _open);
    }
    final document = _document;
    if (document == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(
          1,
          math.min(
            (constraints.maxWidth * pixelRatio).round(),
            _maxPageWidthPx,
          ),
        );
        return ListView.separated(
          itemCount: document.pageCount,
          separatorBuilder: (_, _) => const SizedBox(height: _pageGap),
          itemBuilder: (context, index) {
            final pageNumber = index + 1;
            _ensurePage(document, pageNumber, width);
            final slot = _pages[pageNumber]!;
            return _Page(
              pageNumber: pageNumber,
              pageCount: document.pageCount,
              slot: slot,
              onRetry: () => _retryPage(pageNumber),
            );
          },
        );
      },
    );
  }
}

/// One page's drawing, at the width it was asked for.
class _PageSlot {
  _PageSlot(this.width);

  final int width;
  ContractPdfPageImage? image;
  Object? error;
}

class _Page extends StatelessWidget {
  const _Page({
    required this.pageNumber,
    required this.pageCount,
    required this.slot,
    required this.onRetry,
  });

  final int pageNumber;
  final int pageCount;
  final _PageSlot slot;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final image = slot.image;
    if (image != null) {
      return AspectRatio(
        aspectRatio: image.width / image.height,
        child: Image.memory(
          image.bytes,
          fit: BoxFit.fill,
          gaplessPlayback: true,
          semanticLabel: '$pageNumber / $pageCount',
        ),
      );
    }
    return AspectRatio(
      aspectRatio: _placeholderAspect,
      child: slot.error != null
          ? _Failure(onRetry: onRetry)
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

/// The generic error line and a retry — the app's existing copy, until the
/// design gives the preview its own.
class _Failure extends StatelessWidget {
  const _Failure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ContractStrings.previewFailed,
              style: AppTypography.statLabel.copyWith(
                color: context.palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.fieldGap),
            TextButton(
              onPressed: onRetry,
              child: const Text(ContractStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}
