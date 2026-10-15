import 'dart:async';

import 'package:flutter/material.dart';

import 'push_messaging.dart';
import 'push_notifications.dart';

/// Draws a Profile's own switch.
typedef NotificationSwitchBuilder =
    Widget Function(
      BuildContext context,
      bool value,
      ValueChanged<bool>? onChanged,
    );

/// The Profile "Notification" switch (Issue #429): the device's OS
/// notification permission for this app, not a server-side preference — none
/// exists (#291).
///
/// With push on, it is on when the permission is granted and off otherwise,
/// read when Profile opens and again on every resume ([PushNotifications]
/// re-reads it there). A tap opens this app's notification settings in the
/// OS; the switch never pretends to change the permission itself. With push
/// off — no Firebase configuration, iOS today — it is inert and off.
///
/// Each Profile draws its own switch through [builder]; this decides only
/// its value and its tap.
class NotificationPermissionSwitch extends StatefulWidget {
  const NotificationPermissionSwitch({
    required this.builder,
    this.push,
    super.key,
  });

  final NotificationSwitchBuilder builder;

  /// Defaults to [PushNotifications.instance]. Injected in tests.
  final PushNotifications? push;

  @override
  State<NotificationPermissionSwitch> createState() =>
      _NotificationPermissionSwitchState();
}

class _NotificationPermissionSwitchState
    extends State<NotificationPermissionSwitch> {
  PushNotifications get _push => widget.push ?? PushNotifications.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_push.refreshPermission());
  }

  @override
  Widget build(BuildContext context) {
    final push = _push;
    return ValueListenableBuilder<PushPermission?>(
      valueListenable: push.permissionState,
      builder: (context, permission, _) => widget.builder(
        context,
        push.enabled && permission == PushPermission.granted,
        push.enabled ? (_) => unawaited(push.openNotificationSettings()) : null,
      ),
    );
  }
}
