import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';

/// A primary tab's header: its title on a white band, with a 1pt rule under
/// it — Courses, the Adult, Junior and Teacher Profiles, and the Teacher
/// Gradebook all draw this one (Issue #368).
///
/// The band is [AppPalette.surface] behind the status bar as well as the
/// title, as the frames draw it; the title is [AppTypography.screenTitle],
/// left on the [AppDimens.screenPadding] gutter and centred in
/// [AppDimens.tabHeaderHeight], inside the [AppDimens.maxContentWidth]
/// column. A title that wraps at larger text grows the band rather than
/// spilling out of it. The rule runs the full width, under the band.
///
/// The tabs led by the brand lockup (`HomeHeader`) and Teacher Schedule's
/// date band are documented exceptions (`SCREEN_PATTERNS.md` §3).
class TabTitleBar extends StatelessWidget {
  const TabTitleBar({required this.title, this.titleColor, super.key});

  final String title;

  /// Null for [AppPalette.textPrimary]. The Teacher tabs pass their own
  /// title ink, `teacherTitle`.
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: palette.surface,
          child: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppDimens.maxContentWidth,
                ),
                // The column's full width, so the title stays on its left
                // gutter however wide the window; at least the band's height,
                // so a one-line title is centred in it and a wrapped one grows
                // it.
                child: SizedBox(
                  width: double.infinity,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppDimens.tabHeaderHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.screenPadding,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: AppTypography.screenTitle.copyWith(
                              color: titleColor ?? palette.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(height: AppDimens.borderWidth, color: palette.divider),
      ],
    );
  }
}
