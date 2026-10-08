import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../home/presentation/home_strings.dart';
import '../../home/presentation/widgets/home_palette.dart';
import '../domain/app_notification.dart';
import 'notification_header.dart';
import 'notification_strings.dart';

/// One notification in full (Issue #248) — what a Notification Center row
/// opens, for every `kind`. The row holds one line of title and one of body;
/// this holds all of both, scrolling when they run long.
///
/// No Figma frame draws it: by product decision it is the Notification
/// Center's own header and language — the row's glyph and accent, its title
/// and body type a step larger, a [HomePalette.headerRule] rule — with
/// nothing new. Built from the [AppNotification] the list already loaded:
/// the contract has no detail endpoint, and nothing here changes. Read state
/// stays with `NotificationCenter`; `kind` and `data` are not read — no deep
/// links are defined.
class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({required this.notification, super.key});

  final AppNotification notification;

  /// Pushes the detail for [notification] over [context]'s navigator.
  static Future<void> open(
    BuildContext context,
    AppNotification notification,
  ) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NotificationDetailScreen(notification: notification),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NotificationHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    _headerToContent,
                    AppDimens.screenPadding,
                    _contentBottom + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SvgPicture.asset(
                        HomeIcons.notification,
                        width: _iconSize,
                        height: _iconSize,
                        colorFilter: const ColorFilter.mode(
                          HomePalette.accent,
                          BlendMode.srcIn,
                        ),
                        excludeFromSemantics: true,
                      ),
                      const SizedBox(height: _iconToTitle),
                      Semantics(
                        header: true,
                        child: Text(notification.title, style: _titleStyle),
                      ),
                      const SizedBox(height: _titleToDate),
                      Text(
                        NotificationStrings.sentAt(notification.createdAt),
                        style: _dateStyle,
                      ),
                      const SizedBox(height: _dateToRule),
                      // Full width: a childless box in a Column would size
                      // to nothing.
                      const SizedBox(
                        width: double.infinity,
                        height: AppDimens.borderWidth,
                        child: ColoredBox(color: HomePalette.headerRule),
                      ),
                      const SizedBox(height: _ruleToBody),
                      Text(notification.body, style: _bodyStyle),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- No frame: the Notification Center's own spacing, a step roomier ------

/// As the list's first row sits under the header, doubled for a page.
const double _headerToContent = 24;
const double _contentBottom = 24;

/// The row's glyph, a third larger as the page's one mark.
const double _iconSize = 32;
const double _iconToTitle = 16;
const double _titleToDate = 4;
const double _dateToRule = 16;
const double _ruleToBody = 16;

/// The row's title (16/24 w700), a step up.
const TextStyle _titleStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 20,
  height: 28 / 20,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The row's age type.
const TextStyle _dateStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w400,
  color: AppColors.textSecondary,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The row's body (14/20), a step up and in the primary ink: here it is the
/// thing being read.
const TextStyle _bodyStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 16,
  height: 24 / 16,
  fontWeight: FontWeight.w400,
  color: AppColors.textPrimary,
  leadingDistribution: TextLeadingDistribution.even,
);
