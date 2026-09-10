import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Where a successful sign-in lands.
///
/// A placeholder on purpose: the login flow needs a destination, and the home
/// screen is a separate piece of work. Replace it wholesale — nothing but the
/// `/home` route name points here.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Нэвтэрлээ',
              style: AppTypography.heading,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
