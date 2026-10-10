/// One entry of `GET /me/contracts` (Issues #294, #300).
///
/// **The fields are documented by the backend's own source, not observed
/// live.** `ai-academy-backend` `docs/e_contract_api_v1.md` and
/// `StudentContract.to_dict` / `student._summary` (commit `208e1c9`) define
/// them; the only production response seen is `{"contracts": []}`. Every
/// field is therefore read leniently: a missing or mistyped one is null (or
/// false for the flags), never a failure — one odd field must not hide the
/// contract or take down the screens that read it.
class StudentContract {
  const StudentContract({
    this.id,
    this.contractNumber,
    this.status = StudentContractStatus.unknown,
    this.course,
    this.cohort,
    this.createdAt,
    this.signedAt,
    this.cancelledAt,
    this.canView = false,
    this.canSign = false,
    this.isCurrent = false,
    this.documentUrl,
  });

  /// The contract's id, kept as text: the documented type is an integer, but
  /// it is what `GET /me/contracts/{contract_id}` takes, nothing more. Null
  /// when the item carries no usable `id`.
  final String? id;

  /// `contract_number`, e.g. `AIAA-C-2026-00012`.
  final String? contractNumber;

  final StudentContractStatus status;

  final ContractCourse? course;
  final ContractCohort? cohort;

  final DateTime? createdAt;
  final DateTime? signedAt;
  final DateTime? cancelledAt;

  /// `can_view` — signed with a PDF, or pending with a template to preview.
  final bool canView;

  /// `can_sign` — pending, the enrollment active, a template present.
  final bool canSign;

  /// `is_current` — false only for a cancelled contract.
  final bool isCurrent;

  /// `document_url` — the API path of the download call once signed.
  final String? documentUrl;
}

/// The backend's three statuses (`pending`, `signed`, `cancelled`), and
/// [unknown] for anything else — a value this build does not know is never
/// read as one it does.
enum StudentContractStatus {
  pending,
  signed,
  cancelled,
  unknown;

  static StudentContractStatus fromApi(Object? value) => switch (value) {
    'pending' => pending,
    'signed' => signed,
    'cancelled' => cancelled,
    _ => unknown,
  };
}

/// A contract's `course` object.
class ContractCourse {
  const ContractCourse({
    this.id,
    this.slug,
    this.titleMn,
    this.titleEn,
    this.level,
  });

  final int? id;
  final String? slug;
  final String? titleMn;
  final String? titleEn;

  /// `adult` or `junior`, as the backend sends it.
  final String? level;
}

/// A contract's `cohort` object.
class ContractCohort {
  const ContractCohort({this.id, this.name, this.startDate, this.endDate});

  final int? id;
  final String? name;
  final DateTime? startDate;
  final DateTime? endDate;
}

/// The contract a contract notice is about — the backend's own rule
/// (`docs/e_contract_api_v1.md`): the newest with [StudentContract.canSign];
/// with none signable, the newest with [StudentContract.isCurrent]; else
/// none. "Newest" is the first such entry, as the API lists contracts newest
/// first.
StudentContract? selectNoticeContract(List<StudentContract> contracts) {
  for (final contract in contracts) {
    if (contract.canSign) return contract;
  }
  for (final contract in contracts) {
    if (contract.isCurrent) return contract;
  }
  return null;
}
