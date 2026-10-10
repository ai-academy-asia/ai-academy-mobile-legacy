import 'package:aia_mobile/features/contracts/domain/student_contract.dart';
import 'package:flutter_test/flutter_test.dart';

/// The backend's banner rule (`docs/e_contract_api_v1.md`, Issue #300): the
/// newest signable contract, else the newest current one, else none — the
/// list is newest first. Test values only.
void main() {
  const pendingSignable = StudentContract(
    id: '3',
    status: StudentContractStatus.pending,
    canSign: true,
    isCurrent: true,
  );
  const olderPendingSignable = StudentContract(
    id: '1',
    status: StudentContractStatus.pending,
    canSign: true,
    isCurrent: true,
  );
  const signed = StudentContract(
    id: '4',
    status: StudentContractStatus.signed,
    canView: true,
    isCurrent: true,
  );
  const olderSigned = StudentContract(
    id: '2',
    status: StudentContractStatus.signed,
    isCurrent: true,
  );
  const cancelled = StudentContract(
    id: '5',
    status: StudentContractStatus.cancelled,
  );

  test('a signable contract wins over a newer current one', () {
    expect(selectNoticeContract([signed, pendingSignable]), pendingSignable);
  });

  test('of several signable contracts, the newest (first) wins', () {
    expect(
      selectNoticeContract([pendingSignable, olderPendingSignable]),
      pendingSignable,
    );
  });

  test('with none signable, the newest current contract', () {
    expect(selectNoticeContract([cancelled, signed, olderSigned]), signed);
  });

  test('none signable and none current: no contract', () {
    expect(selectNoticeContract([cancelled]), isNull);
  });

  test('an empty list: no contract', () {
    expect(selectNoticeContract(const []), isNull);
  });

  test('the flags decide, not the status', () {
    // A pending contract that cannot be signed (e.g. its template was
    // removed) is still current, so it is chosen by the fallback.
    const pendingNotSignable = StudentContract(
      status: StudentContractStatus.pending,
      isCurrent: true,
    );
    expect(selectNoticeContract([pendingNotSignable]), pendingNotSignable);
  });
}
