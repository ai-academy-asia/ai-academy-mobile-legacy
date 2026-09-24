import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../home_strings.dart';

/// The dashboard's header: the brand lockup, and the notification control at
/// the trailing edge.
///
/// Home is the only screen with no heading line — the lockup stands in for
/// one, which is why this sits on [AppColors.surface] with a rule under it
/// while the content below scrolls on the page grey.
///
/// The lockup is the icon mark ([HomeIcons.appIcon]) beside "AI academy" /
/// "Asia" drawn as live text ([AppTypography.homeLogoWordmark]) — the same
/// icon-plus-text split the splash screen uses, in place of the one flattened
/// `ai_academy_logo.png` export this used to show. Both pieces are sized so
/// the whole lockup still sits at [AppDimens.headerLogoHeight] (32), same as
/// the old image did — the header's own height, padding and the bell's
/// position are unchanged.
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
              child: const _BrandLockup(),
            ),
            const Spacer(),
            _NotificationButton(onTap: onNotifications),
          ],
        ),
      ),
    );
  }
}

/// Icon mark + two-line wordmark, both held to
/// [AppDimens.headerLogoHeight] (32) so the pair reads as one lockup at the
/// same footprint the single flattened logo image used to occupy.
class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimens.headerLogoHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            HomeIcons.appIcon,
            height: AppDimens.headerLogoHeight,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),
          Text(
            '${HomeStrings.wordmarkLine1}\n${HomeStrings.wordmarkLine2}',
            style: AppTypography.homeLogoWordmark,
          ),
        ],
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
