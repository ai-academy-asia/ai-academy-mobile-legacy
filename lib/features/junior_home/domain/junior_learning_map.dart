/// How far along the path one learning node is.
///
/// Three states, because the Figma frame draws three and no more, and each
/// comes straight off a server field — the contract is explicit that the
/// client must derive neither `completed` nor `locked`:
///
/// * [completed] — `module.completed` is true.
/// * [locked] — `module.locked` is true.
/// * [current] — neither: the module is open and unfinished. The frame draws
///   one such node, so the name is the design's; the *meaning* is "unlocked
///   and not done", which is the only reading the two server booleans
///   support. Which of several open modules the student should resume is a
///   separate server answer — `continue.module_id`, kept on
///   [JuniorLearningMap.continueModuleId] rather than folded in here.
enum JuniorNodeState { completed, current, locked }

/// Where the student stands on earning the course certificate.
///
/// The three values `course_learning_api_contract_v1.md` §2.9 lists for
/// `certificate.status`, and no others — eligibility rules are the server's.
enum JuniorCertificateStatus { notEligible, eligible, issued }

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
    this.status,
  });

  /// "Junior" — the pill at the top of the card.
  final String track;

  /// "AI BootCamp".
  final String courseName;

  /// "Earn a Certificate of completion".
  final String description;

  /// `certificate.status` from the API.
  ///
  /// Null when the response omits the summary or sends a value outside the
  /// contract's three — this client does not guess a fourth state.
  ///
  /// Held but not drawn: the Figma frame has one certificate panel and no
  /// per-status variant of it, so binding this to a visual would mean
  /// designing that variant. It is in the domain so the screen can use it the
  /// moment the design says how.
  final JuniorCertificateStatus? status;
}

/// Everything the Junior Home screen draws, in one object.
///
/// Built by `ApiJuniorHomeRepository` from one `CourseLearningPath` —
/// `GET /me/courses/{course_slug}/learning`. Progress is a percentage and the
/// nodes carry server-decided state rather than colours or asset names,
/// because that is the shape the contract answers in; the icons and accents
/// the backend does not send stay in the widget layer.
class JuniorLearningMap {
  const JuniorLearningMap({
    required this.progress,
    required this.nodes,
    required this.certificate,
    this.continueModuleId,
    this.continueLessonId,
    this.courseSlug,
  });

  /// The learning path's own `Course.slug` — which course a node opens
  /// (Issue #174). Null for content that is not a real course (the sample
  /// map), which leaves the nodes inert.
  final String? courseSlug;

  final JuniorCourseProgress progress;

  /// In path order — first is the earliest stop. The map draws as many as its
  /// route has room for; see `junior_map_geometry.dart`.
  final List<JuniorMapNode> nodes;

  final JuniorCertificate certificate;

  /// The server's own answer to "where should this student resume?" —
  /// `continue.module_id` and `continue.lesson_id`.
  ///
  /// **Server-selected; this client does not recompute it.** Null when the
  /// contract sends `continue: null`, which means nothing is unlocked.
  ///
  /// Held in the domain rather than wired to a control: the Junior frame has
  /// no "Continue learning" button — the map itself is the navigation — so
  /// there is nothing to attach it to without inventing UI the design does
  /// not have.
  final int? continueModuleId;
  final int? continueLessonId;
}
