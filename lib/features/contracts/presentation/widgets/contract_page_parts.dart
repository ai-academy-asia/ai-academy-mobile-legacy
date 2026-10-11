import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../course_learning/presentation/widgets/course_learning_back_button.dart';
import '../contract_strings.dart';

/// The back button with "Гэрээ · E-Contract" centred on its row — the
/// export's header, the Certificate and Notification screens' layout. Shared
/// by the E-Contract list (Issue #312) and the contract form (Issue #314),
/// which both draw it.
class ContractHeader extends StatelessWidget {
  const ContractHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const CourseLearningBackButton(icon: AppIcons.arrowLeft),
        Positioned.fill(
          top: _backButtonTop,
          child: Center(
            child: Text(
              ContractStrings.title,
              style: _titleStyle.copyWith(color: context.palette.textTitle),
              textAlign: TextAlign.center,
            ),
          ),
        ),
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

const TextStyle _titleStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 18,
  height: 26 / 18,
  fontWeight: FontWeight.w700,
  leadingDistribution: TextLeadingDistribution.even,
);
