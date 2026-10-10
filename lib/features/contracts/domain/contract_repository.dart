import 'student_contract.dart';

/// The signed-in student's e-contracts (Issue #294).
abstract interface class ContractRepository {
  /// `GET /me/contracts`. Throws `ContractFailure` when it cannot be read.
  Future<List<StudentContract>> getContracts();
}
