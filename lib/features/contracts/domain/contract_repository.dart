import 'contract_detail.dart';
import 'student_contract.dart';

/// The signed-in student's e-contracts (Issues #294, #302).
///
/// Every method throws `ContractFailure` when it cannot answer.
abstract interface class ContractRepository {
  /// `GET /me/contracts`.
  Future<List<StudentContract>> getContracts();

  /// `GET /me/contracts/{contract_id}`.
  Future<ContractDetail> getContractDetail(String contractId);

  /// `POST /me/contracts/{contract_id}/sign` with `{form, agreed,
  /// signature}`. [signature] is the drawn PNG as a data URL
  /// (`data:image/png;base64,…`) or bare base64 — see
  /// [signatureDataUrl]. [agreed] is sent as given: the student's own
  /// agreement, never assumed. Answers the signed contract's detail.
  ///
  /// **Irreversible for the student** — only a staff reset undoes it.
  Future<ContractDetail> signContract(
    String contractId, {
    required ContractForm form,
    required bool agreed,
    required String signature,
  });

  /// `GET /me/contracts/{contract_id}/download` — signed contracts only.
  Future<ContractDownload> getContractDownload(String contractId);
}
