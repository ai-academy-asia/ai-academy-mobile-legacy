import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../data/http_contract_repository.dart';
import '../domain/contract_detail.dart';
import '../domain/contract_failure.dart';
import '../domain/contract_repository.dart';
import 'contract_signing_controller.dart';
import 'contract_strings.dart';
import 'widgets/contract_page_parts.dart';

/// The E-Contract form step (Issue #314): one contract's details, checked
/// before the student goes on to the preview and the signature.
///
/// **No frame draws it.** `e-contract2.png` is the preview/signature step;
/// the form is laid out in the app's own form pattern instead — Login's
/// [AppTextField] and [AppButton], `fieldGap` apart, under the list's
/// [ContractHeader] — with plain section headings. A `PRODUCT DECISION` until
/// design supplies a frame.
///
/// **Everything runs through [ContractSigningController].** The form is the
/// controller's: prefilled from `detail.form` (nothing is filled in here),
/// every keystroke sent through `updateField`, and each field's error is
/// `errorFor` — the server's `invalid_fields` reason when it gave one,
/// otherwise [ContractFormValidator]'s. No rule is repeated here. Pass
/// [controller] to share it with the steps after this one (they need the
/// same form); otherwise the screen makes and disposes its own.
///
/// **Which fields.** The six student fields always; the four guardian
/// fields only when `rules.guardian_required` — `guardian_relation` among
/// them, since the backend requires it with the other three; the final
/// payment date only when `rules.final_payment_date_required`, picked from a
/// calendar bounded by `final_payment_date_min` / `_max`, never typed.
///
/// **States.** A loader until the detail answers (and during a reload); a
/// failure's own line with a retry; a contract that cannot be signed shows
/// its form disabled under [ContractStrings.formReadOnly], with Continue
/// disabled; otherwise the editable form.
///
/// **Errors** stay hidden until Continue is first pressed — an untouched form
/// is not wrong yet — and then follow the form as it is edited. A signing
/// attempt refused with `invalid_fields` shows them at once. Reasons for
/// keys this client has no field for are one line above Continue.
///
/// **Continue** checks the form and, only when no field has an error, calls
/// [onContinue]; otherwise it scrolls to the first field at fault. It calls
/// no endpoint — the preview is the next step's.
class ContractFormScreen extends StatefulWidget {
  const ContractFormScreen({
    super.key,
    required this.contractId,
    this.repository,
    this.controller,
    this.onContinue,
  });

  /// The contract to fill in — `StudentContract.id`.
  final String contractId;

  /// Defaults to the real API. Ignored when [controller] is given.
  final ContractRepository? repository;

  /// A controller shared with the steps after this one; not disposed here.
  /// Loaded by the screen if it has not been yet.
  final ContractSigningController? controller;

  /// Called by Continue once the form passes the client check.
  final void Function(
    BuildContext context,
    ContractSigningController controller,
  )?
  onContinue;

  /// Pushes the form for [contractId] over [context]'s navigator.
  static Future<void> open(
    BuildContext context, {
    required String contractId,
    ContractRepository? repository,
    void Function(BuildContext, ContractSigningController)? onContinue,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ContractFormScreen(
        contractId: contractId,
        repository: repository,
        onContinue: onContinue,
      ),
    ),
  );

  @override
  State<ContractFormScreen> createState() => _ContractFormScreenState();
}

class _ContractFormScreenState extends State<ContractFormScreen> {
  late final ContractSigningController _controller;
  late final bool _ownsController;

  final Map<ContractFormField, TextEditingController> _texts = {
    for (final field in ContractFormField.values)
      field: TextEditingController(),
  };
  final Map<ContractFormField, GlobalKey> _fieldKeys = {
    for (final field in ContractFormField.values) field: GlobalKey(),
  };

  /// The detail whose form the text controllers hold.
  ContractDetail? _shownDetail;

  /// True while the text controllers are being set from the controller's
  /// form, so that is not echoed back as an edit.
  bool _syncing = false;

  /// Continue has been pressed: errors are shown from now on.
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    final shared = widget.controller;
    assert(shared == null || shared.contractId == widget.contractId);
    _ownsController = shared == null;
    _controller =
        shared ??
        ContractSigningController(
          contractId: widget.contractId,
          repository: widget.repository ?? HttpContractRepository(),
        );
    for (final MapEntry(key: field, value: text) in _texts.entries) {
      text.addListener(() => _onTextChanged(field));
    }
    _controller.addListener(_syncTexts);
    _syncTexts();
    if (!_controller.hasLoadedOnce && !_controller.loading) {
      _controller.load();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_syncTexts);
    if (_ownsController) _controller.dispose();
    for (final text in _texts.values) {
      text.dispose();
    }
    super.dispose();
  }

  /// A new detail (a load or reload) brings a new form: the fields show it.
  void _syncTexts() {
    final detail = _controller.detail;
    if (identical(detail, _shownDetail)) return;
    _shownDetail = detail;
    _syncing = true;
    for (final MapEntry(key: field, value: text) in _texts.entries) {
      text.text = _controller.form.valueOf(field);
    }
    _syncing = false;
  }

  void _onTextChanged(ContractFormField field) {
    if (_syncing) return;
    final value = _texts[field]!.text;
    // A text controller also notifies on cursor moves; only a changed value
    // is an edit (and an edit drops that field's server reason).
    if (value != _controller.form.valueOf(field)) {
      _controller.updateField(field, value);
    }
  }

  bool get _showErrors =>
      _attempted ||
      _controller.signFailure?.kind == ContractFailureKind.invalidFields;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.page(context, navigationBar: context.palette.surface),
      child: Scaffold(
        backgroundColor: context.palette.surface,
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
                      listenable: _controller,
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
    final detail = _controller.detail;
    if (_controller.loading || (detail == null && !_controller.hasLoadedOnce)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (detail == null) {
      final kind =
          _controller.loadFailure?.kind ?? ContractFailureKind.unexpected;
      return ContractMessage(
        message: ContractStrings.messageFor(kind),
        action: TextButton(
          onPressed: _controller.load,
          child: const Text(ContractStrings.retry),
        ),
      );
    }
    return _form(detail);
  }

  Widget _form(ContractDetail detail) {
    final editable = _controller.canSign;
    final rules = detail.rules;
    final lastTyped = rules.guardianRequired
        ? ContractFormField.guardianRegister
        : ContractFormField.address;

    Widget field(ContractFormField f) =>
        _textField(f, editable: editable, last: f == lastTyped);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        AppDimens.headingToForm,
        AppDimens.screenPadding,
        AppDimens.screenPadding + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!editable) ...[
            Text(
              ContractStrings.formReadOnly,
              style: AppTypography.statLabel.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.headingToForm),
          ],
          const _SectionTitle(ContractStrings.formStudentSection),
          ..._spaced(_studentFields.map(field)),
          if (rules.guardianRequired) ...[
            const SizedBox(height: AppDimens.headingToForm),
            const _SectionTitle(ContractStrings.formGuardianSection),
            ..._spaced(_guardianFields.map(field)),
          ],
          if (rules.finalPaymentDateRequired) ...[
            const SizedBox(height: AppDimens.headingToForm),
            const _SectionTitle(ContractStrings.formPaymentSection),
            _dateField(detail.rules, editable: editable),
          ],
          if (_showErrors && _controller.unmatchedServerErrors.isNotEmpty) ...[
            const SizedBox(height: AppDimens.fieldGap),
            const _ErrorLine(ContractStrings.formUnmatchedErrors),
          ],
          const SizedBox(height: AppDimens.formToButtons),
          AppButton(
            label: ContractStrings.formContinue,
            onPressed: editable ? _continue : null,
          ),
        ],
      ),
    );
  }

  Widget _textField(
    ContractFormField field, {
    required bool editable,
    required bool last,
  }) {
    return _LabelledField(
      key: _fieldKeys[field],
      error: _errorFor(field),
      child: AppTextField(
        controller: _texts[field]!,
        placeholder: ContractStrings.fieldLabel(field),
        errorText: _errorFor(field),
        enabled: editable,
        keyboardType: _keyboardFor(field),
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
      ),
    );
  }

  Widget _dateField(ContractRules rules, {required bool editable}) {
    const field = ContractFormField.finalPaymentDate;
    return _LabelledField(
      key: _fieldKeys[field],
      error: _errorFor(field),
      child: AppTextField(
        controller: _texts[field]!,
        placeholder: ContractStrings.fieldLabel(field),
        errorText: _errorFor(field),
        enabled: editable,
        readOnly: true,
        onTap: editable ? () => _pickDate(rules) : null,
        suffix: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            AppIcons.calendar,
            size: 20,
            color: context.palette.textSecondary,
          ),
        ),
      ),
    );
  }

  String? _errorFor(ContractFormField field) {
    if (!_showErrors) return null;
    final reason = _controller.errorFor(field);
    return reason == null ? null : ContractStrings.fieldError(field, reason);
  }

  Future<void> _pickDate(ContractRules rules) async {
    final first = DateUtils.dateOnly(rules.finalPaymentDateMin);
    final max = rules.finalPaymentDateMax;
    var last = max == null
        ? DateTime(first.year + _openEndedPickerYears, first.month, first.day)
        : DateUtils.dateOnly(max);
    if (last.isBefore(first)) last = first;

    final text = _texts[ContractFormField.finalPaymentDate]!;
    final current = DateTime.tryParse(text.text);
    final initial =
        current == null || current.isBefore(first) || current.isAfter(last)
        ? first
        : current;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      // The calendar only: the picker's own text entry would be free-text
      // date typing by another route.
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null && mounted) text.text = _isoDay(picked);
  }

  void _continue() {
    FocusScope.of(context).unfocus();
    setState(() => _attempted = true);
    final errors = _controller.fieldErrors;
    if (errors.isEmpty) {
      widget.onContinue?.call(context, _controller);
      return;
    }
    final firstBad = _displayOrder.firstWhere(
      errors.containsKey,
      orElse: () => errors.keys.first,
    );
    // After this frame, so the error lines are laid out before scrolling.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _fieldKeys[firstBad]?.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.1,
        duration: const Duration(milliseconds: 250),
      );
    });
  }

  /// The keyboard for [field]. Nothing is filtered while typing: a
  /// prefilled value is shown as the server sent it, and the validator says
  /// what is wrong with it.
  static TextInputType _keyboardFor(ContractFormField field) => switch (field) {
    ContractFormField.phone => TextInputType.phone,
    ContractFormField.email => TextInputType.emailAddress,
    ContractFormField.address => TextInputType.streetAddress,
    ContractFormField.register ||
    ContractFormField.guardianRegister => TextInputType.text,
    _ => TextInputType.name,
  };

  /// `YYYY-MM-DD`, the API's form of a date.
  static String _isoDay(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-'
        '${two(date.month)}-${two(date.day)}';
  }

  static Iterable<Widget> _spaced(Iterable<Widget> fields) sync* {
    var first = true;
    for (final field in fields) {
      if (!first) yield const SizedBox(height: AppDimens.fieldGap);
      first = false;
      yield field;
    }
  }
}

/// The student's fields, top to bottom.
const List<ContractFormField> _studentFields = [
  ContractFormField.lastName,
  ContractFormField.firstName,
  ContractFormField.register,
  ContractFormField.phone,
  ContractFormField.email,
  ContractFormField.address,
];

/// The guardian's fields, top to bottom — shown for a junior course.
const List<ContractFormField> _guardianFields = [
  ContractFormField.guardianRelation,
  ContractFormField.guardianLastName,
  ContractFormField.guardianFirstName,
  ContractFormField.guardianRegister,
];

/// Every field in the order the screen draws them.
const List<ContractFormField> _displayOrder = [
  ..._studentFields,
  ..._guardianFields,
  ContractFormField.finalPaymentDate,
];

/// With no `final_payment_date_max` the backend sets no upper bound, but the
/// date picker needs one: this many years past the minimum. A picker range,
/// not a rule — the validator checks none.
const int _openEndedPickerYears = 5;

/// A section heading over a group of fields.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.fieldGap),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: AppTypography.cardHeading.copyWith(
            color: context.palette.textTitle,
          ),
        ),
      ),
    );
  }
}

/// [AppTextField] draws no message under itself (Login carries its reason in
/// a band of its own); a form of many fields needs each reason by its field,
/// so it goes in a line under the box.
class _LabelledField extends StatelessWidget {
  const _LabelledField({super.key, required this.child, this.error});

  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child,
        if (error case final error?)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: _ErrorLine(error),
          ),
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.fieldError.copyWith(color: context.palette.error),
    );
  }
}
