import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../login_strings.dart';
import '../manager_contact.dart';

/// Asks how to reach the manager — call or email (Issue #186) — and completes
/// with the chosen link, [ManagerContact.phone] or [ManagerContact.email].
///
/// "Цуцлах", a tap on the barrier and the system back gesture all complete
/// with null: nothing is launched and Login is left exactly as it was.
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
/// No Figma frame draws it, so nothing here is new design. It is assembled
/// from what Login's own frame and the sign-out dialog (#166) already use:
///
///  * the heading is Login's own "Менежертэй холбогдоорой" in
///    [AppTypography.cardHeading], as the dialog heads its card;
///  * each option is the Login frame's contact card — white surface, 1pt
///    [AppColors.border], [AppDimens.cardRadius], trailing
///    [AppIcons.caretRight] — with the action as its [AppTypography.cardTitle]
///    line and the contact itself as its [AppTypography.cardSupporting] line,
///    led by a Phosphor glyph from the font the design draws with;
///  * "Цуцлах" is the dialog's outlined [AppButton], its way back.
///
/// Spacing is the screen's own: [AppDimens.cardPadding] around the content,
/// [AppDimens.headingToForm] under the heading and above the button,
/// [AppDimens.fieldGap] between the two options.
class ManagerContactSheet extends StatefulWidget {
  const ManagerContactSheet({super.key});

  @override
  State<ManagerContactSheet> createState() => _ManagerContactSheetState();
}

class _ManagerContactSheetState extends State<ManagerContactSheet> {
  // A second tap landing before the route is gone would pop Login itself.
  // Only the first answer counts — same guard as the sign-out dialog.
  bool _answered = false;

  void _answer(Uri? choice) {
    if (_answered) return;
    _answered = true;
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              LoginStrings.contactManager,
              style: AppTypography.cardHeading,
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
            const SizedBox(height: AppDimens.headingToForm),
            AppButton(
              label: LoginStrings.contactCancel,
              variant: AppButtonVariant.outlined,
              onPressed: () => _answer(null),
            ),
          ],
        ),
      ),
    );
  }
}

/// One way to reach the manager, drawn as the Login frame's contact card:
/// the same 80pt bordered white surface and trailing caret, with the action
/// over the contact rather than the card's supporting line over its title.
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
                Icon(
                  icon,
                  size: AppDimens.settingsRowIconSize,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimens.cardLineGap),
                      Text(
                        value,
                        style: AppTypography.cardSupporting,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
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
