import 'package:flutter/material.dart';

import '../../domain/junior_learning_map.dart';
import '../junior_home_strings.dart';
import 'junior_map_geometry.dart';
import '../../../../core/theme/app_palette.dart';

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
///
/// **The check-in node** (Issue #202) is the current module's — the one the
/// frame draws with the QR mark. [checkInOpen] true draws it as the frame
/// does; false, outside a lesson, draws it grey — the locked node's fill and
/// outline, its QR mark in greys — so it reads as not available yet. Null
/// for every other node.
class JuniorMapNodeTile extends StatelessWidget {
  const JuniorMapNodeTile({
    required this.node,
    required this.scale,
    super.key,
    this.onTap,
    this.checkInOpen,
    this.state,
  });

  final JuniorMapNode node;

  /// What the node is drawn as — the map's `JuniorLearningMap.stateOf`, so
  /// only one node is ever current (Issue #204). Null draws [node]'s own.
  final JuniorNodeState? state;

  /// Whether this is the check-in node, and if so whether check-in is open.
  final bool? checkInOpen;

  /// Opens the course, or null for an inert node. The map passes one for
  /// completed and current nodes only — a locked module stays inert, as a
  /// locked module card does on the Adult course screen (Issue #174). No
  /// pressed state is drawn: the frame has none, so the node looks exactly
  /// as it did.
  final VoidCallback? onTap;

  /// The map's design-space-to-pixels factor.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final closed = checkInOpen == false;
    final drawn = state ?? node.state;
    final palette = context.palette;
    final style = closed
        ? _NodeStyle.closedCheckIn(palette)
        : _NodeStyle.of(drawn, palette);
    final glyph = Image.asset(
      JuniorMapGeometry.sprite(style.glyph),
      width: JuniorMapGeometry.nodeGlyph * scale,
      height: JuniorMapGeometry.nodeGlyph * scale,
      filterQuality: FilterQuality.high,
    );

    final onTap = this.onTap;
    return Semantics(
      label: switch (checkInOpen) {
        null => JuniorHomeStrings.nodeLabel(node.id, drawn),
        final open => JuniorHomeStrings.checkInNodeLabel(node.id, open: open),
      },
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
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
            // The node's lift: not a blurred shadow but a flat band of the
            // node's *own outline colour* — measured down the centre of all
            // three states, the frame draws 9 of it below the node, 3 of
            // border and 6 of band, with no gradient. A zero-blur shadow of
            // the node's rounded square, offset down: the same depth idiom
            // `CourseModuleCard` uses. The opaque fill on this same
            // decoration keeps the band from covering the node.
            boxShadow: [
              BoxShadow(
                color: style.border,
                offset: Offset(0, JuniorMapGeometry.nodeDepth * scale),
              ),
            ],
          ),
          child: Center(
            child: closed
                ? ColorFiltered(colorFilter: _greys, child: glyph)
                : glyph,
          ),
        ),
      ),
    );
  }
}

/// Luminance only — the QR mark's own light and dark, in greys.
const ColorFilter _greys = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

class _NodeStyle {
  const _NodeStyle({
    required this.fill,
    required this.border,
    required this.glyph,
  });

  final Color fill;
  final Color border;
  final String glyph;

  /// The check-in node outside a lesson: the locked node's fill and outline
  /// round the QR mark.
  static _NodeStyle closedCheckIn(AppPalette palette) => _NodeStyle(
    fill: palette.juniorMutedFill,
    border: palette.outline,
    glyph: 'node_current',
  );

  /// Completed: the course card's pale blue (`juniorCard`) in the accent.
  /// Current: a `surface` node in the `outline` grey. Locked: the map's
  /// not-yet-reached grey (`juniorMutedFill`). The glyphs are authored.
  static _NodeStyle of(JuniorNodeState state, AppPalette palette) =>
      switch (state) {
        JuniorNodeState.completed => _NodeStyle(
          fill: palette.juniorCard,
          border: palette.accent,
          glyph: 'node_check',
        ),
        JuniorNodeState.current => _NodeStyle(
          fill: palette.surface,
          border: palette.outline,
          glyph: 'node_current',
        ),
        JuniorNodeState.locked => _NodeStyle(
          fill: palette.juniorMutedFill,
          border: palette.outline,
          glyph: 'node_lock',
        ),
      };
}
