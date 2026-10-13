import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
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
      // A sheet: `surfaceElevated`, as the app's other sheets and the
      // sign-out dialog (Dark Mode Phases 5, 8 and 9).
      backgroundColor: context.palette.surfaceElevated,
      showDragHandle: false,
      constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.cardRadius),
        ),
      ),
      // The sheet may take the whole safe height, rather than Flutter's
      // default 9/16 of the screen: on a small phone, or at a larger text
      // size, that cap cut the options off — the email one could not be
      // chosen at 1.3× on a 375×667 phone (Issue #343).
      isScrollControlled: true,
      useSafeArea: true,
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
///    [AppTypography.sectionTitle]: a section heading, a step below Login's
///    [AppTypography.screenTitle]. Under it, [AppDimens.fieldGap] apart, a
///    short message in [AppTypography.body], in [AppColors.textPrimary];
///  * each option is the Login frame's contact card — white surface, 1pt
///    [AppColors.border], [AppDimens.cardRadius], [AppDimens.cardHeight],
///    trailing [AppIcons.caretRight] — led by its Phosphor glyph in
///    [AppColors.blue] on a round [AppDimens.statIconTile] tile, with the
///    action in [AppTypography.itemTitle] over the contact in
///    [AppTypography.supporting].
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

  /// How much of [_ScrollFade] shows: 0 while nothing is hidden below the
  /// scroll view — always, at the default size — up to 1 once at least its
  /// own height is.
  final ValueNotifier<double> _fade = ValueNotifier(0);

  bool _onScrollMetrics(ScrollMetrics metrics) {
    _fade.value = (metrics.extentAfter / _ScrollFade.height).clamp(0.0, 1.0);
    return false;
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The cue stays put — a fixed 68pt whatever the text size — and
          // everything under it scrolls when the sheet still cannot fit it
          // (Issue #343). A drag on the cue always dismisses the sheet, and
          // while everything fits the scroll view takes no drags, so a drag
          // anywhere dismisses it as before.
          const Padding(
            padding: EdgeInsets.only(top: AppDimens.headingToForm),
            child: Center(
              child: _IconTile(
                icon: AppIcons.chatCircleDots,
                size: AppDimens.avatarSize,
                iconSize: headerIconSize,
              ),
            ),
          ),
          Flexible(
            child: Stack(
              children: [
                // Both: the first tells the fade there is more below before
                // anything scrolls, the second as it scrolls.
                NotificationListener<ScrollMetricsNotification>(
                  onNotification: (n) => _onScrollMetrics(n.metrics),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) => _onScrollMetrics(n.metrics),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.screenPadding,
                        AppDimens.fieldGap,
                        AppDimens.screenPadding,
                        AppDimens.cardPadding,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            LoginStrings.contactSheetTitle,
                            style: AppTypography.sectionTitle.copyWith(
                              color: context.palette.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppDimens.fieldGap),
                          Text(
                            LoginStrings.contactMessage,
                            style: AppTypography.body.copyWith(
                              color: context.palette.textPrimary,
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
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _fade,
                    builder: (context, fade, _) => fade == 0
                        ? const SizedBox.shrink()
                        : _ScrollFade(opacity: fade),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The hint that the sheet scrolls (Issue #343): its own background fading
/// in over the foot of the scroll view while content is hidden below, and
/// fading out as the end is reached — so at the end nothing covers the last
/// option. The app has no scrollbar or scroll-fade pattern; this is the
/// lightest one, drawn in the sheet's own colour.
///
/// Drawn only while there is more below — never at the default size, where
/// nothing scrolls. It takes no pointers, so a tap or a drag under it reaches
/// the option or the sheet, and it has no semantics.
class _ScrollFade extends StatelessWidget {
  const _ScrollFade({required this.opacity});

  /// The fade's height, the sheet's own [AppDimens.headingToForm] step.
  static const double height = AppDimens.headingToForm;

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final surface = context.palette.surfaceElevated;
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [surface.withValues(alpha: 0), surface],
            ),
          ),
        ),
      ),
    );
  }
}

/// One way to reach the manager, drawn as the Login frame's contact card:
/// the same bordered white surface — at least 80pt — and trailing caret, led
/// by the option's glyph on a pale blue tile, with the action over the
/// contact.
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
      // `excludeSemantics` also drops the [InkWell]'s tap action, so the
      // button carries its own: without it a screen reader announced a
      // button it could not activate (Issue #343).
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          // At least the Login card's 80, and taller when a larger text
          // size needs it (Issue #343); the vertical inset only shows then —
          // at the default size the content sits well inside the 80.
          child: Container(
            constraints: const BoxConstraints(minHeight: AppDimens.cardHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.cardPadding,
              vertical: AppDimens.fieldGap,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.cardRadius),
              border: Border.all(
                color: context.palette.border,
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
                // The action and the contact wrap rather than ellipsize: cut
                // to "info@ai-acad…" at a large text size, the address — the
                // point of the option — was lost (Issue #343). At the default
                // size each is one line.
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.itemTitle.copyWith(
                          color: context.palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimens.cardLineGap),
                      Text(
                        value,
                        style: AppTypography.supporting.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.fieldGap),
                Icon(
                  AppIcons.caretRight,
                  size: AppDimens.caretSize,
                  color: context.palette.textSecondary,
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

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      // `primary` at 12 %, the same tint the Home program card's decoration
      // draws its blue with; the glyph in `primary`.
      decoration: BoxDecoration(
        color: context.palette.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: iconSize, color: context.palette.primary),
    );
  }
}
