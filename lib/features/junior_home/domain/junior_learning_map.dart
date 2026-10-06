import '../../home/domain/home_dashboard.dart';

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
///
/// These are the *server's* states. What the map draws for each node is
/// [JuniorLearningMap.stateOf], which keeps one module current (Issue #204).
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
  const JuniorMapNode({required this.id, required this.state, this.title = ''});

  /// The module's own id — what a tap opens (Issue #204).
  final int id;
  final JuniorNodeState state;

  /// The module's title — the heading of the lessons a tap opens. Empty for
  /// a sample node.
  final String title;
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
    this.nextLesson,
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

  /// The cohort's lesson under way or next to start — the dashboard's
  /// `EnrolledProgram.nextLesson`, from the `GET /cohorts` schedule. Null
  /// when the schedule names none. What decides whether the check-in node is
  /// live (Issue #202).
  final NextLesson? nextLesson;

  /// Every module completed, by the server's own `completed` flags — the
  /// program is done. Never true for a map with no nodes.
  bool get isComplete =>
      nodes.isNotEmpty &&
      nodes.every((node) => node.state == JuniorNodeState.completed);

  /// The student's one current module (Issue #204) — the attendance
  /// check-in node (Issue #202), the one the frame draws with the QR mark.
  ///
  /// The server's own answer, `continue.module_id`: the contract (§2.1)
  /// selects it as "the first unlocked, uncompleted lesson's module, or the
  /// last one when everything is done" — so it is only current while that
  /// module is unfinished. When `continue` names no open, unfinished module
  /// listed here, the first open, unfinished module in path order: the same
  /// rule at module level. Null when there is none — a completed program,
  /// or one with nothing unlocked (`continue: null`).
  ///
  /// A module that is merely unlocked and unfinished is **not** current:
  /// a course can unlock several at once, and the map draws one stop at a
  /// time.
  JuniorMapNode? get checkInNode {
    final open = nodes.where((n) => n.state == JuniorNodeState.current);
    return open.where((n) => n.id == continueModuleId).firstOrNull ??
        open.firstOrNull;
  }

  /// What the map draws for [node] (Issue #204): completed as completed, the
  /// [checkInNode] as current, and every other unfinished module as locked —
  /// the stops still ahead. Exactly one node is ever current, and a
  /// completed program has none.
  JuniorNodeState stateOf(JuniorMapNode node) {
    if (node.state == JuniorNodeState.completed) {
      return JuniorNodeState.completed;
    }
    return identical(node, checkInNode)
        ? JuniorNodeState.current
        : JuniorNodeState.locked;
  }

  /// Whether check-in is open at [now]: there is a [checkInNode] and a
  /// lesson is under way — Adult Home's own rule for its attendance action
  /// ([NextLesson.isLiveAt]), not a backend-defined window.
  bool checkInOpenAt(DateTime now) =>
      checkInNode != null && (nextLesson?.isLiveAt(now) ?? false);
}
