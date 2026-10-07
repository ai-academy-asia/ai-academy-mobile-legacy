import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../home_strings.dart';
import 'home_palette.dart';

/// The dashboard's header: the brand lockup, and the notification control at
/// the trailing edge.
///
/// Home is the only screen with no heading line — the lockup stands in for
/// one, which is why this sits on [AppColors.surface] with a rule under it
/// while the content below scrolls on the page grey.
///
/// The lockup is the icon mark ([HomeIcons.appIcon]) beside the "AI academy"
/// / "Asia" wordmark ([HomeIcons.wordmark]) — the same two Figma exports the
/// splash screen draws. The wordmark is the frame's outlined vector paths,
/// not live text: it is not set in Manrope, so text could only approximate
/// it (Issue #188). The lockup sits at [AppDimens.headerLogoHeight] (40) —
/// the frame's 32 scaled by 1.25 — while the bell stays at the frame's
/// [AppDimens.headerActionSize] (44), so the header keeps the reference's
/// height.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, this.onNotifications, this.onLogoTap});

  /// What the bell does. Null draws it as the reference does but inert —
  /// there is no notifications screen in the app yet.
  final VoidCallback? onNotifications;

  /// What a tap on the brand lockup does — Adult and Junior Home refresh
  /// their data with it (Issue #221). Null leaves the lockup inert, as it
  /// was. Either way it is drawn exactly the same: no ripple or pressed
  /// state, which the frame does not draw.
  final VoidCallback? onLogoTap;

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
              image: onLogoTap == null,
              button: onLogoTap != null,
              child: GestureDetector(
                onTap: onLogoTap,
                behavior: HitTestBehavior.opaque,
                child: const _BrandLockup(),
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

/// Icon mark + two-line wordmark, both drawn at [AppDimens.headerLogoHeight]
/// (40) and sharing a bottom edge.
///
/// That one height reproduces the reference's proportions with the exports
/// as they are: the wordmark's ink fills 29.9–96.4 of its 97-unit box, so it
/// inks 27.4 tall with "Asia" sitting on the mark's baseline — the reference
/// draws 0.675 × the mark (27.0 at 40) on the same baseline. [_gap] makes the
/// ink-to-ink gap the reference's 5.3 beside a 32pt mark, scaled to 6.6.
class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  /// The box between the two exports: 6.6 of clear space less the mark's
  /// own 1.65 of transparent margin and the wordmark's 1.93.
  static const double _gap = 3;

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
          const SizedBox(width: _gap),
          SvgPicture.asset(
            HomeIcons.wordmark,
            height: AppDimens.headerLogoHeight,
            // The lockup's own [Semantics] announces it.
            excludeFromSemantics: true,
          ),
        ],
      ),
    );
  }
}

/// The circular bell: a white circle with a hairline border, the same control
/// shape as the profile header's edit button, at the frame's
/// [AppDimens.headerActionSize] (44) with its 20pt glyph.
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
