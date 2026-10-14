import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/junior_learning_map.dart';
import '../junior_home_strings.dart';
import 'junior_map_geometry.dart';

/// One 84 x 84 stop on the route — one lesson (Issue #410).
///
/// Fill, outline and glyph follow the lesson's [JuniorNodeState]; the size,
/// radius and border never change, which is what makes the path read as one
/// family in the reference.
///
/// The tick, the scan mark and the padlock are the design's exported
/// artwork — none has a match in the bundled Phosphor set (Issue #410): a
/// completed lesson the tick on the pale blue face — **a tick always means
/// completed**; **the lesson to continue with** the active frame (the white
/// face in the accent outline and band) with no glyph, as it is not done
/// yet — the one unfinished lesson that opens; every
/// other unfinished lesson, which cannot be opened, the grey padlock —
/// whether its class date has not come ([JuniorNodeState.locked]) or it has
/// but its turn has not ([JuniorNodeState.open]): a node that does not open
/// never looks as if it might. No other glyph is ever drawn on the path;
/// the screen-reader label still tells the two apart.
///
/// **The check-in node** (Issues #202, #410): while check-in is actionable
/// ([checkIn] true) the lesson draws as the updated reference's check-in
/// stop — the QR mark on the white face, in the accent frame — and pulses
/// gently, unless the platform asks for reduced motion. The pulse only
/// scales what is painted: the node's place and its tap target never move.
/// When check-in is not actionable the node is simply its lesson.
class JuniorMapNodeTile extends StatefulWidget {
  const JuniorMapNodeTile({
    required this.node,
    required this.number,
    required this.scale,
    super.key,
    this.onTap,
    this.checkIn = false,
  });

  final JuniorMapNode node;

  /// The lesson's place on the path, 1-based — its screen-reader name.
  final int number;

  /// Whether this is the check-in node while check-in is actionable.
  final bool checkIn;

  /// Opens the lesson (or, for an actionable check-in node, the scanner).
  /// Null for an inert node — a locked lesson, or the sample map. No pressed
  /// state is drawn: the frame has none.
  final VoidCallback? onTap;

  /// The map's design-space-to-pixels factor.
  final double scale;

  /// How far the check-in node swells at the top of a pulse, and how long a
  /// beat lasts. Chosen, not design values: a restrained, slow beat.
  static const double pulseScale = 1.06;
  static const Duration pulsePeriod = Duration(milliseconds: 1400);

  @override
  State<JuniorMapNodeTile> createState() => _JuniorMapNodeTileState();
}

class _JuniorMapNodeTileState extends State<JuniorMapNodeTile>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(JuniorMapNodeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  /// Pulses only while this is an actionable check-in and motion is allowed;
  /// stops — and rests at full size — the moment either changes.
  void _syncPulse() {
    final pulse = widget.checkIn && !MediaQuery.disableAnimationsOf(context);
    if (pulse && _pulse == null) {
      _pulse = AnimationController(
        vsync: this,
        duration: JuniorMapNodeTile.pulsePeriod,
      )..repeat(reverse: true);
    } else if (!pulse && _pulse != null) {
      _pulse!.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final scale = widget.scale;
    final palette = context.palette;
    final style = widget.checkIn
        ? _NodeStyle.checkIn(palette)
        : _NodeStyle.of(node.state, palette);
    final glyphSize = JuniorMapGeometry.nodeGlyph * scale;
    final glyph = switch (style.glyph) {
      final String sprite => Image.asset(
        JuniorMapGeometry.sprite(sprite),
        width: glyphSize,
        height: glyphSize,
        filterQuality: FilterQuality.high,
      ),
      // The continue lesson: the frame alone carries it.
      null => const SizedBox.shrink(),
    };

    Widget tile = Container(
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
        // node's *own outline colour* — 9 of colour below every node, 3 of
        // border and 6 of band, with no gradient.
        boxShadow: [
          BoxShadow(
            color: style.border,
            offset: Offset(0, JuniorMapGeometry.nodeDepth * scale),
          ),
        ],
      ),
      child: Center(child: glyph),
    );
    final pulse = _pulse;
    if (pulse != null) {
      tile = ScaleTransition(
        scale: Tween<double>(
          begin: 1,
          end: JuniorMapNodeTile.pulseScale,
        ).animate(CurvedAnimation(parent: pulse, curve: Curves.easeInOut)),
        child: tile,
      );
    }

    final onTap = widget.onTap;
    return Semantics(
      label: widget.checkIn
          ? JuniorHomeStrings.checkInNodeLabel(widget.number, node.title)
          : JuniorHomeStrings.nodeLabel(widget.number, node.title, node.state),
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: tile,
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

  /// The exported sprite's name; null for the continue lesson's empty
  /// active frame.
  final String? glyph;

  /// The live check-in: the updated reference's QR stop — the white face in
  /// the accent frame.
  static _NodeStyle checkIn(AppPalette palette) => _NodeStyle(
    fill: palette.surface,
    border: palette.accent,
    glyph: 'node_current',
  );

  /// Completed: the tick on the course card's pale blue (`juniorCard`) in
  /// the accent. Current: the active frame — a `surface` node in the
  /// accent — with no tick: it is not completed. Open and locked — both
  /// cannot be opened: the padlock on the map's not-yet-reached grey
  /// (`juniorMutedFill`) in the `outline`.
  static _NodeStyle of(JuniorNodeState state, AppPalette palette) =>
      switch (state) {
        JuniorNodeState.completed => _NodeStyle(
          fill: palette.juniorCard,
          border: palette.accent,
          glyph: 'node_check',
        ),
        JuniorNodeState.current => _NodeStyle(
          fill: palette.surface,
          border: palette.accent,
          glyph: null,
        ),
        JuniorNodeState.open || JuniorNodeState.locked => _NodeStyle(
          fill: palette.juniorMutedFill,
          border: palette.outline,
          glyph: 'node_lock',
        ),
      };
}
