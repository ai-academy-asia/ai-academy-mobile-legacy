import 'package:flutter/painting.dart';

import '../../../../core/theme/app_palette.dart';
import 'junior_map_geometry.dart';

/// One large cloud of a theme's bank, in design units measured from the
/// **bottom-left corner of the program's background** — x to the right, y
/// upward as negative values — so the bank sits on the background's bottom
/// edge on every phone, scaled with the map's width like everything else.
class JuniorBankCloud {
  const JuniorBankCloud(this.rect, {this.mirrored = false});

  final Rect rect;
  final bool mirrored;
}

/// What gives a program's learning path its background (Issue #410): the
/// sky's colour, its cloud artwork, and the bank of large clouds along the
/// background's bottom edge — the boundary of this program's world.
///
/// All of it is background: fixed to the map's viewport behind the
/// scrolling path, never scrolling with the certificate or the nodes. The
/// path's layout — nodes, route, cards — never reads a colour or an asset
/// from here, so another program can bring its own background by adding a
/// theme and selecting it in [forTrack], without touching the layout.
/// Today there is one: [junior], the Junior sky.
class JuniorMapTheme {
  const JuniorMapTheme({
    required this.sky,
    required this.cloudAsset,
    required this.bankClouds,
  });

  /// The field behind everything — a palette role, so it follows the theme.
  final Color Function(AppPalette palette) sky;

  /// The cloud artwork the sky and the bank share.
  final String cloudAsset;

  /// The large clouds along the background's bottom edge. Decorative: drawn
  /// behind the content, never hit-tested, never announced, never moving.
  final List<JuniorBankCloud> bankClouds;

  /// The Junior sky: its field, its pixel clouds, and the updated
  /// reference's cloud bank (`junior-homepage-u[date.png`), measured from
  /// the map's bottom edge there (the tab bar's top, y 1989): two clouds
  /// rising about 210 at either side, two wider ones from about 150 across
  /// the middle, and two more filling the bottom — each at the cloud
  /// export's own 207:106 aspect. At the end of the path the certificate
  /// card stands in front of the bank, as the reference draws it.
  static const JuniorMapTheme junior = JuniorMapTheme(
    sky: _juniorSky,
    cloudAsset: JuniorMapGeometry.cloud,
    bankClouds: [
      JuniorBankCloud(Rect.fromLTWH(-38, -209.3, 200, 102)),
      JuniorBankCloud(Rect.fromLTWH(227, -219.3, 200, 102), mirrored: true),
      JuniorBankCloud(Rect.fromLTWH(-78, -144.3, 300, 154), mirrored: true),
      JuniorBankCloud(Rect.fromLTWH(172, -149.3, 300, 154)),
      JuniorBankCloud(Rect.fromLTWH(-28, -44.3, 300, 154), mirrored: true),
      JuniorBankCloud(Rect.fromLTWH(212, -34.3, 300, 154)),
    ],
  );

  static Color _juniorSky(AppPalette palette) => palette.juniorMapSky;

  /// The theme for a program on [track] — every program draws the Junior
  /// sky today. The one place a second program's background is chosen.
  static JuniorMapTheme forTrack(String? track) => junior;
}
