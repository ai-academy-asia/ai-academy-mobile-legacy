import 'package:flutter/foundation.dart';

import '../../../core/utils/open_external_url.dart';
import '../domain/contract_detail.dart';
import '../domain/contract_failure.dart';
import '../domain/contract_form_validator.dart';
import '../domain/contract_repository.dart';
import '../domain/student_contract.dart';

/// What [ContractSigningController.sign] did.
enum ContractSignResult {
  /// The contract is signed; [ContractSigningController.detail] is the
  /// signed one.
  signed,

  /// Nothing was sent: the detail is not loaded, or the contract cannot be
  /// signed (`can_sign` is false).
  notSignable,

  /// Nothing was sent: a sign request is already in flight.
  inProgress,

  /// Nothing was sent: no signature was drawn.
  emptySignature,

  /// Nothing was sent: the student has not agreed.
  notAgreed,

  /// Nothing was sent: the form fails the client's check — see
  /// [ContractSigningController.fieldErrors].
  invalidForm,

  /// The request was sent and refused, or never completed — see
  /// [ContractSigningController.signFailure].
  failed,
}

/// What [ContractSigningController.download] did.
enum ContractDownloadResult {
  /// A fresh link was fetched and the OS took it.
  opened,

  /// Nothing was sent: a download is already in flight.
  inProgress,

  /// The link could not be had, or the OS would not open it — see
  /// [ContractSigningController.downloadFailure].
  failed,
}

/// The E-Contract signing logic, for a screen not yet designed (Issue #306):
/// one contract's detail, its editable form checked exactly as the backend
/// checks it ([ContractFormValidator]), the sign request, and the signed
/// PDF's download. It draws nothing.
///
/// **Signing is guarded locally.** [sign] sends nothing unless the detail is
/// loaded and signable, no other sign is in flight, a signature is drawn,
/// the student has agreed, and the form passes the client check — the
/// backend would refuse each of these anyway, and a signed contract cannot
/// be undone by the student (only a staff reset can).
///
/// **Errors.** A field's error is the server's `invalid_fields` reason when
/// it gave one since the field was last edited, otherwise the client's. A
/// failed sign keeps the whole [ContractFailure] — kind, detail, field
/// reasons — and `already_signed` reloads the detail so the screen shows the
/// contract as it now is. Until a load succeeds after that, the contract is
/// treated as signed whatever the stale detail says, so a failed reload
/// cannot make it signable again. Field reasons for keys this client does
/// not know are kept in [unmatchedServerErrors], not dropped.
///
/// **Overlapping requests.** Each [load] takes a generation number, and a
/// successful [sign] or [dispose] moves the generation on: a load answering
/// after a newer load, after the contract was signed, or after disposal is
/// dropped, so an older response never overwrites newer state. Nothing
/// notifies after [dispose], and an `already_signed` reload is not started
/// once disposed.
///
/// The shapes behind it are the backend's own source (`docs/
/// e_contract_api_v1.md`, `fields.py`), not observed live.
class ContractSigningController extends ChangeNotifier {
  ContractSigningController({
    required this.contractId,
    required this._repository,
    Future<bool> Function(Uri url)? openUrl,
  }) : _openUrl = openUrl ?? openExternalUrl;

  /// The contract this controller is about — `StudentContract.id`.
  final String contractId;

  final ContractRepository _repository;
  final Future<bool> Function(Uri url) _openUrl;

  bool _disposed = false;

  /// Bumped by every [load], a successful [sign] and [dispose]; a load whose
  /// number is no longer current is dropped.
  int _generation = 0;

  /// The server said `already_signed`; set until a load succeeds, so the
  /// stale `pending` detail cannot make the contract signable again.
  bool _serverReportedSigned = false;

  bool _loading = false;
  bool _hasLoadedOnce = false;
  ContractDetail? _detail;
  ContractFailure? _loadFailure;

  ContractForm _form = const ContractForm();
  Map<ContractFormField, ContractFieldReason> _serverErrors = const {};
  Map<String, ContractFieldReason> _unmatchedServerErrors = const {};

  bool _signing = false;
  ContractFailure? _signFailure;

  bool _downloading = false;
  ContractFailure? _downloadFailure;

  bool get loading => _loading;
  bool get hasLoadedOnce => _hasLoadedOnce;

  /// The contract as last loaded or signed. Null until a load succeeds.
  ContractDetail? get detail => _detail;

  /// Why the last [load] failed. Null once one succeeds.
  ContractFailure? get loadFailure => _loadFailure;

  /// The form as the student has it — the detail's, then their edits.
  ContractForm get form => _form;

  /// Whether the contract can be signed now: loaded, `can_sign`, `pending`,
  /// and not reported `already_signed` since the last successful load.
  bool get canSign {
    final contract = _detail?.contract;
    return !_serverReportedSigned &&
        contract != null &&
        contract.canSign &&
        contract.status == StudentContractStatus.pending;
  }

  bool get signing => _signing;

  /// Why the last sent [sign] failed. Null after one succeeds, and until one
  /// is sent.
  ContractFailure? get signFailure => _signFailure;

  bool get downloading => _downloading;

  /// Why the last [download] failed. Null after one opens.
  ContractFailure? get downloadFailure => _downloadFailure;

  /// The client's check of the current form. Empty when the detail is not
  /// loaded.
  Map<ContractFormField, ContractFieldReason> get clientErrors {
    final detail = _detail;
    if (detail == null) return const {};
    return ContractFormValidator.validate(_form, detail.rules);
  }

  /// Each field's error: the server's reason when it gave one since the
  /// field was last edited, otherwise the client's.
  Map<ContractFormField, ContractFieldReason> get fieldErrors => {
    ...clientErrors,
    ..._serverErrors,
  };

  /// Server `invalid_fields` reasons for keys this client does not know.
  Map<String, ContractFieldReason> get unmatchedServerErrors =>
      _unmatchedServerErrors;

  /// The error to show for [field], or null.
  ContractFieldReason? errorFor(ContractFormField field) =>
      _serverErrors[field] ?? clientErrors[field];

  /// Loads (or reloads) the detail. Its form replaces the edited one, and
  /// earlier server field reasons are cleared — they were about a form that
  /// is gone. An answer overtaken by a newer load, a successful [sign] or
  /// [dispose] is dropped (see the class doc).
  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_generation;
    _loading = true;
    _loadFailure = null;
    _notify();

    ContractDetail? loaded;
    ContractFailure? failure;
    try {
      loaded = await _repository.getContractDetail(contractId);
    } on ContractFailure catch (error) {
      failure = error;
    } catch (error) {
      failure = _unexpected(error);
    }

    if (generation != _generation) return;
    if (loaded != null) {
      _adopt(loaded);
    } else {
      _loadFailure = failure;
    }
    _loading = false;
    _hasLoadedOnce = true;
    _notify();
  }

  /// Sets [field] to [value]. A server reason for that field no longer
  /// applies to the new value, so it is dropped; the client check follows
  /// the form on its own.
  void updateField(ContractFormField field, String value) {
    _form = _form.withValue(field, value);
    if (_serverErrors.containsKey(field)) {
      _serverErrors = {..._serverErrors}..remove(field);
    }
    _notify();
  }

  /// Signs with [png] — the signature pad's export — and [agreed], the
  /// student's own agreement, sent as given. See [ContractSignResult] for
  /// every case that sends nothing.
  Future<ContractSignResult> sign(
    Uint8List? png, {
    required bool agreed,
  }) async {
    final detail = _detail;
    if (detail == null || !canSign) return ContractSignResult.notSignable;
    if (_signing) return ContractSignResult.inProgress;
    if (png == null || png.isEmpty) return ContractSignResult.emptySignature;
    if (!agreed) return ContractSignResult.notAgreed;
    if (ContractFormValidator.validate(_form, detail.rules).isNotEmpty) {
      return ContractSignResult.invalidForm;
    }

    _signing = true;
    _signFailure = null;
    _notify();
    try {
      final signed = await _repository.signContract(
        contractId,
        form: ContractFormValidator.normalize(_form),
        agreed: agreed,
        signature: signatureDataUrl(png),
      );
      // The authoritative state now: any load still in flight began before
      // it and is dropped when it answers.
      _generation++;
      _loading = false;
      _adopt(signed);
      return ContractSignResult.signed;
    } on ContractFailure catch (failure) {
      _signFailure = failure;
      _takeServerErrors(failure);
      if (failure.kind == ContractFailureKind.alreadySigned) {
        // Signed elsewhere (another device, a retried request). Treat it as
        // signed until a load says otherwise, then show it as it now is.
        // Still [signing] until the reload lands, so a tap meanwhile cannot
        // send again; a failed reload keeps the guard and its loadFailure.
        _serverReportedSigned = true;
        if (!_disposed) await load();
      }
      return ContractSignResult.failed;
    } catch (error) {
      _signFailure = _unexpected(error);
      return ContractSignResult.failed;
    } finally {
      _signing = false;
      _notify();
    }
  }

  /// Fetches a fresh link to the signed PDF — it expires in minutes, so it is
  /// never reused — and hands it to the OS. `not_signed`, any other failure,
  /// and a link the OS will not open are [ContractDownloadResult.failed].
  Future<ContractDownloadResult> download() async {
    if (_downloading) return ContractDownloadResult.inProgress;
    _downloading = true;
    _downloadFailure = null;
    _notify();
    try {
      final link = await _repository.getContractDownload(contractId);
      if (await _openUrl(link.url)) return ContractDownloadResult.opened;
      _downloadFailure = const ContractFailure(
        ContractFailureKind.unexpected,
        detail: 'the OS did not open the download link',
      );
      return ContractDownloadResult.failed;
    } on ContractFailure catch (failure) {
      _downloadFailure = failure;
      return ContractDownloadResult.failed;
    } catch (error) {
      _downloadFailure = _unexpected(error);
      return ContractDownloadResult.failed;
    } finally {
      _downloading = false;
      _notify();
    }
  }

  void _adopt(ContractDetail detail) {
    _serverReportedSigned = false;
    _detail = detail;
    _form = detail.form;
    _serverErrors = const {};
    _unmatchedServerErrors = const {};
  }

  void _takeServerErrors(ContractFailure failure) {
    if (failure.kind != ContractFailureKind.invalidFields) return;
    final matched = <ContractFormField, ContractFieldReason>{};
    final unmatched = <String, ContractFieldReason>{};
    for (final MapEntry(:key, :value) in failure.fieldErrors.entries) {
      final field = ContractFormField.fromApi(key);
      if (field == null) {
        unmatched[key] = value;
      } else {
        matched[field] = value;
      }
    }
    _serverErrors = matched;
    _unmatchedServerErrors = unmatched;
  }

  static ContractFailure _unexpected(Object error) =>
      ContractFailure(ContractFailureKind.unexpected, detail: '$error');

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
