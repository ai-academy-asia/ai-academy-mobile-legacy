import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../profile_strings.dart';

/// The measured parts the profile frames are drawn from — the Figma "Adults -
/// Profile" frame and the Teacher "Profile" frame share them at 1:1 (393
/// wide, a 44pt status-bar inset): the white title band and its rule, the
/// avatar hero, the caption bands, the settings rows, the MN/EN control, the
/// switch and the log-out pill.
///
/// Moved here unchanged from `ProfileScreen` (Issue #243) so the Adult and
/// Teacher profiles draw the same parts rather than two copies of them.
/// `JuniorProfileScreen` keeps its own, measured off the junior frame.
abstract final class ProfileMetrics {
  /// The white header under the status bar, down to its rule.
  static const double headerHeight = 63;

  /// The hero band: the avatar 32 below the rule above it, 31 above the one
  /// under it.
  static const double avatarSize = 72;
  static const double heroTop = 32;
  static const double heroBottom = 31;

  /// A settings row.
  static const double rowHeight = 55;

  /// The contact rows, which the frames run without rules between them.
  static const double contactRowHeight = 56;

  /// Log out 32 below the last contact row, and 32 of page under it.
  static const double contactToLogOut = 32;
  static const double bottomPadding = 32;
}

/// The caption band above each group — the caption's line 16 below the
/// band's top.
const double _captionBand = 40;
const double _captionTop = 16;

/// A row's icon box and its gap to the label — 8 on these frames, a point
/// tighter than the junior frame's 9.
const double _rowIcon = 20;
const double _iconToLabel = 8;

/// The MN/EN control — see [ProfileLanguageToggle].
const double _toggleHeight = 35;
const double _toggleInset = 4;
const double _capsuleWidth = 44;
const double _otherSegmentWidth = 41;
const double _toggleRadius = 12;
const double _capsuleRadius = 8;

/// Caps [child] at [AppDimens.maxContentWidth], centred, as every other
/// screen does on a wide window.
Widget profileConstrained(Widget child) => Align(
  alignment: Alignment.topCenter,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
    child: child,
  ),
);

/// The white title band — white behind the status bar as well as the title,
/// as the frames draw it. The rule under it is a separate [ProfileRule].
class ProfileTitleBar extends StatelessWidget {
  const ProfileTitleBar({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.palette.surface,
      child: SafeArea(
        bottom: false,
        child: profileConstrained(
          SizedBox(
            height: ProfileMetrics.headerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.screenPadding,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: profileHeadingStyle.copyWith(
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The avatar: a placeholder disc. No confirmed response carries an avatar
/// URL, so the frames' photos are design content, never app data.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ProfileMetrics.avatarSize,
      height: ProfileMetrics.avatarSize,
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        shape: BoxShape.circle,
        border: Border.all(color: context.palette.outline),
      ),
      child: Icon(Icons.person, size: 36, color: context.palette.textSecondary),
    );
  }
}

/// A grey caption naming the group under it.
class ProfileCaption extends StatelessWidget {
  const ProfileCaption(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _captionBand,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          _captionTop,
          AppDimens.screenPadding,
          0,
        ),
        child: Text(
          label,
          style: captionStyle.copyWith(color: context.palette.textSecondary),
        ),
      ),
    );
  }
}

/// Rows with a rule after each one, the last closing the group off. No rule
/// between a caption and its own first row: the frames run the caption
/// straight into the group it names.
class ProfileGroup extends StatelessWidget {
  const ProfileGroup({required this.rows, super.key});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in rows) ...[row, const ProfileRule()],
      ],
    );
  }
}

/// One row: icon, label, and an optional trailing control. No chevron — the
/// frames draw none on any row, including the ones that will eventually open
/// a screen of their own.
class ProfileRow extends StatelessWidget {
  const ProfileRow({
    required this.icon,
    required this.label,
    super.key,
    this.trailing,
    this.onTap,
    this.height = ProfileMetrics.rowHeight,
  });

  /// Path to the row's exported SVG — see [ProfileIcons].
  final String icon;

  final String label;

  /// The row's trailing control, where the row has one.
  final Widget? trailing;

  /// Pushes the row's destination screen. `null` for every row with no
  /// destination yet.
  final VoidCallback? onTap;

  final double height;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.screenPadding,
        ),
        child: Row(
          children: [
            AppSvgIcon(icon, size: _rowIcon),
            const SizedBox(width: _iconToLabel),
            Expanded(
              child: Text(
                label,
                style: rowLabelStyle.copyWith(
                  color: context.palette.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing case final trailing?) ...[
              const SizedBox(width: 12),
              trailing,
            ],
          ],
        ),
      ),
    );

    final onTap = this.onTap;
    if (onTap == null) return row;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// The MN/EN control: a blue rounded rectangle with the selected language on
/// a white capsule inset 4 inside it — 93 x 35 overall, the capsule 44 x 27,
/// as on the junior frame. The halves are not equal: the capsule is 44 wide
/// and the other language centres in the 41 left over.
///
/// A null [onChanged] draws it inert: it shows [english] and ignores taps —
/// for a screen with no locale mechanism to hand a choice to.
class ProfileLanguageToggle extends StatelessWidget {
  const ProfileLanguageToggle({
    required this.english,
    required this.onChanged,
    super.key,
  });

  final bool english;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return Container(
      height: _toggleHeight,
      padding: const EdgeInsets.all(_toggleInset),
      decoration: BoxDecoration(
        color: context.palette.accent,
        borderRadius: BorderRadius.circular(_toggleRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            label: ProfileStrings.languageMn,
            selected: !english,
            onTap: onChanged == null ? null : () => onChanged(false),
          ),
          _Segment(
            label: ProfileStrings.languageEn,
            selected: english,
            onTap: onChanged == null ? null : () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: selected ? _capsuleWidth : _otherSegmentWidth,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? context.palette.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(_capsuleRadius),
          ),
          child: Text(
            label,
            style: _segmentStyle.copyWith(
              color: selected
                  ? context.palette.linkInk
                  : context.palette.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The frames' switch: a 44 x 24 grey track with a white knob — smaller than
/// Flutter's own [Switch], so drawn here rather than scaled.
///
/// A null [onChanged] draws it inert: it shows [value] and ignores taps — for
/// a setting with no endpoint behind it.
class ProfileSwitch extends StatelessWidget {
  const ProfileSwitch({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final palette = context.palette;
    return Semantics(
      toggled: value,
      // Only an inert switch says so; an active one is drawn as it always was.
      enabled: onChanged == null ? false : null,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 24,
          padding: const EdgeInsets.all(2),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? palette.accent : palette.outline,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: palette.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The full-width outlined pill.
class ProfileLogOutButton extends StatelessWidget {
  const ProfileLogOutButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppDimens.buttonRadius));
    return Semantics(
      button: true,
      label: ProfileStrings.logOut,
      excludeSemantics: true,
      child: Material(
        color: context.palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: context.palette.outline),
        ),
        child: InkWell(
          onTap: onPressed,
          customBorder: const RoundedRectangleBorder(borderRadius: radius),
          child: SizedBox(
            height: AppDimens.buttonHeight,
            child: Center(
              child: Text(
                ProfileStrings.logOut,
                style: _logOutStyle.copyWith(
                  color: context.palette.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileRule extends StatelessWidget {
  const ProfileRule({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimens.borderWidth,
      color: context.palette.divider,
    );
  }
}

// --- Colour and type ---------------------------------------------------------
//
// Sampled and measured off the frames at 1:1; sizes from cap heights
// (Manrope's cap height is 0.72 em). The colours are the same ones
// `JuniorProfileScreen` sampled off the junior frame.
//
// The parts above draw every colour from `context.palette` (Dark Mode Phase
// 3, Issue #258) — "MN"'s deep indigo is `linkInk`, not the capsule's blue.
// The public styles below keep their light colours for the screens that
// still use them directly; the parts apply the role's colour over them.

/// The title band's "Profile".
const TextStyle profileHeadingStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 24,
  height: 32 / 24,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The hero's name.
const TextStyle profileNameStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 18,
  height: 24 / 18,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
  leadingDistribution: TextLeadingDistribution.even,
);

/// A section caption's style. Public so the screens' tests can tell the
/// "Notification" caption from the "Notification" row.
const TextStyle captionStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 12,
  height: 16 / 12,
  fontWeight: FontWeight.w700,
  color: AppColors.textSecondary,
  leadingDistribution: TextLeadingDistribution.even,
);

/// A settings row's label style — see [captionStyle].
const TextStyle rowLabelStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 16,
  height: 24 / 16,
  fontWeight: FontWeight.w400,
  color: AppColors.textPrimary,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _segmentStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 12,
  height: 16 / 12,
  fontWeight: FontWeight.w700,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _logOutStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 16,
  height: 24 / 16,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
  leadingDistribution: TextLeadingDistribution.even,
);
