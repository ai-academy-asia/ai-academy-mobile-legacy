import 'package:aia_mobile/features/contracts/domain/contract_failure.dart';
import 'package:aia_mobile/features/contracts/domain/contract_repository.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';

/// A repository the tests drive by hand: returns [contracts], or throws a
/// chosen [ContractFailure].
class FakeContractRepository implements ContractRepository {
  FakeContractRepository({this.contracts = const [], this.failure});

  /// Returned on success.
  List<StudentContract> contracts;

  /// Thrown instead of returning, when set.
  ContractFailure? failure;

  /// How many times [getContracts] has been called.
  int callCount = 0;

  @override
  Future<List<StudentContract>> getContracts() async {
    callCount++;
    if (failure case final failure?) throw failure;
    return contracts;
  }
}
