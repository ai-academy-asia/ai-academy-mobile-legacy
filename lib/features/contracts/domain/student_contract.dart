/// One entry of `GET /me/contracts` (Issue #294).
///
/// **Only [id] is read.** The verified response is the envelope
/// `{"contracts": [...]}`, seen live only empty; the Postman collection's own
/// test script reads `contracts[i].id`, which is the single item field there
/// is any evidence for. A title, course, status or date has never been seen
/// in a response (`BACKEND GAP`), so none is modelled — the screen draws
/// none rather than guess.
class StudentContract {
  const StudentContract({this.id});

  /// The contract's identifier, kept as text because its JSON type (number
  /// or string) is not confirmed. Null when the item carries no usable `id`.
  /// Nothing reads it yet; it is what `GET /me/contracts/{contract_id}` will
  /// take once that response is documented.
  final String? id;
}
