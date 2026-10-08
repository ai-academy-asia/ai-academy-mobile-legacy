import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../login_strings.dart';
import '../manager_contact.dart';

/// Asks how to reach the manager — call or email (Issue #186) — and completes
/// with the chosen link, [ManagerContact.phone] or [ManagerContact.email].
///
/// A tap on the barrier, a drag down and the system back gesture all complete
/// with null: nothing is launched and Login is left exactly as it was. There
/// is no "Цуцлах" button — those already are the way out (Issue #239).
Future<Uri?> chooseManagerContact(BuildContext context) =>
    showModalBottomSheet<Uri>(
      context: context,
      // Painted from the token, as the sign-out dialog paints its card.
      backgroundColor: AppColors.surface,
      showDragHandle: false,
      constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.cardRadius),
        ),
      ),
      builder: (_) => const ManagerContactSheet(),
    );

/// The sheet itself.
///
/// No Figma frame draws it, so nothing here is new design: it is assembled
/// from Login's own frame and existing tokens, so it reads as part of Login
/// rather than a stock sheet (Issue #239):
///
///  * a header cue — Phosphor [AppIcons.chatCircleDots] in [AppColors.blue]
///    on a round [AppDimens.avatarSize] tile of the same pale blue as the
///    options' own tiles — over the heading, "Танд асуух зүйл байна уу?", in
///    [AppTypography.catalogTitle]: a section heading, a step below Login's
///    22pt screen heading. Under it, [AppDimens.fieldGap] apart, a short
///    message in [AppTypography.statLabel] darkened to
///    [AppColors.textPrimary] so it reads as copy rather than a caption;
///  * each option is the Login frame's contact card — white surface, 1pt
///    [AppColors.border], [AppDimens.cardRadius], [AppDimens.cardHeight],
///    trailing [AppIcons.caretRight] — led by its Phosphor glyph in
///    [AppColors.blue] on a round [AppDimens.statIconTile] tile, with the
///    action in [AppTypography.cardHeading] over the contact in
///    [AppTypography.statLabel].
///
/// Spacing is Login's: [AppDimens.screenPadding] at the sides,
/// [AppDimens.headingToForm] above the cue and between the message and the
/// options, [AppDimens.fieldGap] under the cue, under the heading and between
/// the options, and
/// [AppDimens.cardPadding] under the last option — the safe area adds the
/// rest.
class ManagerContactSheet extends StatefulWidget {
  const ManagerContactSheet({super.key});

  @override
  State<ManagerContactSheet> createState() => _ManagerContactSheetState();
}

class _ManagerContactSheetState extends State<ManagerContactSheet> {
  /// The header cue's glyph — the 24pt nominal size the tab bar's Phosphor
  /// glyphs use, one step up from the options' 20.
  static const double headerIconSize = 24;

  // A second tap landing before the route is gone would pop Login itself.
  // Only the first answer counts — same guard as the sign-out dialog.
  bool _answered = false;

  void _answer(Uri choice) {
    if (_answered) return;
    _answered = true;
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          AppDimens.headingToForm,
          AppDimens.screenPadding,
          AppDimens.cardPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: _IconTile(
                icon: AppIcons.chatCircleDots,
                size: AppDimens.avatarSize,
                iconSize: headerIconSize,
              ),
            ),
            const SizedBox(height: AppDimens.fieldGap),
            const Text(
              LoginStrings.contactSheetTitle,
              style: AppTypography.catalogTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.fieldGap),
            Text(
              LoginStrings.contactMessage,
              style: AppTypography.statLabel.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.headingToForm),
            _ContactOption(
              icon: AppIcons.phone,
              label: LoginStrings.contactCall,
              value: ManagerContact.phoneLabel,
              onTap: () => _answer(ManagerContact.phone),
            ),
            const SizedBox(height: AppDimens.fieldGap),
            _ContactOption(
              icon: AppIcons.envelope,
              label: LoginStrings.contactEmail,
              value: ManagerContact.emailLabel,
              onTap: () => _answer(ManagerContact.email),
            ),
          ],
        ),
      ),
    );
  }
}

/// One way to reach the manager, drawn as the Login frame's contact card:
/// the same 80pt bordered white surface and trailing caret, led by the
/// option's glyph on a pale blue tile, with the action over the contact.
class _ContactOption extends StatelessWidget {
  const _ContactOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $value',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          child: Container(
            height: AppDimens.cardHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.cardPadding,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.cardRadius),
              border: Border.all(
                color: AppColors.border,
                width: AppDimens.borderWidth,
              ),
            ),
            child: Row(
              children: [
                _IconTile(
                  icon: icon,
                  size: AppDimens.statIconTile,
                  iconSize: AppDimens.settingsRowIconSize,
                ),
                const SizedBox(width: AppDimens.fieldGap),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.cardHeading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimens.cardLineGap),
                      Text(
                        value,
                        style: AppTypography.statLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.fieldGap),
                const Icon(
                  AppIcons.caretRight,
                  size: AppDimens.caretSize,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A Phosphor glyph in [AppColors.blue] on a round pale-blue tile — the
/// header cue and each option's lead.
class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  /// [AppColors.blue] at 12%, the same tint the Home program card's
  /// decoration draws its blue with.
  static final Color fill = AppColors.blue.withValues(alpha: 0.12);

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: Icon(icon, size: iconSize, color: AppColors.blue),
    );
  }
}
