import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Debug-only diagnostics for a request that never completed (Issue #339) —
/// the transports' timeout, socket, client and TLS failures. Without them a
/// failure surfaced only as the screen's message; the API outage of October
/// 2026 could be diagnosed only from outside the app.
///
/// **What is logged:** the transport, the failure kind and the exception's
/// *type* — e.g. `api: network (HandshakeException)`. Nothing else, ever:
/// exception messages are not safe to log (a `SocketException`'s names the
/// host, a `ClientException`'s can carry the URL with its query, a TLS
/// error's can carry certificate details), so no message, URL, query,
/// header, body, token or personal data reaches the log.
///
/// **When:** debug builds only ([kDebugMode], a compile-time constant), so a
/// release build emits nothing.
void logTransportFailure(String transport, String kind, Object error) {
  if (!kDebugMode) return;
  final line = '$transport: $kind (${error.runtimeType})';
  final sink = debugTransportFailureSink;
  if (sink != null) {
    sink(line);
  } else {
    developer.log(line, name: 'aia.transport');
  }
}

/// Where [logTransportFailure] writes in tests; null — the default — writes
/// to `dart:developer`'s log.
@visibleForTesting
void Function(String line)? debugTransportFailureSink;
