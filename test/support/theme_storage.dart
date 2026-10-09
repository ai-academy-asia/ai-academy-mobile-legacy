import 'dart:async';

import 'package:aia_mobile/core/theme/app_theme_controller.dart';
import 'package:aia_mobile/core/theme/theme_preference.dart';

/// Each account's theme preference in memory (Issue #286), recording every
/// write as `account=value`. [legacy] stands in for the device-wide value
/// stored before per-account keys.
class MemoryThemeStorage implements ThemePreferencePersistence {
  MemoryThemeStorage([Map<String, String>? values, this.legacy])
    : values = {...?values};

  final Map<String, String> values;
  String? legacy;
  final List<String> writes = [];
  final List<String> reads = [];

  /// When set, each read waits for it — so a test can hold one in flight.
  Completer<void>? gate;

  @override
  Future<String?> read(String account) async {
    reads.add(account);
    await gate?.future;
    return values[account];
  }

  @override
  Future<void> write(String account, String value) async {
    writes.add('$account=$value');
    values[account] = value;
  }

  @override
  Future<void> deleteLegacy() async => legacy = null;
}

/// Storage that fails every read, write and delete.
class FailingThemeStorage implements ThemePreferencePersistence {
  @override
  Future<String?> read(String account) =>
      Future.error(StateError('storage unavailable'));

  @override
  Future<void> write(String account, String value) =>
      Future.error(StateError('storage unavailable'));

  @override
  Future<void> deleteLegacy() =>
      Future.error(StateError('storage unavailable'));
}

/// A controller on [storage], with [account] signed in and its preference
/// applied — as `main()` leaves it.
Future<AppThemeController> themeFor(
  ThemePreferencePersistence storage, {
  String? account = '9',
}) async {
  final controller = AppThemeController();
  await controller.attach(storage);
  await controller.activateAccount(account);
  return controller;
}
