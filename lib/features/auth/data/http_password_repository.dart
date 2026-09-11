import 'package:http/http.dart' as http;

import '../domain/auth_session_store.dart';
import '../domain/password_repository.dart';
import 'auth_http.dart';

/// Changes the signed-in user's password against the AI Academy API.
///
///     POST https://api.ai-academy.asia/auth/change-password
///     { "current_password": "...", "new_password": "..." }
///
/// The screen's third field — "Шинэ нууц үг давтах" — is a client-side check
/// only. It never reaches this class: [PasswordRepository.changePassword] takes
/// two passwords, and the body below carries exactly the two keys the contract
/// names.
///
/// **The success response has no confirmed shape, so none is asserted.** This
/// follows the admin panel's own precedent for endpoints whose bodies were
/// never recorded (`staff.repository.http.ts`): a non-2xx already throws, and
/// asserting an unverified shape would invent a contract. Any 2xx is taken as
/// the password having changed. Add the check here once a real response is
/// captured.
class HttpPasswordRepository implements PasswordRepository {
  HttpPasswordRepository({
    http.Client? client,
    Uri? baseUrl,
    AuthSessionStore? sessionStore,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? Uri.parse(defaultBaseUrl),
       _sessionStore = sessionStore ?? AuthSessionStore.instance;

  static const String defaultBaseUrl = 'https://api.ai-academy.asia';

  final http.Client _client;
  final Uri _baseUrl;
  final AuthSessionStore _sessionStore;
  final Duration timeout;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await postJson(
      client: _client,
      url: _baseUrl.resolve('/auth/change-password'),
      // The request names no user, so the token is the only thing that says
      // whose password this is — it is sent whenever a session is held. This
      // is inference, not a stated requirement: the contract given covers the
      // path, method and body only.
      headers: _sessionStore.authorizationHeader,
      body: {'current_password': currentPassword, 'new_password': newPassword},
      timeout: timeout,
    );
  }
}
