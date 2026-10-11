import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../course_learning/presentation/widgets/course_learning_back_button.dart';
import '../contract_strings.dart';

/// The back button with "Гэрээ · E-Contract" centred on its row — the
/// export's header, the Certificate and Notification screens' layout. Shared
/// by the E-Contract list (Issue #312), the contract form (Issue #314) and
/// the preview (Issue #316).
///
/// **The title never covers the button (Issue #318).** It used to fill the
/// whole row on top of the button, so at large text sizes it grew over the
/// circle and took its taps. Now it is kept out of the button's band on
/// *both* sides — [_titleInset] — so it stays centred on the row, wraps
/// inside what is left, and the header grows to fit it; the button is
/// painted last, on top. At the default text size the title fits that band
/// on a 320-wide phone and lands exactly where it did.
class ContractHeader extends StatelessWidget {
  const ContractHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
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
                ContractStrings.title,
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

/// A centred line, with an optional action under it — the E-Contract
/// screens' empty and failure states.
class ContractMessage extends StatelessWidget {
  const ContractMessage({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTypography.statLabel.copyWith(
                color: context.palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (action case final action?) ...[
              const SizedBox(height: AppDimens.fieldGap),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

/// `CourseLearningBackButton`'s own inset above the circle.
const double _backButtonTop = 12;

/// `CourseLearningBackButton`'s circle.
const double _backButtonSize = 40;

/// Kept clear on either side of the title: the button's screen inset, its
/// circle and 8 between them — mirrored on the right so the title stays
/// centred on the row.
const double _titleInset = AppDimens.screenPadding + _backButtonSize + 8;

const TextStyle _titleStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 18,
  height: 26 / 18,
  fontWeight: FontWeight.w700,
  leadingDistribution: TextLeadingDistribution.even,
);
