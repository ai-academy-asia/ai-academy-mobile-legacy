import 'package:flutter/foundation.dart';

import '../domain/contract_failure.dart';
import '../domain/contract_repository.dart';
import '../domain/student_contract.dart';
import 'contract_strings.dart';

/// State for the E-Contract screen (Issue #294): the student's contracts
/// from `GET /me/contracts`, or the copy for why they could not be read.
class ContractListController extends ChangeNotifier {
  ContractListController({required this._repository});

  final ContractRepository _repository;

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
