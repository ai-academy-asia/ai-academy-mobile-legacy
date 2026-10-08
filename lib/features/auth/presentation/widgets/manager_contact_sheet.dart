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
/// from Login's own frame and the sign-out dialog (#166), restyled so it reads
/// as part of Login rather than a stock sheet (Issue #239):
///
///  * the heading, "Бид танд туслахад бэлэн", is set in Login's screen
///    [AppTypography.heading], with a short message under it in
///    [AppTypography.statLabel] — the sign-out dialog's message style —
///    [AppDimens.titleToSupporting] apart, as Reset Password spaces its
///    heading and supporting line;
///  * each option is the Login frame's contact card — white surface, 1pt
///    [AppColors.border], [AppDimens.cardRadius], [AppDimens.cardHeight],
///    trailing [AppIcons.caretRight] — led by its Phosphor glyph in
///    [AppColors.blue] on a round [AppDimens.statIconTile] tile, with the
///    action in [AppTypography.cardHeading] over the contact in
///    [AppTypography.statLabel].
///
/// Spacing is Login's: [AppDimens.screenPadding] at the sides,
/// [AppDimens.headingToForm] above the heading, between the message and the
/// options and under the last one, [AppDimens.fieldGap] between the options.
class ManagerContactSheet extends StatefulWidget {
  const ManagerContactSheet({super.key});

  @override
  State<ManagerContactSheet> createState() => _ManagerContactSheetState();
}

class _ManagerContactSheetState extends State<ManagerContactSheet> {
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
          AppDimens.headingToForm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              LoginStrings.contactSheetTitle,
              style: AppTypography.heading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.titleToSupporting),
            const Text(
              LoginStrings.contactMessage,
              style: AppTypography.statLabel,
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

  /// The tile behind the glyph: [AppColors.blue] at 12%, the same tint the
  /// Home program card's decoration draws its blue with.
  static final Color tileFill = AppColors.blue.withValues(alpha: 0.12);

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
                Container(
                  width: AppDimens.statIconTile,
                  height: AppDimens.statIconTile,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tileFill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: AppDimens.settingsRowIconSize,
                    color: AppColors.blue,
                  ),
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
