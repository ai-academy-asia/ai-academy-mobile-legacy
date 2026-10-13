import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// Marks a debug build that talks to a non-production API (Issue #388): a
/// small pill at the top of every screen naming the server — `host:port`,
/// nothing else — so a local test is never mistaken for production.
///
/// Drawn by `MaterialApp.builder` only when `ApiConfig.current.isOverride`;
/// a production build never builds it. It takes no taps.
class ApiOverrideBanner extends StatelessWidget {
  const ApiOverrideBanner({
    required this.label,
    required this.child,
    super.key,
  });

  /// `ApiBaseUrl.label` — `host[:port]`.
  final String label;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: Center(
                child: Semantics(
                  label: 'Debug API: $label',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.errorInk,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: Text(
                        'API: $label',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: palette.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
