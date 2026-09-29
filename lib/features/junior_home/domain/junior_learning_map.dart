/// How far along the path one learning node is.
///
/// Three states, because the Figma frame draws three and no more: a finished
/// node, the one the student is on, and one not open yet. There is
/// deliberately no "available but not started" — the reference has no visual
/// for it, the same gap `CourseModule.locked` records for the adult screen.
enum JuniorNodeState { completed, current, locked }

/// One stop on the Junior learning map.
///
/// Carries no position: where a node sits is the *map's* business, not the
/// node's — the Figma frame lays the five out along a fixed hand-drawn route
/// rather than on a grid this data could describe. See
/// `junior_map_geometry.dart` for the route.
class JuniorMapNode {
  const JuniorMapNode({required this.id, required this.state});

  final int id;
  final JuniorNodeState state;
}

/// The course strip at the top of the map: what the student is studying, and
/// how far in they are.
class JuniorCourseProgress {
  const JuniorCourseProgress({
    required this.title,
    required this.percentComplete,
  });

  final String title;

  /// 0–100. Drawn as both the ring's sweep and its centre label.
  final int percentComplete;
}

/// The certificate panel at the foot of the map.
class JuniorCertificate {
  const JuniorCertificate({
    required this.track,
    required this.courseName,
    required this.description,
  });

  /// "Junior" — the pill at the top of the card.
  final String track;

  /// "AI BootCamp".
  final String courseName;

  /// "Earn a Certificate of completion".
  final String description;
}

/// Everything the Junior Home screen draws, in one object.
///
/// **Presentation data only.** This issue is UI-only and adds no backend
/// call; `sample_junior_learning_map.dart` hand-authors one of these from the
/// Figma frame. The shape is chosen so a repository can later return it
/// unchanged — which is why progress is a percentage and the nodes carry
/// server-decidable state rather than colours or asset names.
class JuniorLearningMap {
  const JuniorLearningMap({
    required this.progress,
    required this.nodes,
    required this.certificate,
  });

  final JuniorCourseProgress progress;

  /// In path order — first is the earliest stop. The map draws as many as its
  /// route has room for; see `junior_map_geometry.dart`.
  final List<JuniorMapNode> nodes;

  final JuniorCertificate certificate;
}
