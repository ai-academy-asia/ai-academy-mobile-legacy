import 'dart:ui';

/// Every position on the Junior learning map, in the Figma frame's own
/// coordinates.
///
/// **How this file was produced.** The reference export is 1179 x 4284 at 3x,
/// so 393 x 1428 logical. Each value below was measured off it at 1:1 — node
/// fills and card fills found by colour, the connector route traced run by run
/// down the frame — rather than estimated by eye. Nothing here is a round
/// number chosen for tidiness; where a value looks odd (154.7, 376.7) that is
/// what the frame draws.
///
/// **Origin.** y = 0 is the *top of the map*, the row just under the header's
/// rule at frame y = 108. So a frame measurement becomes a constant here by
/// subtracting 108. x is unchanged — the map runs the full 393 width.
///
/// **Scaling.** The map is laid out in this 393-wide space and multiplied by
/// one factor (`viewportWidth / mapWidth`) at paint time, so the composition
/// holds its proportions on any iPhone rather than reflowing. See
/// `JuniorLearningMapView`.
abstract final class JuniorMapGeometry {
  /// The design frame's own width, and the map's full scroll height.
  static const double mapWidth = 393;
  static const double mapHeight = 1214;

  /// The design frame's *full* height, header and tab bar included, and where
  /// the map starts inside it.
  ///
  /// Only the scenery asset needs these: it is exported as the whole frame,
  /// while everything else on this screen is positioned from the map's own
  /// origin. [mapHeight] is exactly `1322 - mapTopInFrame`, the band between
  /// the header's rule and the tab bar.
  static const double frameHeight = 1428;
  static const double mapTopInFrame = 108;

  // --- Course progress card ------------------------------------------------

  static const Rect courseCard = Rect.fromLTWH(16, 32, 361, 88);

  /// The card's own gutter matches the app's [AppDimens.screenPadding], which
  /// is why the card lands on the same 361 content width every other screen
  /// uses.
  static const double courseCardPadding = 17;
  static const double courseCardRadius = 24;

  /// The title's own text box. Narrower than the space left of the dial, so
  /// the sample course name wraps onto the two lines the frame draws it on —
  /// its longest line inks 127 wide there, and the gap before the dial is
  /// part of the design rather than slack.
  static const double courseTitleWidth = 180;

  /// Outer diameter and stroke of the "40%" ring, measured across its track.
  static const double ringSize = 56;
  static const double ringStroke = 5;

  // --- Learning nodes ------------------------------------------------------

  /// Every node is the same 84 x 84 rounded square; only the fill, the border
  /// and the glyph change with state.
  static const double nodeSize = 84;
  static const double nodeRadius = 20;
  static const double nodeBorder = 3;

  /// The flat band of the node's own outline colour under its bottom edge.
  /// Measured as 9 of colour below every node, of which 3 is the border
  /// itself.
  static const double nodeDepth = 6;

  /// The glyph box inside a node — the reference draws each state's artwork
  /// at 48 within the 84.
  static const double nodeGlyph = 48;

  /// Top-left of each node, in path order. Not a column and not a grid: the
  /// route swings right, back left, further left, then right again, which is
  /// the whole point of the frame.
  static const List<Offset> nodes = [
    Offset(154.7, 160), // 1 — completed
    Offset(277, 268.7), // 2 — completed
    Offset(154.7, 377), // 3 — current
    Offset(32, 485.7), // 4 — locked
    Offset(154.7, 594), // 5 — locked
  ];

  // --- Connectors ----------------------------------------------------------

  /// The radius of every elbow in the route. One value for all five, which is
  /// what the frame draws.
  static const double connectorRadius = 32;
  static const double connectorStroke = 3;

  /// The five connectors, each a right-angle elbow rounded at [connectorRadius].
  ///
  /// `from` and `to` sit on a node's edge (or, for the last one, on the
  /// certificate card's top) and `corner` is the right-angle vertex the elbow
  /// is filleted around. Only the first is drawn in the active blue — the
  /// route goes grey from node 2 onward, exactly where the frame does.
  static const List<JuniorConnector> connectors = [
    // node 1 right edge → right → down → node 2 top
    JuniorConnector(
      from: Offset(238.7, 202),
      corner: Offset(319, 202),
      to: Offset(319, 268.7),
      active: true,
    ),
    // node 2 bottom → down → left → node 3 right edge
    JuniorConnector(
      from: Offset(319, 352.7),
      corner: Offset(319, 419),
      to: Offset(238.7, 419),
    ),
    // node 3 left edge → left → down → node 4 top
    JuniorConnector(
      from: Offset(154.7, 419),
      corner: Offset(74, 419),
      to: Offset(74, 485.7),
    ),
    // node 4 bottom → down → right → node 5 left edge
    JuniorConnector(
      from: Offset(74, 569.7),
      corner: Offset(74, 636),
      to: Offset(154.7, 636),
    ),
    // node 5 right edge → right → down → the certificate card
    JuniorConnector(
      from: Offset(238.7, 636),
      corner: Offset(319, 636),
      to: Offset(319, 702),
    ),
  ];

  // --- Certificate ---------------------------------------------------------

  static const Rect certificateCard = Rect.fromLTWH(32, 705.7, 329, 361);
  static const double certificateRadius = 20;

  /// The pill, the certificate image and both lines of copy all sit on the
  /// same 17 inset, and the card's top and bottom padding are both 14.
  static const double certificatePadding = 17;
  static const double certificateVerticalPadding = 14;
  static const double certificatePillHeight = 30;
  static const double certificateImageHeight = 210;

  // --- Scenery -------------------------------------------------------------

  static const String assetDir = 'assets/images/junior_home';

  /// The whole Junior world behind the UI: the pale blue field, the pixel
  /// clouds, and every floating island, flower and coin.
  ///
  /// **This file is the Figma export itself**, unmodified and uncropped — not
  /// a reconstruction. It is the complete 393 x 1428 frame, which is why
  /// [frameHeight] and [mapTopInFrame] exist: the map draws it shifted up by
  /// the header's height so the export's own rows land on the map's
  /// coordinates, and the map's clip takes care of the rest. Nothing is
  /// scaled disproportionately — the box it is drawn into carries the
  /// export's own 393:1428 ratio.
  ///
  /// The islands and coins therefore come *from this image*, at the positions
  /// the design gave them. They were separate sprite widgets while the
  /// backdrop was a reconstruction with them erased; drawing both would
  /// double them.
  static String get backdrop => '$assetDir/map_backdrop.png';

  /// A node's state glyph — `node_check`, `node_current`, `node_lock`.
  static String sprite(String name) => '$assetDir/$name.png';

  // --- Scenery, piece by piece ---------------------------------------------
  //
  // The islands and coins of [backdrop], as separate pieces so each can move
  // on its own. Each was found in the export by matching the design's own
  // SVG against it at 3x — position and scale — to a mean difference around
  // 1/255. The clouds in motion are the same SVG at many sizes and heights
  // (`JuniorSceneryMotion.clouds`); the export's own seven appear only in the
  // still scenery.

  /// The design's pixel cloud, floating island (flowers included) and coin,
  /// at their exported sizes.
  static const String cloud = 'assets/icons/cloud.svg';
  static const String island = 'assets/icons/grass.svg';
  static const String coin = 'assets/icons/coin.svg';
  static const Size cloudSize = Size(207, 106);

  /// The largest cloud the frame draws (1.62x [cloudSize], bottom right of
  /// the export): no cloud in motion is ever larger.
  static const Size largestDesignCloud = Size(335.34, 171.72);
  static const Size islandSize = Size(125, 86);
  static const Size coinSize = Size(37, 37);

  /// Top-left of three of the export's four islands, each at 1:1. They are
  /// drawn over the clouds.
  static const List<Offset> islands = [
    Offset(289, 69),
    Offset(17, 285),
    Offset(-7, 797),
  ];

  /// Where each island's coin sits over it — the same for all three, at 1:1.
  static const Offset coinOnIsland = Offset(47, -20);

  /// The fourth island and its coin: the small, paler pair right of node 5.
  ///
  /// They match no uniform scale of the SVGs, so rather than guess at an
  /// opacity or a stretch, they are drawn from the export's own pixels
  /// ([farIsland]) and never animate.
  static const Rect unmatchedScenery = Rect.fromLTWH(296, 561, 80, 70);

  /// [unmatchedScenery]'s box of [backdrop] at 3x, with its sky cut away so
  /// a cloud can pass behind it.
  ///
  /// Derived from the export, not drawn: every pixel within 2/255 of the
  /// field colour is made transparent and every other pixel is kept exactly.
  /// The cut is clean — the box's sky is all one shade (`#C0D8F8`), and the
  /// pair's own pixels are all at least 6/255 away from it. Over the field it
  /// reproduces the export to within 1/255.
  static String get farIsland => '$assetDir/map_far_island.png';
}

/// One piece of scenery, placed in map coordinates.
class JuniorScenery {
  const JuniorScenery(this.asset, this.rect, {this.mirrored = false});

  final String asset;

  /// Where the asset's own box lands.
  final Rect rect;

  /// Drawn flipped left-to-right, as the frame draws some of its clouds.
  final bool mirrored;
}

/// One rounded right-angle elbow in the route.
class JuniorConnector {
  const JuniorConnector({
    required this.from,
    required this.corner,
    required this.to,
    this.active = false,
  });

  final Offset from;

  /// The right-angle vertex. The drawn line is filleted around this point, so
  /// it is never touched by the stroke itself.
  final Offset corner;

  final Offset to;

  /// True for the stretch the student has already walked — drawn in the brand
  /// blue. False draws the pale grey the locked half of the route uses.
  final bool active;
}
