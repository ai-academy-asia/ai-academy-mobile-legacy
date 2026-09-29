import 'package:flutter/material.dart';

import '../../domain/junior_learning_map.dart';
import '../junior_home_strings.dart';
import 'junior_home_palette.dart';
import 'junior_map_geometry.dart';

/// One 84 x 84 stop on the route.
///
/// Fill, outline and glyph all follow [JuniorNodeState]; the size, radius and
/// border never change, which is what makes the five read as one family in
/// the reference.
///
/// Named `...Tile` rather than `JuniorMapNode` so the widget does not shadow
/// the domain model it draws.
///
/// The three glyphs are exported artwork rather than font icons. A completed
/// node's tick, the current node's scan mark and a locked node's padlock are
/// each drawn by the design, and none has a match in the bundled Phosphor set
/// or in `assets/images/course_learning/` — the nearest candidates there are a
/// *green disc* tick and an *outline* padlock, neither of which is what this
/// frame draws. Guessing a codepoint is what `DEVELOPMENT_RULES.md` §6
/// forbids, so the design's own glyphs are used.
class JuniorMapNodeTile extends StatelessWidget {
  const JuniorMapNodeTile({required this.node, required this.scale, super.key});

  final JuniorMapNode node;

  /// The map's design-space-to-pixels factor.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final style = _NodeStyle.of(node.state);

    return Semantics(
      label: JuniorHomeStrings.nodeLabel(node.id, node.state),
      child: Container(
        decoration: BoxDecoration(
          color: style.fill,
          borderRadius: BorderRadius.circular(
            JuniorMapGeometry.nodeRadius * scale,
          ),
          border: Border.all(
            color: style.border,
            width: JuniorMapGeometry.nodeBorder * scale,
          ),
          boxShadow: JuniorPalette.nodeDepth(
            style.border,
            JuniorMapGeometry.nodeDepth * scale,
          ),
        ),
        child: Center(
          child: Image.asset(
            JuniorMapGeometry.sprite(style.glyph),
            width: JuniorMapGeometry.nodeGlyph * scale,
            height: JuniorMapGeometry.nodeGlyph * scale,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

class _NodeStyle {
  const _NodeStyle({
    required this.fill,
    required this.border,
    required this.glyph,
  });

  final Color fill;
  final Color border;
  final String glyph;

  static _NodeStyle of(JuniorNodeState state) => switch (state) {
    JuniorNodeState.completed => const _NodeStyle(
      fill: JuniorPalette.cardFill,
      border: JuniorPalette.accent,
      glyph: 'node_check',
    ),
    JuniorNodeState.current => const _NodeStyle(
      fill: Color(0xFFFFFFFF),
      border: JuniorPalette.muted,
      glyph: 'node_current',
    ),
    JuniorNodeState.locked => const _NodeStyle(
      fill: JuniorPalette.mutedFill,
      border: JuniorPalette.muted,
      glyph: 'node_lock',
    ),
  };
}
