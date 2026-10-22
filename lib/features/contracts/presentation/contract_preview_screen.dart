import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../course_learning/presentation/widgets/exercise_submit_button.dart';
import '../domain/contract_failure.dart';
import 'contract_signing_controller.dart';
import 'contract_strings.dart';
import '../../../shared/widgets/back_title_header.dart';
import 'widgets/contract_page_parts.dart';
import 'widgets/contract_pdf_renderer.dart';
import 'widgets/contract_pdf_view.dart';
import 'widgets/contract_signature_pad.dart';

/// The E-Contract preview and signing step (Issues #316, #320): the contract
/// PDF filled with the student's form, unsigned, from `POST …/preview`; then
/// the signature, the agreement and Sign — after the form's Continue.
///
/// **The controller is the form's.** [controller] is the
/// [ContractSigningController] the form screen owns (or was given), shared
/// so the preview shows — and Sign sends — exactly the form the student
/// filled in; this screen never disposes it. It owns only the signature
/// pad's controller, and disposes that.
///
/// **Fresh, not stale.** Opening asks [ContractSigningController.loadPreview],
/// which fetches for the current, normalized form — or reuses the bytes
/// when the form has not changed since they were fetched. Going back and
/// editing outdates them, so the next Continue fetches again.
///
/// **Design.** `e-contract2.png`: [ContractPdfView] in the 293-tall
/// document box, 16 in from either side and 22 under the back button, on
/// the export's `surfaceSubtle` page; [ContractSignaturePad] under it; the
/// agreement; and "Гарын үсэг зурах / Sign" — the export's accent pill on
/// its depth band ([ExerciseSubmitButton], full width). The export draws
/// the agreement as a plain line; it is a checkbox here by product decision
/// (Issue #320), drawn as the app's checkbox. One scrolling page; the pad
/// keeps its strokes from the scroll.
///
/// **Sign** is offered only with a preview of the current form shown, a
/// signature drawn, the agreement ticked, a signable contract and nothing
/// in flight — and sends through [ContractSigningController.sign], which
/// checks the same again. While it is in flight nothing can be changed or
/// sent again, and back is blocked: a sign cannot be taken back by the
/// student, so it is never left half-watched.
///
/// **Outcomes.**
///  * signed — the success state, with the signed PDF's download
///    ([ContractSigningController.download]: a fresh link, opened outside
///    the app) and a way back;
///  * `invalid_fields` — back to the form, whose fields show the reasons;
///  * `already_signed` — said in a SnackBar, and the signing step is left
///    (the form, now signed, closes behind it);
///  * `contract_cancelled`, a missing or broken template, `forbidden`,
///    `contract_not_found` — their line, and Sign stays off: retrying
///    cannot change the answer;
///  * anything else (network, server, storage, session, a refused
///    signature) — its line; the signature and the agreement are kept, so
///    Sign can be pressed again.
///
/// **States before signing.** A spinner while the preview is fetched; a
/// failure's own line with a retry. Reached any other way — a contract that
/// cannot be signed, a form that fails the client check — the generic line,
/// and nothing is requested.
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
  /// navigator — the form's Continue. Completes when it is closed.
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

  /// The signature — this screen's, disposed with it.
  final ContractSignatureController _signature = ContractSignatureController();

  bool _agreed = false;

  /// From Sign's press until [ContractSigningController.sign] answers —
  /// including the PNG export before it, which the controller does not see.
  bool _submitting = false;

  /// Signed from here: the success state replaces the form.
  bool _signed = false;

  /// A refusal retrying cannot change: Sign stays off.
  bool _blocked = false;

  /// The last sign failure's line; null when there is none to show.
  String? _signMessage;

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

  @override
  void dispose() {
    _signature.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    final result = await widget.controller.loadPreview();
    if (mounted) setState(() => _result = result);
  }

  bool get _canSign {
    final controller = widget.controller;
    return controller.preview != null &&
        !controller.previewLoading &&
        controller.canSign &&
        !controller.signing &&
        !_signature.isEmpty &&
        _agreed &&
        !_submitting &&
        !_blocked;
  }

  Future<void> _sign() async {
    if (!_canSign) return;
    setState(() {
      _submitting = true;
      _signMessage = null;
    });
    final png = await _signature.toPng();
    final result = await widget.controller.sign(png, agreed: _agreed);
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case ContractSignResult.signed:
        setState(() => _signed = true);
      case ContractSignResult.failed:
        final kind =
            widget.controller.signFailure?.kind ??
            ContractFailureKind.unexpected;
        _onFailure(kind);
      case ContractSignResult.invalidForm:
        // The client check failed after all (the form is the controller's,
        // and the preview was of it): the form says what.
        _leave(ContractStrings.signFixForm);
      case ContractSignResult.notSignable ||
          ContractSignResult.inProgress ||
          ContractSignResult.emptySignature ||
          ContractSignResult.notAgreed:
        // Nothing was sent; Sign was not offered for any of these.
        break;
    }
  }

  void _onFailure(ContractFailureKind kind) {
    switch (kind) {
      case ContractFailureKind.invalidFields:
        _leave(ContractStrings.signFixForm);
      case ContractFailureKind.alreadySigned:
        _leave(ContractStrings.signAlreadySigned);
      case ContractFailureKind.contractCancelled ||
          ContractFailureKind.templateMissing ||
          ContractFailureKind.templateInvalid ||
          ContractFailureKind.forbidden ||
          ContractFailureKind.contractNotFound:
        setState(() {
          _blocked = true;
          _signMessage = ContractStrings.messageFor(kind);
        });
      default:
        setState(() => _signMessage = ContractStrings.messageFor(kind));
    }
  }

  /// Says [message] where the student lands, and leaves this step.
  void _leave(String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pop();
  }

  Future<void> _download() async {
    await widget.controller.download();
  }

  @override
  Widget build(BuildContext context) {
    // The export's page is `#F9FAFB` around a white document box — not the
    // list's white page — so the box reads as a sheet.
    final background = context.palette.surfaceSubtle;
    return PopScope(
      canPop: !_submitting,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                    const BackTitleHeader(title: ContractStrings.title),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: Listenable.merge([
                          widget.controller,
                          _signature,
                        ]),
                        builder: (context, _) => _body(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_signed) return _scrolled(_success());
    final controller = widget.controller;
    final bytes = controller.preview;
    if (bytes != null) return _scrolled(_signing(bytes));
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
          child: Text(ContractStrings.retry),
        ),
      ),
    };
  }

  Widget _scrolled(Widget child) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      AppDimens.screenPadding,
      _headerToDocument,
      AppDimens.screenPadding,
      _bottomGap + MediaQuery.paddingOf(context).bottom,
    ),
    child: child,
  );

  Widget _signing(Uint8List bytes) {
    final editable = !_submitting && !_blocked;
    final message = _signMessage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _documentHeight,
          child: ContractPdfView(bytes: bytes, renderer: widget.renderer),
        ),
        const SizedBox(height: _documentToSignature),
        IgnorePointer(
          ignoring: !editable,
          child: ContractSignaturePad(controller: _signature),
        ),
        const SizedBox(height: _signatureToAgreement),
        _AgreementCheckbox(
          value: _agreed,
          onChanged: editable ? (v) => setState(() => _agreed = v) : null,
        ),
        if (message != null) ...[
          const SizedBox(height: AppDimens.fieldGap),
          Text(
            message,
            style: AppTypography.fieldError.copyWith(
              color: context.palette.error,
            ),
          ),
        ],
        // No gap to Sign: the row's own 44 (a tap target) puts Sign at the
        // export's y≈734.
        if (_submitting)
          const SizedBox(
            height: _signHeight,
            child: Center(child: CircularProgressIndicator()),
          )
        else
          ExerciseSubmitButton(
            label: ContractStrings.signSubmit,
            width: double.infinity,
            onPressed: _canSign ? _sign : null,
          ),
      ],
    );
  }

  Widget _success() {
    final controller = widget.controller;
    final palette = context.palette;
    final failure = controller.downloadFailure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: _successTop),
        Icon(
          AppIcons.checkCircle,
          size: _successIconSize,
          color: palette.success,
        ),
        const SizedBox(height: AppDimens.fieldGap),
        Semantics(
          header: true,
          child: Text(
            ContractStrings.signedTitle,
            style: AppTypography.cardHeading.copyWith(color: palette.textTitle),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppDimens.formToButtons),
        AppButton(
          label: ContractStrings.download,
          loading: controller.downloading,
          onPressed: _download,
        ),
        if (failure != null) ...[
          const SizedBox(height: AppDimens.fieldGap),
          Text(
            ContractStrings.messageFor(failure.kind),
            style: AppTypography.fieldError.copyWith(color: palette.error),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppDimens.buttonGap),
        AppButton(
          label: ContractStrings.signedDone,
          variant: AppButtonVariant.outlined,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// The agreement: the app's checkbox — the box Login's "remember me" draws —
/// beside the export's sentence.
///
/// Not `RememberMeCheckbox`: that is a fixed 20-tall row for a short label,
/// and this sentence has to wrap on a narrow phone or at a large text size
/// (Issue #318's widths and scales) instead of overflowing. The whole row is
/// the tap target, at least 44 tall.
class _AgreementCheckbox extends StatelessWidget {
  const _AgreementCheckbox({required this.value, required this.onChanged});

  final bool value;

  /// Null while signing, or once Sign is off for good.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onChanged != null;
    return Semantics(
      checked: value,
      enabled: enabled,
      label: ContractStrings.signAgreement,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: enabled ? () => onChanged!(!value) : null,
          borderRadius: BorderRadius.circular(AppDimens.checkboxRadius),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _agreementMinHeight),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: AppDimens.checkboxSize,
                  height: AppDimens.checkboxSize,
                  decoration: BoxDecoration(
                    color: value ? palette.primary : palette.surface,
                    borderRadius: BorderRadius.circular(
                      AppDimens.checkboxRadius,
                    ),
                    border: Border.all(
                      color: value
                          ? palette.primary
                          : (enabled ? palette.border : palette.disabled),
                      width: 1.5,
                    ),
                  ),
                  child: value
                      ? Center(
                          child: Icon(
                            AppIcons.check,
                            size: 12,
                            color: palette.onPrimary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ContractStrings.signAgreement,
                    style: AppTypography.checkboxLabel.copyWith(
                      color: enabled
                          ? palette.textPrimary
                          : palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Measured off `e-contract2.png` at 1× (the export is 1179 × 2532 at 3×).

/// The back button's bottom to the document box (box top y≈117, back button
/// bottom y≈95).
const double _headerToDocument = 22;

/// The document box (y≈117–410).
const double _documentHeight = 293;

/// The box to "Гарын үсэг зурна уу · Sign here" — puts the pad at
/// y≈466–626, the export's.
const double _documentToSignature = 19;

/// The pad section's end (under "Цэвэрлэх / Clear") to the agreement row —
/// centres the sentence on the export's y≈713.
const double _signatureToAgreement = 16;

/// Sign's pill — its depth band is a shadow painted under it, outside the
/// box, so the spinner that stands in for it while signing is this tall.
const double _signHeight = AppDimens.buttonHeight;

/// Sign's box (y≈734–778, its band painted to 782) to the home indicator's
/// inset: the export's page ends there, so it fits 844 without scrolling.
const double _bottomGap = 32;

/// The agreement row's least height — a comfortable tap target.
const double _agreementMinHeight = 44;

/// The success state: no frame draws it; the app's own spacing.
const double _successTop = 64;
const double _successIconSize = 56;
