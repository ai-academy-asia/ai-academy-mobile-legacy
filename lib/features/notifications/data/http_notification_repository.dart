import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../auth/data/authenticated_client.dart';
import '../../auth/domain/auth_session_store.dart';
import '../domain/app_notification.dart';
import '../domain/notification_failure.dart';
import '../domain/notification_repository.dart';

/// The in-app notification endpoints (Issue #246), as verified live in
/// Phase 0 with an adult student account:
///
///     GET  /me/notifications?limit=30
///       -> {"notifications": [{id, title, body, kind, created_at,
///           read_at|null, data|null}, ...], "unread_count": n}
///     POST /me/notifications/{id}/read      (no body)
///       -> the notification, read_at set, and "unread_count"
///          404 {"error": "notification_not_found"} for an unknown id
///     POST /me/notifications/read-all       (no body)
///       -> {"unread_count": 0, "updated": n}
///
/// Students (Adult and Junior) and teachers use the same endpoints with
/// their own token. Sent through [AuthenticatedClient.instance], so an
/// expired access token is renewed and the request retried once; a 401
/// that survives that ends the session here too, as every authenticated
/// repository does.
///
/// **Malformed items are skipped, not fatal.** One item that does not match
/// the contract leaves the rest of the list readable; it is reported with
/// [debugPrint] (its index and the reason — never its title or body) and
/// counted in [NotificationFeed.skipped], so the gap is visible rather than
/// silent. The envelope itself — the `notifications` array and
/// `unread_count` — is required: without it the response is the server's
/// fault.
///
/// Whether mark-one's `unread_count` sits beside the notification's own
/// fields or the notification is wrapped in a `notification` key was not
/// pinned down in Phase 0, so both are read.
class HttpNotificationRepository implements NotificationRepository {
  HttpNotificationRepository({
    http.Client? client,
    Uri? baseUrl,
    AuthSessionStore? sessionStore,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? AuthenticatedClient.instance,
       _baseUrl = baseUrl ?? Uri.parse(defaultBaseUrl),
       _sessionStore = sessionStore ?? AuthSessionStore.instance;

  static const String defaultBaseUrl = 'https://api.ai-academy.asia';

  final http.Client _client;
  final Uri _baseUrl;
  final AuthSessionStore _sessionStore;
  final Duration timeout;

  @override
  Future<NotificationFeed> getNotifications({int limit = 30}) async {
    final body = await _send(
      (headers) => getRaw(
        client: _client,
        url: _baseUrl.replace(
          path: '/me/notifications',
          queryParameters: {'limit': '$limit'},
        ),
        headers: headers,
        timeout: timeout,
      ),
    );
    final decoded = _object(body);

    final items = decoded['notifications'];
    if (items is! List) {
      throw const NotificationFailure(
        NotificationFailureKind.server,
        detail: 'notifications: expected a list',
      );
    }

    final notifications = <AppNotification>[];
    var skipped = 0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final notification = item is Map<String, dynamic>
          ? notificationFrom(item)
          : null;
      if (notification == null) {
        skipped++;
        debugPrint(
          'HttpNotificationRepository: skipped notifications[$i] — it does '
          'not match the contract (${_reasonFor(item)})',
        );
        continue;
      }
      notifications.add(notification);
    }

    return NotificationFeed(
      notifications: notifications,
      unreadCount: _unreadCount(decoded),
      skipped: skipped,
    );
  }

  @override
  Future<NotificationReadResult> markRead(int id) async {
    final body = await _send(
      (headers) => postWithoutBody(
        client: _client,
        url: _baseUrl.resolve('/me/notifications/$id/read'),
        headers: headers,
        timeout: timeout,
      ),
    );
    final decoded = _object(body);
    final wrapped = decoded['notification'];
    final notification = notificationFrom(
      wrapped is Map<String, dynamic> ? wrapped : decoded,
    );
    if (notification == null) {
      throw NotificationFailure(
        NotificationFailureKind.server,
        detail:
            'read: the notification does not match the contract '
            '(${_reasonFor(wrapped ?? decoded)})',
      );
    }
    return NotificationReadResult(
      notification: notification,
      unreadCount: _unreadCount(decoded),
    );
  }

  @override
  Future<NotificationReadAllResult> markAllRead() async {
    final body = await _send(
      (headers) => postWithoutBody(
        client: _client,
        url: _baseUrl.resolve('/me/notifications/read-all'),
        headers: headers,
        timeout: timeout,
      ),
    );
    final decoded = _object(body);
    final updated = decoded['updated'];
    if (updated is! int) {
      throw const NotificationFailure(
        NotificationFailureKind.server,
        detail: 'read-all: updated is not an integer',
      );
    }
    return NotificationReadAllResult(
      updated: updated,
      unreadCount: _unreadCount(decoded),
    );
  }

  /// Sends an authenticated request and answers its body, or throws the
  /// [NotificationFailure] its status means.
  Future<String> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    if (!_sessionStore.isSignedIn || _sessionStore.isExpired()) {
      throw const NotificationFailure(
        NotificationFailureKind.sessionExpired,
        detail: 'no usable session',
      );
    }

    final http.Response response;
    try {
      response = await request(_sessionStore.authorizationHeader);
    } on ApiFailure catch (failure) {
      // The transport throws only for a request that never completed.
      throw NotificationFailure(
        NotificationFailureKind.network,
        detail: failure.detail,
      );
    }

    final status = response.statusCode;
    if (status >= 200 && status < 300) return response.body;
    if (status == 401) {
      // A token the backend refused even after renewal: forget it.
      _sessionStore.clear();
      throw const NotificationFailure(
        NotificationFailureKind.sessionExpired,
        detail: 'HTTP 401',
      );
    }
    if (status == 404) {
      throw NotificationFailure(
        NotificationFailureKind.notFound,
        detail: 'HTTP 404 ${_errorCode(response.body) ?? ''}'.trim(),
      );
    }
    throw NotificationFailure(
      status >= 500
          ? NotificationFailureKind.server
          : NotificationFailureKind.unexpected,
      detail: 'HTTP $status',
    );
  }
}

/// One notification object, or null when it does not match the verified
/// contract. Public so the mapping can be tested on its own.
AppNotification? notificationFrom(Map<String, dynamic> json) {
  final id = json['id'];
  final title = json['title'];
  final body = json['body'];
  final kind = json['kind'];
  final createdAt = json['created_at'];
  final readAt = json['read_at'];
  final data = json['data'];

  if (id is! int || title is! String || body is! String || kind is! String) {
    return null;
  }
  final created = createdAt is String ? DateTime.tryParse(createdAt) : null;
  if (created == null) return null;

  DateTime? read;
  if (readAt != null) {
    read = readAt is String ? DateTime.tryParse(readAt) : null;
    if (read == null) return null;
  }
  if (data != null && data is! Map<String, dynamic>) return null;

  return AppNotification(
    id: id,
    title: title,
    body: body,
    kind: kind,
    createdAt: created,
    readAt: read,
    data: data as Map<String, dynamic>?,
  );
}

Map<String, dynamic> _object(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (e) {
    throw NotificationFailure(
      NotificationFailureKind.server,
      detail: 'malformed JSON: ${e.message}',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw const NotificationFailure(
      NotificationFailureKind.server,
      detail: 'response was not a JSON object',
    );
  }
  return decoded;
}

int _unreadCount(Map<String, dynamic> json) {
  final count = json['unread_count'];
  if (count is! int || count < 0) {
    throw NotificationFailure(
      NotificationFailureKind.server,
      detail: 'unread_count: expected a non-negative integer, got $count',
    );
  }
  return count;
}

/// Why [item] was not read — field names only, never their values.
String _reasonFor(Object? item) {
  if (item is! Map<String, dynamic>) return 'not an object';
  const required = ['id', 'title', 'body', 'kind', 'created_at'];
  final missing = [
    for (final key in required)
      if (!item.containsKey(key)) key,
  ];
  if (missing.isNotEmpty) return 'missing ${missing.join(', ')}';
  return 'a field has the wrong type or format';
}

String? _errorCode(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic> && decoded['error'] is String) {
      return decoded['error'] as String;
    }
  } on FormatException {
    return null;
  }
  return null;
}
