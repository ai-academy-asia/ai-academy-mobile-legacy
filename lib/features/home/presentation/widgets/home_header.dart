import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../home_strings.dart';

/// The dashboard's header: the brand lockup, and the notification control at
/// the trailing edge.
///
/// Home is the only screen with no heading line — the lockup stands in for
/// one, which is why this sits on [AppColors.surface] with a rule under it
/// while the content below scrolls on the page grey.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, this.onNotifications});

  /// What the bell does. Null draws it as the reference does but inert —
  /// there is no notifications screen in the app yet.
  final VoidCallback? onNotifications;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.screenPadding,
          vertical: 10,
        ),
        child: Row(
          children: [
            Semantics(
              label: HomeStrings.logo,
              image: true,
              child: Image.asset(
                HomeIcons.logo,
                height: AppDimens.headerLogoHeight,
                fit: BoxFit.contain,
              ),
            ),
            const Spacer(),
            _NotificationButton(onTap: onNotifications),
          ],
        ),
      ),
    );
  }
}

/// The circular bell. Same 44pt circle, white fill and hairline border the
/// profile header's edit control uses — one control shape, drawn twice.
class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: HomeStrings.notifications,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(
          side: BorderSide(
            color: AppColors.border,
            width: AppDimens.borderWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: AppDimens.headerActionSize,
            height: AppDimens.headerActionSize,
            child: Center(
              child: SvgPicture.asset(
                HomeIcons.notification,
                width: 20,
                height: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
