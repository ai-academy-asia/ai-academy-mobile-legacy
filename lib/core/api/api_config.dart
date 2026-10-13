import 'package:flutter/foundation.dart';

/// The API every HTTP repository talks to, decided once (Issue #388).
///
/// **Production by default.** A **debug** build may point at another server
/// — a backend on this Mac, or on the LAN — with
///
///     flutter run --dart-define=AIA_API_BASE_URL=http://localhost:8000
///
/// (see `DATA_AND_API.md` §3.1). A **release** (or profile) build ignores the
/// define entirely and always uses [productionUrl]: the check is
/// [kDebugMode], a compile-time constant.
///
/// A value that is not a bare `http(s)://host[:port]` origin stops the app
/// at startup ([InvalidApiBaseUrl]) instead of quietly falling back to
/// production — someone who asked for a local server must never land on
/// production by mistake.
abstract final class ApiConfig {
  /// The contract host.
  static const String productionUrl = 'https://api.ai-academy.asia';

  /// The `--dart-define` that overrides it, in debug builds only.
  static const String defineName = 'AIA_API_BASE_URL';

  static const String _defined = String.fromEnvironment(defineName);

  /// This build's API, resolved on first use; `main` reads it before
  /// anything else, so an invalid override fails before any request.
  static final ApiBaseUrl current = resolve(
    _defined,
    allowOverride: kDebugMode,
  );

  /// Where every HTTP repository sends its requests unless a test injects
  /// another.
  static Uri get baseUrl => current.uri;

  /// [defined] as this build may use it: ignored unless [allowOverride];
  /// empty or the production URL itself means production; anything else
  /// must be a bare `http(s)://host[:port]` origin.
  @visibleForTesting
  static ApiBaseUrl resolve(String defined, {required bool allowOverride}) {
    final production = ApiBaseUrl._(
      Uri.parse(productionUrl),
      isOverride: false,
    );
    final value = defined.trim();
    if (!allowOverride || value.isEmpty) return production;

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isAbsolute) {
      throw const InvalidApiBaseUrl('not an absolute URL');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const InvalidApiBaseUrl('the scheme must be http or https');
    }
    if (uri.host.isEmpty) throw const InvalidApiBaseUrl('no host');
    // Credentials in a URL would be shown and logged: refused outright.
    if (uri.userInfo.isNotEmpty) {
      throw const InvalidApiBaseUrl('credentials are not allowed in the URL');
    }
    if (uri.hasQuery || uri.hasFragment) {
      throw const InvalidApiBaseUrl('no query or fragment is allowed');
    }
    // Every repository resolves absolute paths (`/me/...`) against it, so a
    // path here would be silently dropped.
    if (uri.path.isNotEmpty && uri.path != '/') {
      throw const InvalidApiBaseUrl('no path is allowed — origin only');
    }

    final origin = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    );
    if (origin == production.uri) return production;
    return ApiBaseUrl._(origin, isOverride: true);
  }
}

/// A resolved API location.
class ApiBaseUrl {
  const ApiBaseUrl._(this.uri, {required this.isOverride});

  /// The origin, `scheme://host[:port]`, with no path.
  final Uri uri;

  /// A debug build pointed away from production.
  final bool isOverride;

  /// `host[:port]` — what the debug marker shows. No scheme, path or
  /// credentials (there are none to show: [ApiConfig.resolve] refuses them).
  String get label => uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
}

/// `AIA_API_BASE_URL` was set to something [ApiConfig.resolve] refuses.
///
/// The message names the rule broken, never the value — which could carry
/// a credential someone pasted by mistake.
class InvalidApiBaseUrl implements Exception {
  const InvalidApiBaseUrl(this.reason);

  final String reason;

  @override
  String toString() =>
      'InvalidApiBaseUrl: ${ApiConfig.defineName} is invalid — $reason. '
      'Use an origin such as http://localhost:8000, or leave it unset for '
      'production.';
}
