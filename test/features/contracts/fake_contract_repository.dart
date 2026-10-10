import 'dart:async';
import 'dart:typed_data';

import 'package:aia_mobile/features/contracts/domain/contract_detail.dart';
import 'package:aia_mobile/features/contracts/domain/contract_failure.dart';
import 'package:aia_mobile/features/contracts/domain/contract_repository.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';

/// A repository the tests drive by hand. Every call is recorded; each method
/// answers its own value or throws its own failure:
///
///  * the list — [contracts], or [failure];
///  * detail — [detail], or [detailFailure]; held open while [detailGate]
///    is unfinished;
///  * sign — [signed], or [signFailure]; held open while [signGate] is
///    unfinished, so a test can act while one is in flight;
///  * download — the next of [downloads] (one per call, so each call's link
///    is its own), or [downloadFailure];
///  * preview — [preview], or [previewFailure].
class FakeContractRepository implements ContractRepository {
  FakeContractRepository({
    this.contracts = const [],
    this.failure,
    this.detail,
    this.detailFailure,
    this.signed,
    this.signFailure,
    List<ContractDownload>? downloads,
    this.downloadFailure,
    this.preview,
    this.previewFailure,
  }) : downloads = downloads ?? [];

  List<StudentContract> contracts;

  /// Thrown by the list, when set.
  ContractFailure? failure;

  ContractDetail? detail;
  ContractFailure? detailFailure;

  /// When set and unfinished, detail waits for it before answering.
  Completer<void>? detailGate;

  ContractDetail? signed;
  ContractFailure? signFailure;

  /// When set and unfinished, sign waits for it before answering.
  Completer<void>? signGate;

  final List<ContractDownload> downloads;
  ContractFailure? downloadFailure;

  Uint8List? preview;
  ContractFailure? previewFailure;

  /// How many times [getContracts] has been called.
  int callCount = 0;

  final List<String> detailCalls = [];
  final List<({String id, ContractForm form, bool agreed, String signature})>
  signCalls = [];
  final List<String> downloadCalls = [];
  final List<({String id, ContractForm form})> previewCalls = [];

  @override
  Future<List<StudentContract>> getContracts() async {
    callCount++;
    if (failure case final failure?) throw failure;
    return contracts;
  }

  @override
  Future<ContractDetail> getContractDetail(String contractId) async {
    detailCalls.add(contractId);
    if (detailGate case final gate?) await gate.future;
    if (detailFailure case final failure?) throw failure;
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
    if (signGate case final gate?) await gate.future;
    if (signFailure case final failure?) throw failure;
    return signed ?? (throw StateError('no signed detail configured'));
  }

  @override
  Future<Uint8List> getContractPreview(
    String contractId, {
    required ContractForm form,
  }) async {
    previewCalls.add((id: contractId, form: form));
    if (previewFailure case final failure?) throw failure;
    return preview ?? (throw StateError('no preview configured'));
  }

  @override
  Future<ContractDownload> getContractDownload(String contractId) async {
    downloadCalls.add(contractId);
    if (downloadFailure case final failure?) throw failure;
    if (downloads.isEmpty) throw StateError('no download configured');
    return downloads.removeAt(0);
  }
}
