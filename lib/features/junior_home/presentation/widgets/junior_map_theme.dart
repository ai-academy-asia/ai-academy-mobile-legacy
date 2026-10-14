import 'package:flutter/painting.dart';

import '../../../../core/theme/app_palette.dart';
import 'junior_map_geometry.dart';

/// One large cloud of a theme's divider, in design units relative to the
/// certificate card's top-left.
class JuniorDividerCloud {
  const JuniorDividerCloud(this.rect, {this.mirrored = false});

  final Rect rect;
  final bool mirrored;
}

/// What gives a program's learning path its background (Issue #410): the
/// sky's colour, its cloud artwork, and the bank of large clouds round the
/// lower half of the certificate card — the divider between this program's
/// path and the region a next program's would take.
///
/// The path's layout — nodes, route, cards — never reads a colour or an
/// asset from here, so another program can bring its own background by
/// adding a theme and selecting it in [forTrack], without touching the
/// layout. Today there is one: [junior], the Junior sky.
class JuniorMapTheme {
  const JuniorMapTheme({
    required this.sky,
    required this.cloudAsset,
    required this.dividerClouds,
  });

  /// The field behind everything — a palette role, so it follows the theme.
  final Color Function(AppPalette palette) sky;

  /// The cloud artwork the sky and the divider share.
  final String cloudAsset;

  /// The large clouds behind the certificate card's lower half and under it.
  /// Decorative: drawn behind the card, never hit-tested, never announced.
  final List<JuniorDividerCloud> dividerClouds;

  /// The Junior sky: its field, its pixel clouds, and the updated
  /// reference's cloud bank round the certificate (`junior-homepage-u[date.png`)
  /// — two flanking the card's lower half, two wider ones under it, each at
  /// the cloud export's own 207:106 aspect, the card covering their middles.
  static const JuniorMapTheme junior = JuniorMapTheme(
    sky: _juniorSky,
    cloudAsset: JuniorMapGeometry.cloud,
    dividerClouds: [
      JuniorDividerCloud(Rect.fromLTWH(-80, 150, 230, 118)),
      JuniorDividerCloud(Rect.fromLTWH(180, 140, 230, 118), mirrored: true),
      JuniorDividerCloud(Rect.fromLTWH(-60, 270, 280, 143), mirrored: true),
      JuniorDividerCloud(Rect.fromLTWH(130, 285, 280, 143)),
    ],
  );

  static Color _juniorSky(AppPalette palette) => palette.juniorMapSky;

  /// The theme for a program on [track] — every program draws the Junior
  /// sky today. The one place a second program's background is chosen.
  static JuniorMapTheme forTrack(String? track) => junior;
}
