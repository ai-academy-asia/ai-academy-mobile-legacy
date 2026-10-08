import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../home/presentation/home_strings.dart';
import '../domain/app_notification.dart';
import 'notification_center.dart';
import 'notification_detail_screen.dart';
import 'notification_header.dart';
import 'notification_strings.dart';

/// The Notification Center — the Figma "Notification" frame (Issue #246):
/// the latest notifications, newest first, under a fixed header. Opened from
/// every bell — Adult Home, Junior Home and Progress, Teacher Home and
/// Schedule — through [NotificationScreen.open]; the same screen for every
/// role, on the shared [NotificationCenter].
///
/// A row reads unread — blue glyph, dark title, grey body, blue dot — while
/// its `read_at` is null, and all grey once read. Tapping any row opens
/// [NotificationDetailScreen] with its full text (Issue #248); an unread row
/// is marked read on the way. The detail is the same for every `kind` — the
/// contract carries no destination, so there are no deep links. Pull down to
/// refresh.
///
/// One glyph for every `kind`: the frame's Money icon illustrates a payment
/// notice, and no payment kind is verified, so per-kind icons wait on a
/// product decision.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key, this.center});

  /// Defaults to [NotificationCenter.instance]. Injected in tests.
  final NotificationCenter? center;

  /// Pushes the screen over [context]'s navigator — what every bell does.
  static Future<void> open(
    BuildContext context, {
    NotificationCenter? center,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => NotificationScreen(center: center)),
  );

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late final NotificationCenter _center =
      widget.center ?? NotificationCenter.instance;

  @override
  void initState() {
    super.initState();
    // Fresh on every open: the bell's count may be minutes old.
    _center.load();
  }

  Future<void> _refresh() async {
    await _center.load();
    final message = _center.errorMessage;
    if (message != null && mounted && _center.notifications.isNotEmpty) {
      _showError(message);
    }
  }

  /// Opens the detail at once, and marks an unread row read alongside —
  /// never waiting on it: a failed mark rolls the row back and says why
  /// (the SnackBar shows over the detail), but never keeps the message from
  /// being read. A read row sends nothing.
  void _open(AppNotification notification) {
    if (!notification.isRead) _markRead(notification);
    NotificationDetailScreen.open(context, notification);
  }

  Future<void> _markRead(AppNotification notification) async {
    final message = await _center.markRead(notification.id);
    if (message != null && mounted) _showError(message);
  }

  void _showError(String message) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: context.palette.surface,
      ),
      child: Scaffold(
        backgroundColor: context.palette.surface,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NotificationHeader(),
              Expanded(
                child: ListenableBuilder(
                  listenable: _center,
                  builder: (context, _) => _body(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final notifications = _center.notifications;
    if (notifications.isEmpty) {
      if (!_center.hasLoadedOnce || _center.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      final message = _center.errorMessage;
      if (message != null) {
        return _Message(
          message: message,
          action: TextButton(
            onPressed: _center.load,
            child: const Text(NotificationStrings.retry),
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: const _Message(message: NotificationStrings.empty),
            ),
          ),
        ),
      );
    }

    final now = DateTime.now();
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: _headerToList,
          bottom: MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return NotificationTile(
            notification: notification,
            age: NotificationStrings.age(notification.createdAt, now),
            onTap: () => _open(notification),
          );
        },
      ),
    );
  }
}

/// One notification row: glyph, title over body, age, and the unread dot,
/// closed by a full-width rule. 72 tall including the rule; the title and
/// body each hold one line, ending in an ellipsis.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    required this.notification,
    required this.age,
    this.onTap,
    super.key,
  });

  final AppNotification notification;

  /// The age as drawn, e.g. `1d` — see `NotificationStrings.age`.
  final String age;

  /// Opens the notification — see `NotificationScreen`. Null draws a row
  /// that does nothing.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final palette = context.palette;
    final row = SizedBox(
      height: _rowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.screenPadding,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: _iconTop),
              child: SvgPicture.asset(
                HomeIcons.notification,
                width: _iconSize,
                height: _iconSize,
                colorFilter: ColorFilter.mode(
                  unread ? palette.accent : palette.textInactive,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(width: _iconToText),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: _textTop),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: _rowTitleStyle.copyWith(
                        color: unread
                            ? palette.textPrimary
                            : palette.textInactive,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: _titleToBody),
                    Text(
                      notification.body,
                      style: _bodyStyle.copyWith(
                        color: unread
                            ? palette.textSecondary
                            : palette.textInactive,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: _iconToText),
            SizedBox(
              height: _rowHeight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    age,
                    style: _ageStyle.copyWith(color: palette.textSecondary),
                  ),
                  const SizedBox(width: _ageToDot),
                  SizedBox.square(
                    dimension: _dotSize,
                    child: unread
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: palette.accent,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      button: onTap != null,
      label: [
        if (unread) _unreadLabel,
        notification.title,
        notification.body,
        age,
      ].join(', '),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(onTap: onTap, child: row),
          // Full width: a childless box in a Column would size to nothing.
          SizedBox(
            width: double.infinity,
            height: AppDimens.borderWidth,
            child: ColoredBox(color: palette.divider),
          ),
        ],
      ),
    );
  }
}

/// The empty and failed states: one centred line, and a retry when there is
/// something to retry.
class _Message extends StatelessWidget {
  const _Message({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTypography.statLabel.copyWith(
                color: context.palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (action case final action?) ...[
              const SizedBox(height: AppDimens.fieldGap),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

// --- Measured off the Figma "Notification" frame at 1:1 (393 wide, a 44pt
// status-bar inset) -----------------------------------------------------------

/// The header ends at the circle's bottom (y 96); the first row starts at
/// y 108.
const double _headerToList = 12;

/// A row's content; with its 1pt rule, 72.
const double _rowHeight = 71;

const double _iconSize = 24;
const double _iconTop = 12;
const double _iconToText = 12;
const double _textTop = 12;
const double _titleToBody = 4;
const double _ageToDot = 13;
const double _dotSize = 8;

/// Read by a screen reader before an unread row's title.
const String _unreadLabel = 'Шинэ';

const TextStyle _rowTitleStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 16,
  height: 24 / 16,
  fontWeight: FontWeight.w700,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _bodyStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w400,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _ageStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w400,
  leadingDistribution: TextLeadingDistribution.even,
);
