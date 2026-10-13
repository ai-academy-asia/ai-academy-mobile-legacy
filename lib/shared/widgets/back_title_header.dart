import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import 'app_back_button.dart';

/// [AppBackButton] (the arrow) with [title] centred on its row — the one
/// header of every pushed page that has one (Issue #368): E-Contract,
/// Certificate, Notification and its detail, Change password, Attendance
/// detail, the Teacher Request and the Gradebook class, student and
/// submission screens. [AppDimens.backHeaderHeight] tall at one line, the
/// title in [AppTypography.headerTitle]; it does not scroll.
///
/// **The title never covers the button (Issues #318, #325).** It is kept out
/// of the button's band on *both* sides — [_titleInset] — so it stays
/// centred on the row, wraps inside what is left, and the header grows to
/// fit it; the button is painted last, on top. A title drawn over the
/// button used to take its taps at large text sizes. At the default text
/// size a short title fits that band on a 320-wide phone and lands centred
/// on the circle.
class BackTitleHeader extends StatelessWidget {
  const BackTitleHeader({super.key, required this.title});

  final String title;

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
          // it; taller when the title wraps.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _backButtonSize),
            child: Center(
              child: Text(
                title,
                style: AppTypography.headerTitle.copyWith(
                  color: context.palette.textTitle,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const AppBackButton(icon: AppIcons.arrowLeft),
      ],
    );
  }
}

/// [AppBackButton]'s own inset above the circle, and the circle.
const double _backButtonTop = AppDimens.backButtonTop;
const double _backButtonSize = AppDimens.backButtonSize;

/// Kept clear on either side of the title: the button's screen inset, its
/// circle and 8 between them — mirrored on the right so the title stays
/// centred on the row.
const double _titleInset = AppDimens.screenPadding + _backButtonSize + 8;
