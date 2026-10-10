import 'package:flutter/foundation.dart';

import '../../../core/utils/open_external_url.dart';
import '../domain/contract_failure.dart';
import '../domain/contract_repository.dart';
import '../domain/student_contract.dart';
import 'contract_strings.dart';

/// State for the E-Contract screen (Issues #294, #312): the student's
/// contracts from `GET /me/contracts`, or the copy for why they could not be
/// read — and each signed contract's download.
///
/// The download fetches a fresh pre-signed link on every tap
/// (`GET /me/contracts/{id}/download`; it expires in five minutes, so it is
/// never cached) and opens it outside the app through the same
/// [openExternalUrl] the certificate and lesson materials use. While one is
/// in flight its button is busy and a second tap does nothing.
class ContractListController extends ChangeNotifier {
  ContractListController({
    required this._repository,
    Future<bool> Function(Uri url)? openUrl,
  }) : _openUrl = openUrl ?? openExternalUrl;

  final ContractRepository _repository;
  final Future<bool> Function(Uri url) _openUrl;
  final Set<String> _downloading = {};

  bool _disposed = false;
  bool _loading = false;
  bool _hasLoadedOnce = false;
  List<StudentContract> _contracts = const [];
  String? _errorMessage;

  bool get loading => _loading;
  bool get hasLoadedOnce => _hasLoadedOnce;
  List<StudentContract> get contracts => _contracts;

  /// The list's failure, as the screen shows it. Null when it loaded.
  String? get errorMessage => _errorMessage;

  bool isDownloading(String contractId) => _downloading.contains(contractId);

  /// Fetches [contractId]'s download link and opens it. Answers null once the
  /// OS has taken the link, or the copy to show when it could not be had or
  /// opened — `not_signed` included, never reported as a success. Ignored
  /// (null) while that contract's download is already in flight.
  Future<String?> download(String contractId) async {
    if (_downloading.contains(contractId)) return null;
    _downloading.add(contractId);
    _notify();
    try {
      final link = await _repository.getContractDownload(contractId);
      final opened = await _openUrl(link.url);
      return opened
          ? null
          : ContractStrings.messageFor(ContractFailureKind.unexpected);
    } on ContractFailure catch (failure) {
      return ContractStrings.messageFor(failure.kind);
    } catch (_) {
      return ContractStrings.messageFor(ContractFailureKind.unexpected);
    } finally {
      _downloading.remove(contractId);
      _notify();
    }
  }

  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    _notify();
    try {
      _contracts = await _repository.getContracts();
    } on ContractFailure catch (failure) {
      _errorMessage = ContractStrings.messageFor(failure.kind);
    } catch (_) {
      _errorMessage = ContractStrings.messageFor(
        ContractFailureKind.unexpected,
      );
    } finally {
      _loading = false;
      _hasLoadedOnce = true;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
