import 'package:flutter/material.dart';

import '../../domain/junior_learning_map.dart';
import 'junior_certificate_card.dart';
import 'junior_course_progress_card.dart';
import 'junior_map_geometry.dart';
import 'junior_map_node.dart';
import 'junior_map_path_painter.dart';
import 'junior_map_scenery.dart';

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
/// wider gaps. The map never shrinks to fit the viewport's *height* — it
/// scrolls, because squashing it is what would break the composition.
///
/// **Layers.** The scenery — the sky and its clouds, then the islands,
/// flowers and coins — is fixed to the map's viewport and never scrolls; a
/// pinch zooms the sky, and only the sky. The route, nodes and cards scroll
/// over it. Both scenery layers are [JuniorMapScenery]'s.
///
/// **Paint order**, bottom to top: the sky, the islands and coins, then the
/// route, the nodes and the two cards. The route is under the nodes so each line runs
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

        // The scenery is fixed to the viewport behind the content, with its
        // own gentle motion and its own pinch. The content scrolls over it.
        return JuniorMapScenery(
          scale: scale,
          content: SingleChildScrollView(
            child: SizedBox(
              width: constraints.maxWidth,
              height: height,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
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
          ),
        );
      },
    );
  }
}
