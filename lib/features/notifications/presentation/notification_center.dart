import 'package:flutter/foundation.dart';

import '../data/http_notification_repository.dart';
import '../domain/app_notification.dart';
import '../domain/notification_failure.dart';
import '../domain/notification_repository.dart';
import 'notification_strings.dart';

/// The signed-in account's in-app notifications (Issue #246) — one shared
/// state for the Notification Center screen and every bell's unread
/// indicator, so they never disagree. Adult students, Junior students and
/// teachers all use it: the endpoints are the same for every role.
///
///  * **List** — the latest [limit] from `GET /me/notifications`; there is
///    no cursor or page in the contract, so no "load more".
///  * **[unreadCount]** — always the server's `unread_count`, never counted
///    from the list (which holds only the latest page).
///  * **[markRead] / [markAllRead]** — optimistic: the row reads as read at
///    once, and is rolled back if the request fails. A second tap while one
///    is in flight does nothing. The server's answer then replaces the
///    optimistic state.
///  * **[load]** — single-flight: a refresh while one runs joins it. A
///    notification marked while a refresh is in flight stays read when the
///    refresh lands.
///  * **[reset]** — on sign-out, or a session that ends: everything is
///    forgotten, and an answer that arrives afterwards is ignored, so the
///    next account never sees this one's notifications.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter({
    NotificationRepository? repository,
    DateTime Function()? clock,
    this.limit = 30,
  }) : _repository = repository ?? HttpNotificationRepository(),
       _clock = clock ?? DateTime.now;

  /// The app's own, shared by every bell and the screen.
  static final NotificationCenter instance = NotificationCenter();

  final NotificationRepository _repository;
  final DateTime Function() _clock;

  /// How many of the latest notifications are asked for.
  final int limit;

  List<AppNotification> _notifications = const [];
  int _unreadCount = 0;
  bool _loading = false;
  bool _hasLoadedOnce = false;
  String? _errorMessage;
  Future<void>? _inFlight;
  final Set<int> _marking = {};
  bool _markingAll = false;
  bool _disposed = false;

  /// Bumped by [reset]: an answer for an older generation is dropped.
  int _generation = 0;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get loading => _loading;
  bool get hasLoadedOnce => _hasLoadedOnce;

  /// The last load's failure, as the screen shows it. Null after a success.
  String? get errorMessage => _errorMessage;

  bool isMarking(int id) => _marking.contains(id);
  bool get markingAll => _markingAll;

  /// Fetches the latest notifications. Joins a load already running.
  Future<void> load() => _inFlight ??= _load().whenComplete(() {
    _inFlight = null;
  });

  /// [load], unless a load has already been made since the last [reset] —
  /// what a bell does when it first appears.
  Future<void> loadIfNeeded() =>
      _hasLoadedOnce || _inFlight != null ? Future.value() : load();

  Future<void> _load() async {
    final generation = _generation;
    // Callers start a load from `initState` — a bell appearing, the screen
    // opening — which is mid-build; telling other listeners then would
    // rebuild them during the build. One microtask later the build is done.
    await Future<void>.value();
    if (generation != _generation) return;
    _loading = true;
    _notify();
    try {
      final feed = await _repository.getNotifications(limit: limit);
      if (generation != _generation) return;
      // A mark still in flight keeps its optimistic read state, and is
      // not counted unread again.
      final now = _clock();
      var pendingUnread = 0;
      final merged = <AppNotification>[];
      for (final n in feed.notifications) {
        final pending = !n.isRead && (_markingAll || _marking.contains(n.id));
        if (pending) pendingUnread++;
        merged.add(pending ? n.copyWith(readAt: now) : n);
      }
      _notifications = merged;
      _unreadCount = _markingAll
          ? 0
          : (feed.unreadCount - pendingUnread).clamp(0, feed.unreadCount);
      _errorMessage = null;
    } on NotificationFailure catch (failure) {
      if (generation != _generation) return;
      _errorMessage = NotificationStrings.messageFor(failure.kind);
    } catch (_) {
      if (generation != _generation) return;
      _errorMessage = NotificationStrings.messageFor(
        NotificationFailureKind.unexpected,
      );
    } finally {
      if (generation == _generation) {
        _loading = false;
        _hasLoadedOnce = true;
        _notify();
      }
    }
  }

  /// Marks notification [id] read. Answers null on success — or when there
  /// is nothing to do: it is already read, unknown here, or already being
  /// marked — and otherwise the copy to show. On failure the row is unread
  /// again; a `404` drops it (the server no longer has it) and reloads.
  Future<String?> markRead(int id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index < 0 || _marking.contains(id) || _markingAll) return null;
    final original = _notifications[index];
    if (original.isRead) return null;

    final generation = _generation;
    _marking.add(id);
    _replace(id, original.copyWith(readAt: _clock()));
    _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
    _notify();

    try {
      final result = await _repository.markRead(id);
      if (generation != _generation) return null;
      _replace(id, result.notification);
      _unreadCount = result.unreadCount;
      return null;
    } on NotificationFailure catch (failure) {
      if (generation != _generation) return null;
      if (failure.kind == NotificationFailureKind.notFound) {
        _notifications = [
          for (final n in _notifications)
            if (n.id != id) n,
        ];
        _marking.remove(id);
        load();
      } else {
        _replace(id, original);
        _unreadCount++;
      }
      return NotificationStrings.messageFor(failure.kind);
    } catch (_) {
      if (generation != _generation) return null;
      _replace(id, original);
      _unreadCount++;
      return NotificationStrings.messageFor(NotificationFailureKind.unexpected);
    } finally {
      if (generation == _generation) {
        _marking.remove(id);
        _notify();
      }
    }
  }

  /// Marks every notification read. Answers null on success, or when one is
  /// already running; otherwise the copy to show, with the list and count
  /// as they were.
  Future<String?> markAllRead() async {
    if (_markingAll) return null;
    final generation = _generation;
    final before = _notifications;
    final countBefore = _unreadCount;

    _markingAll = true;
    final now = _clock();
    _notifications = [
      for (final n in _notifications) n.isRead ? n : n.copyWith(readAt: now),
    ];
    _unreadCount = 0;
    _notify();

    try {
      final result = await _repository.markAllRead();
      if (generation != _generation) return null;
      _unreadCount = result.unreadCount;
      return null;
    } on NotificationFailure catch (failure) {
      if (generation != _generation) return null;
      _notifications = before;
      _unreadCount = countBefore;
      return NotificationStrings.messageFor(failure.kind);
    } catch (_) {
      if (generation != _generation) return null;
      _notifications = before;
      _unreadCount = countBefore;
      return NotificationStrings.messageFor(NotificationFailureKind.unexpected);
    } finally {
      if (generation == _generation) {
        _markingAll = false;
        _notify();
      }
    }
  }

  /// Forgets everything — sign-out, or a session that ends.
  void reset() {
    _generation++;
    _notifications = const [];
    _unreadCount = 0;
    _loading = false;
    _hasLoadedOnce = false;
    _errorMessage = null;
    _inFlight = null;
    _marking.clear();
    _markingAll = false;
    _notify();
  }

  void _replace(int id, AppNotification notification) {
    _notifications = [
      for (final n in _notifications) n.id == id ? notification : n,
    ];
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
