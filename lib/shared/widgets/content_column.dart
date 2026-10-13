import 'package:flutter/widgets.dart';

import '../../core/theme/app_dimens.dart';

/// Caps [child] at [AppDimens.maxContentWidth], centred at the top: on a wide
/// window a page's column stops and centres rather than stretching. Every
/// page does this (`SCREEN_PATTERNS.md` §1, Issue #368); this is the one
/// shared spelling of it.
class ContentColumn extends StatelessWidget {
  const ContentColumn({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
        child: child,
      ),
    );
  }
}
