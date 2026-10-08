import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../course_learning/presentation/widgets/course_learning_back_button.dart';
import 'notification_strings.dart';

/// The back button with "Notification" centred on its row — the Certificate
/// screen's header, which the Figma "Notification" frame draws the same.
/// Shared by the Notification Center and Notification Detail (Issue #248),
/// so the detail screen reads as the same place.
class NotificationHeader extends StatelessWidget {
  const NotificationHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const CourseLearningBackButton(icon: AppIcons.arrowLeft),
        Positioned.fill(
          top: _backButtonTop,
          child: const Center(
            child: Text(
              NotificationStrings.title,
              style: _titleStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
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
  color: Color(0xFF191919),
  leadingDistribution: TextLeadingDistribution.even,
);
