import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_system_ui.dart';
import '../domain/contract_failure.dart';
import 'contract_signing_controller.dart';
import 'contract_strings.dart';
import 'widgets/contract_page_parts.dart';
import 'widgets/contract_pdf_renderer.dart';
import 'widgets/contract_pdf_view.dart';

/// The E-Contract preview step (Issue #316): the contract PDF filled with
/// the student's form, unsigned, from `POST …/preview` — after the form's
/// Continue, before signing.
///
/// **The controller is the form's.** [controller] is the
/// [ContractSigningController] the form screen owns (or was given), shared
/// so the preview shows exactly the form the student filled in; this screen
/// never disposes it. The form screen stays under this one, so the
/// controller outlives it.
///
/// **Fresh, not stale.** Opening asks [ContractSigningController.loadPreview],
/// which fetches for the current, normalized form — or reuses the bytes
/// when the form has not changed since they were fetched. Going back and
/// editing outdates them, so the next Continue fetches again.
///
/// **Design.** `e-contract2.png`'s header and document box: [ContractPdfView]
/// 16 in from either side, 22 under the back button, on the export's
/// `surfaceSubtle` page. The export's box is 293
/// tall because the signature section sits under it; that section, the
/// agreement line and the Sign button are the signing step's, so here the
/// box takes the rest of the screen.
///
/// **States.** A spinner while the preview is fetched; a failure's own line
/// with a retry; the PDF (whose own opening and page states are
/// [ContractPdfView]'s). Reached any other way — a contract that cannot be
/// signed, a form that fails the client check — the generic line, and
/// nothing is requested.
class ContractPreviewScreen extends StatefulWidget {
  const ContractPreviewScreen({
    super.key,
    required this.controller,
    this.renderer,
  });

  final ContractSigningController controller;

  /// Draws the PDF. Defaults to `pdfx`; injected in tests.
  final ContractPdfRenderer? renderer;

  /// Pushes the preview for [controller]'s contract over [context]'s
  /// navigator — the form's Continue.
  static Future<void> open(
    BuildContext context, {
    required ContractSigningController controller,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ContractPreviewScreen(controller: controller),
    ),
  );

  @override
  State<ContractPreviewScreen> createState() => _ContractPreviewScreenState();
}

class _ContractPreviewScreenState extends State<ContractPreviewScreen> {
  /// What the last [ContractSigningController.loadPreview] from here said;
  /// null until it answers.
  ContractPreviewResult? _result;

  @override
  void initState() {
    super.initState();
    // After the first frame: the request notifies the shared controller's
    // listeners at once — the form screen under this one among them — and
    // nothing may be marked dirty while this route is still being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _request();
    });
  }

  Future<void> _request() async {
    final result = await widget.controller.loadPreview();
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    // The export's page is `#F9FAFB` around a white document box — not the
    // list's white page — so the box reads as a sheet.
    final background = context.palette.surfaceSubtle;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.page(context, navigationBar: background),
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimens.maxContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ContractHeader(),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: widget.controller,
                      builder: (context, _) => _body(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final controller = widget.controller;
    final bytes = controller.preview;
    if (bytes != null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          _headerToDocument,
          AppDimens.screenPadding,
          AppDimens.screenPadding + MediaQuery.paddingOf(context).bottom,
        ),
        child: ContractPdfView(bytes: bytes, renderer: widget.renderer),
      );
    }
    if (controller.previewLoading || _result == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final failure = controller.previewFailure;
    return switch (_result) {
      ContractPreviewResult.notSignable ||
      ContractPreviewResult.invalidForm => ContractMessage(
        message: ContractStrings.messageFor(ContractFailureKind.unexpected),
      ),
      _ => ContractMessage(
        message: ContractStrings.messageFor(
          failure?.kind ?? ContractFailureKind.unexpected,
        ),
        action: TextButton(
          onPressed: () {
            setState(() => _result = null);
            _request();
          },
          child: const Text(ContractStrings.retry),
        ),
      ),
    };
  }
}

/// The back button's bottom to the document box — measured off
/// `e-contract2.png` (box top at y≈117, back button bottom at y≈95, at 1×).
const double _headerToDocument = 22;
