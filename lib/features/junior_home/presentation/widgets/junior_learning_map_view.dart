import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

import '../../domain/junior_learning_map.dart';
import 'junior_certificate_card.dart';
import 'junior_course_progress_card.dart';
import 'junior_map_geometry.dart';
import 'junior_map_node.dart';
import 'junior_map_path_painter.dart';
import 'junior_map_scenery.dart';
import 'junior_map_theme.dart';

/// The game world between the header and the tab bar.
///
/// **Why a [Stack] and not a column of cards.** The frame is a hand-drawn
/// route: the nodes swing right, back left, further left and right again
/// — the reference's wave, repeated for every lesson — with islands and
/// coins tucked into the gaps between them. A [ListView] would straighten
/// all of that out. So every element is placed at
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
/// flowers and coins — is fixed to the map's viewport and never scrolls or
/// zooms (Issue #410). The route, nodes and cards scroll over it. Both
/// scenery layers are [JuniorMapScenery]'s.
///
/// **Paint order**, bottom to top: the sky, the [theme]'s cloud bank along
/// the background's bottom edge, the islands and coins — all background,
/// fixed to the viewport — then the route, the nodes, the course card and
/// the certificate card, which scroll over it. So the route runs behind
/// each node's rounded square, and at the end of the path the certificate
/// stands in front of the bank, which never moves with it (Issue #410).
///
/// **One node per lesson** (Issue #410), in course order, however many the
/// course has; the route joins them and ends at the certificate card. See
/// `JuniorMapGeometry.route`.
///
/// **Taps** (Issue #417), by each node's four-state look
/// ([JuniorLearningMap.displayStateOf]): CHECK_IN_REQUIRED — the check-in
/// node while check-in is actionable at [now] — calls [onCheckIn];
/// LESSON_COMPLETED and ATTENDANCE_COMPLETED call [onLessonTap] with their
/// lesson, unless the server locks it ([JuniorMapNode.opens]); LOCKED does
/// nothing. The course card calls [onCourseTap].
class JuniorLearningMapView extends StatelessWidget {
  const JuniorLearningMapView({
    required this.map,
    required this.now,
    super.key,
    this.onLessonTap,
    this.onCheckIn,
    this.onCourseTap,
    this.theme = JuniorMapTheme.junior,
  });

  final JuniorLearningMap map;

  /// What the check-in node's state is read against.
  final DateTime now;

  /// Called with a completed or open lesson when it is tapped. Null leaves
  /// every lesson inert.
  final ValueChanged<JuniorMapNode>? onLessonTap;

  /// Called when the check-in node is tapped while check-in is open. Null
  /// leaves it inert.
  final VoidCallback? onCheckIn;

  /// Called when the course card is tapped. Null leaves it inert.
  final VoidCallback? onCourseTap;

  /// The program's background — the sky and its cloud bank.
  final JuniorMapTheme theme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / JuniorMapGeometry.mapWidth;
        final nodes = map.nodes;
        final height = JuniorMapGeometry.mapHeightFor(nodes.length) * scale;
        final certificate = JuniorMapGeometry.certificateFor(nodes.length);

        // Each node's four-state look (Issue #417), from the derivation —
        // CHECK_IN_REQUIRED opens the scanner; LESSON_COMPLETED and
        // ATTENDANCE_COMPLETED open their lesson; LOCKED never opens.
        VoidCallback? tapFor(JuniorMapNode node) {
          if (map.displayStateOf(node, now) ==
              JuniorNodeState.checkInRequired) {
            return onCheckIn;
          }
          final onLessonTap = this.onLessonTap;
          if (onLessonTap == null || !node.opens) return null;
          return () => onLessonTap(node);
        }

        Widget at(Rect rect, Widget child) => Positioned(
          left: rect.left * scale,
          top: rect.top * scale,
          width: rect.width * scale,
          height: rect.height * scale,
          child: child,
        );

        // The scenery is fixed to the viewport behind the content, with its
        // own gentle motion and no zoom. The content scrolls over it.
        return JuniorMapScenery(
          scale: scale,
          theme: theme,
          content: SingleChildScrollView(
            // At least the frame's height; taller only when the certificate
            // card grows (below).
            child: ConstrainedBox(
              constraints: BoxConstraints.tightFor(
                width: constraints.maxWidth,
              ).copyWith(minHeight: height),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // The route, behind the nodes it joins.
                  Positioned.fill(
                    child: CustomPaint(
                      painter: JuniorMapPathPainter(
                        scale: scale,
                        travelled: context.palette.accent,
                        // White, as the updated reference draws the way
                        // ahead (Issue #410).
                        untravelled: context.palette.surface,
                        connectors: JuniorMapGeometry.route([
                          for (final node in nodes)
                            node.state == JuniorNodeState.completed,
                        ]),
                      ),
                    ),
                  ),

                  for (final (i, node) in nodes.indexed)
                    at(
                      JuniorMapGeometry.nodeAt(i) &
                          const Size(
                            JuniorMapGeometry.nodeSize,
                            JuniorMapGeometry.nodeSize,
                          ),
                      JuniorMapNodeTile(
                        node: node,
                        number: i + 1,
                        scale: scale,
                        checkIn:
                            map.displayStateOf(node, now) ==
                            JuniorNodeState.checkInRequired,
                        onTap: tapFor(node),
                      ),
                    ),

                  at(
                    JuniorMapGeometry.courseCard,
                    // No pressed state: the frame draws none, so the card
                    // looks exactly as it did (Issue #207).
                    Semantics(
                      button: onCourseTap != null,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onCourseTap,
                        child: JuniorCourseProgressCard(
                          progress: map.progress,
                          scale: scale,
                        ),
                      ),
                    ),
                  ),

                  // The one child not pinned to the frame, so the map sizes
                  // to it: at its frame place and size, but free to grow
                  // downward when a larger system text size needs room
                  // (Issue #345) — never capping the text. The card is the
                  // last thing on the map, so growing moves nothing else;
                  // the map grows by the same amount and keeps the frame's
                  // margin under it. At the default size it is exactly the
                  // frame's card and the map exactly the frame's height.
                  Padding(
                    padding: EdgeInsets.only(
                      left: certificate.left * scale,
                      top: certificate.top * scale,
                      bottom:
                          (JuniorMapGeometry.mapHeightFor(nodes.length) -
                              certificate.bottom) *
                          scale,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: certificate.width * scale,
                        maxWidth: certificate.width * scale,
                        minHeight: certificate.height * scale,
                      ),
                      child: JuniorCertificateCard(
                        certificate: map.certificate,
                        scale: scale,
                      ),
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
