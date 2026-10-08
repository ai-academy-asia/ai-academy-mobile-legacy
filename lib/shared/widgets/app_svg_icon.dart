import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';

/// A monochrome SVG icon, always tinted from the theme (Dark Mode Phase 3,
/// Issue #258).
///
/// The app's single-colour icons — the bell, the Profile row icons — are
/// drawn `stroke="black"`, so untinted they stay black in any theme. This
/// paints them in [color], defaulting to [AppPalette.iconInk].
///
/// **Tinted only when the colour differs from the asset's own
/// ([authoredInk]).** A `srcIn` [ColorFilter] re-rasterises the picture and
/// moves anti-aliased edge pixels even when the colour is the same (measured
/// on the goldens: up to 9/255 on the Profile icons). So in light mode, where
/// [AppPalette.iconInk] is the icons' own black, the icon draws untinted —
/// pixel-identical to before — and any other palette tints it.
///
/// For artwork with several colours (illustrations, the track glyphs, module
/// art) use [SvgPicture] directly — a tint would flatten it.
class AppSvgIcon extends StatelessWidget {
  const AppSvgIcon(
    this.asset, {
    required this.size,
    this.color,
    this.authoredInk = AppColors.iconInk,
    this.semanticLabel,
    super.key,
  });

  final String asset;
  final double size;

  /// Defaults to `context.palette.iconInk`.
  final Color? color;

  /// The single colour the SVG file itself is drawn in — black for the
  /// app's monochrome icons. Painting in this colour needs no tint.
  final Color authoredInk;

  /// Passed through as [SvgPicture.semanticsLabel]; the semantics are
  /// otherwise exactly an untinted [SvgPicture]'s, so moving an icon here
  /// changes nothing a screen reader hears.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? context.palette.iconInk;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ink == authoredInk
          ? null
          : ColorFilter.mode(ink, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
    );
  }
}
