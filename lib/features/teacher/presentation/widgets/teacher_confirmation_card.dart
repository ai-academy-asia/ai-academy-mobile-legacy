import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import 'teacher_pill_button.dart';

/// A confirmed success: the success disc, the [title], and the full-width
/// [dismissLabel] ("Ойлголоо") that dismisses it — the Teacher redesign's one
/// success card, for "Хүсэлт илгээгдлээ" (Issue #372, shown since #449) and
/// "Амжилттай баталгаажлаа" (attendance, Issue #374).
///
/// A post-write state: show it only once the server has confirmed every
/// write it reports — never optimistically.
class TeacherConfirmationCard extends StatelessWidget {
  const TeacherConfirmationCard({
    required this.title,
    required this.dismissLabel,
    required this.onDismiss,
    super.key,
  });

  final String title;

  /// The dismiss button's label. Each caller passes its own, so the request
  /// card follows the language (Issue #547) while attendance keeps its
  /// Mongolian until its own migration.
  final String dismissLabel;

  /// Dismisses the card. Null leaves the button inert.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      // The reference's 16 / 29 / 16 to the card's outer edge, its 1pt
      // outline included.
      padding: const EdgeInsets.fromLTRB(15, 28, 15, 15),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        border: Border.all(color: palette.outlineFaint),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: _successDisc,
              height: _successDisc,
              decoration: BoxDecoration(
                color: palette.successFillStrong,
                shape: BoxShape.circle,
                border: Border.all(color: palette.successInk, width: 2.5),
              ),
              child: Icon(AppIcons.check, size: 18, color: palette.successInk),
            ),
          ),
          const SizedBox(height: 24),
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.sectionTitle.copyWith(
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          TeacherPillButton(
            label: dismissLabel,
            wrapLabel: true,
            variant: TeacherPillVariant.filled,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// The success disc: 37 across with its ring, as the reference draws it.
const double _successDisc = 37;
