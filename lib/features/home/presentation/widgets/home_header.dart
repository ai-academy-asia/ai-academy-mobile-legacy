import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../home_strings.dart';
import 'home_palette.dart';

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
/// the whole lockup sits at [AppDimens.headerLogoHeight] (40) — the frame's
/// 32 scaled by 1.25 (Issue #188). The bell grows from the frame's 44 to
/// [AppDimens.headerActionSize] (48) with it, so the header is 4pt taller
/// than the reference; its padding is unchanged.
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
        // 10 over the bell and 9 under it: the reference's rule sits 63 below
        // the status bar, not 64.
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          10,
          AppDimens.screenPadding,
          9,
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
/// [AppDimens.headerLogoHeight] (40) so the pair reads as one lockup. The
/// gap and the wordmark's nudge are the frame's (3.5 and 4 beside a 32pt
/// mark) scaled by the same 40 / 32 as the mark itself.
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
          const SizedBox(width: 4.4),
          // The reference sets the two lines below the mark's centre —
          // "Asia" sits on the mark's baseline — so the block is nudged down
          // rather than centred. A paint-time offset, so the lockup keeps
          // its 40pt footprint.
          Transform.translate(
            offset: const Offset(0, 5),
            child: Text(
              '${HomeStrings.wordmarkLine1}\n${HomeStrings.wordmarkLine2}',
              style: AppTypography.homeLogoWordmark,
            ),
          ),
        ],
      ),
    );
  }
}

/// The circular bell: a white circle with a hairline border, the same control
/// shape as the profile header's edit button, at
/// [AppDimens.headerActionSize]. The glyph is the frame's 20 inside 44,
/// scaled with the circle to 22 inside 48.
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
            color: HomePalette.border,
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
                width: 22,
                height: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
