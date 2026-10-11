import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../course_learning/presentation/widgets/course_learning_back_button.dart';
import 'notification_strings.dart';

/// The back button with "Notification" centred on its row — the Certificate
/// screen's header, which the Figma "Notification" frame draws the same.
/// Shared by the Notification Center and Notification Detail (Issue #248),
/// so the detail screen reads as the same place. Its title takes
/// `AppPalette.textTitle` (Issue #252); the back button is a shared
/// component and moves with the others (audit Phase 3).
///
/// **The title never covers the button (Issue #325, as #318 fixed the
/// E-Contract header).** It used to fill the whole row on top of the button,
/// so at large text sizes it grew over the circle and took its taps. Now it
/// is kept out of the button's band on *both* sides — [_titleInset] — so it
/// stays centred on the row, wraps inside what is left, and the header grows
/// to fit it; the button is painted last, on top. At the default text size
/// the title fits that band on a 320-wide phone and lands exactly where it
/// did.
class NotificationHeader extends StatelessWidget {
  const NotificationHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          // The button's own 12 above it, so the title centres on the circle.
          padding: const EdgeInsets.fromLTRB(
            _titleInset,
            _backButtonTop,
            _titleInset,
            0,
          ),
          // At least the circle's height, so a one-line title is centred on
          // it as before; taller when the title wraps.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _backButtonSize),
            child: Center(
              child: Text(
                NotificationStrings.title,
                style: _titleStyle.copyWith(color: context.palette.textTitle),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const CourseLearningBackButton(icon: AppIcons.arrowLeft),
      ],
    );
  }
}

/// `CourseLearningBackButton`'s own inset above the circle.
const double _backButtonTop = 12;

/// `CourseLearningBackButton`'s circle.
const double _backButtonSize = 40;

/// Kept clear on either side of the header title: the button's screen inset,
/// its circle and 8 between them — mirrored on the right so the title stays
/// centred on the row (Issue #325).
const double _titleInset = AppDimens.screenPadding + _backButtonSize + 8;

const TextStyle _titleStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 18,
  height: 26 / 18,
  fontWeight: FontWeight.w700,
  leadingDistribution: TextLeadingDistribution.even,
);
