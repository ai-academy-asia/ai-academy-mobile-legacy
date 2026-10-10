import 'package:aia_mobile/features/contracts/domain/contract_detail.dart';
import 'package:aia_mobile/features/contracts/domain/contract_failure.dart';
import 'package:aia_mobile/features/contracts/domain/contract_repository.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';

/// A repository the tests drive by hand: returns [contracts], or throws a
/// chosen [ContractFailure]. Detail, sign and download answer [detail],
/// [signed] and [download], or throw [failure] too; each call is recorded.
class FakeContractRepository implements ContractRepository {
  FakeContractRepository({
    this.contracts = const [],
    this.failure,
    this.detail,
    this.signed,
    this.download,
  });

  /// Returned on success.
  List<StudentContract> contracts;

  /// Thrown instead of returning, when set.
  ContractFailure? failure;

  ContractDetail? detail;
  ContractDetail? signed;
  ContractDownload? download;

  /// How many times [getContracts] has been called.
  int callCount = 0;

  final List<String> detailCalls = [];
  final List<({String id, ContractForm form, bool agreed, String signature})>
  signCalls = [];
  final List<String> downloadCalls = [];

  @override
  Future<List<StudentContract>> getContracts() async {
    callCount++;
    if (failure case final failure?) throw failure;
    return contracts;
  }

  @override
  Future<ContractDetail> getContractDetail(String contractId) async {
    detailCalls.add(contractId);
    if (failure case final failure?) throw failure;
    return detail ?? (throw StateError('no detail configured'));
  }

  @override
  Future<ContractDetail> signContract(
    String contractId, {
    required ContractForm form,
    required bool agreed,
    required String signature,
  }) async {
    signCalls.add((
      id: contractId,
      form: form,
      agreed: agreed,
      signature: signature,
    ));
    if (failure case final failure?) throw failure;
    return signed ?? (throw StateError('no signed detail configured'));
  }

  @override
  Future<ContractDownload> getContractDownload(String contractId) async {
    downloadCalls.add(contractId);
    if (failure case final failure?) throw failure;
    return download ?? (throw StateError('no download configured'));
  }
}
