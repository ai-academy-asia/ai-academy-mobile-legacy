import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/junior_learning_map.dart';
import 'junior_certificate_card.dart';
import 'junior_course_progress_card.dart';
import 'junior_map_geometry.dart';
import 'junior_map_node.dart';
import 'junior_map_path_painter.dart';

/// The game world between the header and the tab bar.
///
/// **Why a [Stack] and not a column of cards.** The frame is a hand-drawn
/// route: the five nodes swing right, back left, further left and right
/// again, with islands and coins tucked into the gaps between them. A
/// [ListView] would straighten all of that out. So every element is placed at
/// the coordinate the reference puts it at — see `JuniorMapGeometry`, which
/// holds the measurements and nothing else.
///
/// **How it stays proportional.** The whole map is laid out in the frame's own
/// 393-wide space and multiplied by a single factor, so a 430-wide iPhone
/// gets the same composition slightly larger rather than the same nodes with
/// wider gaps. The map never shrinks to fit the viewport's *height* — the
/// camera moves over it instead, because squashing it is what would break
/// the composition.
///
/// **The camera.** The frame sits inside a wider world (`_WorldCamera`) that
/// the student pans and pinch-zooms. The scenery, route, nodes and cards are
/// all in that world, so they move and scale together; the header and tab
/// bar are outside this widget and never move. The camera starts on the
/// frame at 1.0x — exactly the composition the reference draws.
///
/// **Paint order**, bottom to top: the scenery — one Figma export carrying
/// the sky, clouds, islands, flowers and coins — then the route, then the
/// nodes and the two cards. The route is under the nodes so each line runs
/// behind a node's rounded square, and the cards sit over the scenery the way
/// the frame draws them, covering the island and the coin behind each one.
class JuniorLearningMapView extends StatelessWidget {
  const JuniorLearningMapView({required this.map, super.key, this.onNodeTap});

  final JuniorLearningMap map;

  /// Called with a completed or current node when it is tapped; locked nodes
  /// never call it. Null leaves every node inert.
  final ValueChanged<JuniorMapNode>? onNodeTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / JuniorMapGeometry.mapWidth;
        final height = JuniorMapGeometry.mapHeight * scale;

        Widget at(Rect rect, Widget child) => Positioned(
          left: rect.left * scale,
          top: rect.top * scale,
          width: rect.width * scale,
          height: rect.height * scale,
          child: child,
        );

        return _WorldCamera(
          scale: scale,
          viewport: constraints.biggest,
          child: SizedBox(
            width: constraints.maxWidth,
            height: height,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // The scenery — sky, clouds, islands, flowers and coins, all
                // in one Figma export.
                //
                // The export is the whole 393 x 1428 frame, so it is drawn at
                // its full height and shifted up by the header's band to put
                // its map rows on this map's origin; the Stack's clip drops
                // what falls outside. The box carries the export's own
                // aspect, so nothing is stretched, and it is never cropped to
                // fit — the composition is the design's, unaltered.
                Positioned(
                  left: 0,
                  top: -JuniorMapGeometry.mapTopInFrame * scale,
                  width: JuniorMapGeometry.mapWidth * scale,
                  height: JuniorMapGeometry.frameHeight * scale,
                  child: Image.asset(
                    JuniorMapGeometry.backdrop,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    excludeFromSemantics: true,
                  ),
                ),

                // The route, behind the nodes it joins.
                Positioned.fill(
                  child: CustomPaint(
                    painter: JuniorMapPathPainter(scale: scale),
                  ),
                ),

                for (
                  var i = 0;
                  i < map.nodes.length && i < JuniorMapGeometry.nodes.length;
                  i++
                )
                  at(
                    JuniorMapGeometry.nodes[i] &
                        const Size(
                          JuniorMapGeometry.nodeSize,
                          JuniorMapGeometry.nodeSize,
                        ),
                    JuniorMapNodeTile(
                      node: map.nodes[i],
                      scale: scale,
                      onTap:
                          onNodeTap == null ||
                              map.nodes[i].state == JuniorNodeState.locked
                          ? null
                          : () => onNodeTap!(map.nodes[i]),
                    ),
                  ),

                at(
                  JuniorMapGeometry.courseCard,
                  JuniorCourseProgressCard(
                    progress: map.progress,
                    scale: scale,
                  ),
                ),

                at(
                  JuniorMapGeometry.certificateCard,
                  JuniorCertificateCard(
                    certificate: map.certificate,
                    scale: scale,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The camera over the Junior world: pan with one finger, pinch with two.
///
/// The world is the frame ([child], unchanged) with the scenery it crops
/// drawn whole around it — `JuniorMapGeometry.sceneryBeyondFrame` — on the
/// pale blue field the screen already paints behind the map. The frame's own
/// backdrop is opaque, so inside the frame every pixel is still the export;
/// the scenery shows only beyond its edges.
///
/// The camera starts with the frame filling the viewport at 1.0x, the same
/// view the screen had before it had a camera, and can never leave the
/// world: [InteractiveViewer]'s boundary is the world's own edge. It zooms
/// out only as far as the world's width filling the viewport, and in to
/// [maxZoom].
class _WorldCamera extends StatefulWidget {
  const _WorldCamera({
    required this.scale,
    required this.viewport,
    required this.child,
  });

  /// The map's design-space-to-pixels factor.
  final double scale;

  final Size viewport;

  /// The frame: backdrop, route, nodes and cards, laid out at [scale].
  final Widget child;

  /// A conservative ceiling with no design value behind it: twice the frame
  /// keeps a node's label legible and the 3x backdrop export from going soft.
  static const double maxZoom = 2;

  @override
  State<_WorldCamera> createState() => _WorldCameraState();
}

class _WorldCameraState extends State<_WorldCamera> {
  final _camera = TransformationController();

  @override
  void initState() {
    super.initState();
    _camera.value = _home();
  }

  @override
  void didUpdateWidget(_WorldCamera old) {
    super.didUpdateWidget(old);
    if (old.scale != widget.scale) _camera.value = _home();
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  /// The frame's left edge on the viewport's, at 1.0x.
  Matrix4 _home() => Matrix4.translationValues(
    JuniorMapGeometry.worldLeft * widget.scale,
    0,
    0,
  );

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final width = JuniorMapGeometry.worldWidth * scale;
    final height = JuniorMapGeometry.mapHeight * scale;
    final fit = math.max(
      widget.viewport.width / width,
      widget.viewport.height / height,
    );

    return InteractiveViewer(
      transformationController: _camera,
      constrained: false,
      minScale: math.min(fit, 1),
      maxScale: _WorldCamera.maxZoom,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (final piece in JuniorMapGeometry.sceneryBeyondFrame)
              Positioned(
                left: (piece.rect.left - JuniorMapGeometry.worldLeft) * scale,
                top: piece.rect.top * scale,
                width: piece.rect.width * scale,
                height: piece.rect.height * scale,
                child: Transform.flip(
                  flipX: piece.mirrored,
                  child: SvgPicture.asset(
                    piece.asset,
                    fit: BoxFit.fill,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            Positioned(
              left: -JuniorMapGeometry.worldLeft * scale,
              top: 0,
              width: JuniorMapGeometry.mapWidth * scale,
              height: height,
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}
