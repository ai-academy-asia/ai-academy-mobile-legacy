/// Where [AuthSessionStore] keeps its session so it outlives the process
/// (Issue #235).
///
/// One opaque string — the store owns the encoding — so an implementation is
/// only a key in some device storage. The app's own is
/// `SecureSessionPersistence` (Keychain / Android encrypted storage); tests
/// pass an in-memory one.
abstract interface class SessionPersistence {
  /// The stored value, or null when nothing is stored.
  Future<String?> read();

  Future<void> write(String value);

  Future<void> delete();
}
