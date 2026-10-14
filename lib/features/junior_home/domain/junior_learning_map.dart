import '../../home/domain/home_dashboard.dart';

/// How far along the path one lesson is (Issue #410).
///
/// From the lesson's two server booleans — the client never derives
/// `completed` or `locked`, and **the server's `locked` (its class date has
/// not arrived) is the only availability rule**, on this screen as on every
/// other — then the resume lesson picked out ([withResumeLesson]):
///
/// * [completed] — `lesson.completed` is true: a tick. Whether it can be
///   opened is [JuniorMapNode.locked], not this.
/// * [current] — the lesson to continue with: the server's resume lesson
///   (`continue.lesson_id`), open and not yet done. Opens.
/// * [open] — any other lesson the server leaves open and not yet done.
///   Opens.
/// * [locked] — the server locks it (`lesson.locked`, or its module's):
///   a grey padlock, inert.
enum JuniorNodeState { completed, current, open, locked }

/// Where the student stands on earning the course certificate.
///
/// The three values `course_learning_api_contract_v1.md` §2.9 lists for
/// `certificate.status`, and no others — eligibility rules are the server's.
enum JuniorCertificateStatus { notEligible, eligible, issued }

/// One stop on the Junior learning map: one lesson (Issue #410).
///
/// Carries no position: where a node sits is the *map's* business — the
/// route repeats the Figma frame's own swing, see `junior_map_geometry.dart`.
class JuniorMapNode {
  const JuniorMapNode({
    required this.id,
    required this.state,
    this.title = '',
    this.moduleId = 0,
    this.moduleOrder = 0,
    bool? locked,
  }) : locked = locked ?? state == JuniorNodeState.locked;

  /// The lesson's own id — what a tap opens, `CourseExerciseDetailScreen`'s
  /// `lessonId`.
  final int id;
  final JuniorNodeState state;

  /// The lesson's title, for its screen-reader label. Empty for a sample
  /// node.
  final String title;

  /// The module the lesson belongs to — `Lesson.moduleId` — and that
  /// module's `order` (§2.1). 0 for a sample node.
  final int moduleId;
  final int moduleOrder;

  /// Whether the server refuses this lesson's content (`409 lesson_locked`):
  /// the backend locks a whole module, every lesson alike, while its first
  /// class date is still ahead — the only access rule it enforces
  /// (`ensure_module_open`). A **completed** lesson can be locked too, when
  /// its class is moved to a later date: it keeps its tick but is inert, so
  /// no tap ever asks for content the server will refuse. Defaults to the
  /// [state] being [JuniorNodeState.locked].
  final bool locked;
}

/// Picks out the lesson to continue with (Issue #410) — and changes no
/// lesson's availability.
///
/// Of the lessons the server leaves open and not yet completed (state
/// [JuniorNodeState.open]), the server's own resume lesson,
/// [continueLessonId] — `continue.lesson_id`, "the first unlocked,
/// uncompleted lesson" in course order — becomes [JuniorNodeState.current];
/// should the server name none of them, the first of them in course order
/// (the same rule, read off the same flags). Every node keeps its server
/// lock, so whether a lesson opens is the server's `locked` alone.
List<JuniorMapNode> withResumeLesson(
  List<JuniorMapNode> nodes, {
  int? continueLessonId,
}) {
  final open = nodes.where((n) => n.state == JuniorNodeState.open);
  final resume =
      open.where((n) => n.id == continueLessonId).firstOrNull ??
      open.firstOrNull;
  return [
    for (final node in nodes)
      if (identical(node, resume))
        JuniorMapNode(
          id: node.id,
          state: JuniorNodeState.current,
          title: node.title,
          moduleId: node.moduleId,
          moduleOrder: node.moduleOrder,
          locked: node.locked,
        )
      else
        node,
  ];
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
/// `GET /me/courses/{course_slug}/learning` — and every module's lessons —
/// `GET /me/modules/{module_id}/lessons`. Progress is a percentage and the
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
    this.attendanceRecorded,
  });

  /// The learning path's own `Course.slug` — which course the course card
  /// opens (Issue #174). Null for content that is not a real course (the
  /// sample map), which leaves the nodes inert.
  final String? courseSlug;

  final JuniorCourseProgress progress;

  /// Every lesson of the course, in course order: modules by `order`, then
  /// each module's lessons by `order` (Issue #410). The route draws them
  /// all; see `junior_map_geometry.dart`.
  final List<JuniorMapNode> nodes;

  final JuniorCertificate certificate;

  /// The server's own answer to "where should this student resume?" —
  /// `continue.module_id` and `continue.lesson_id`. **Server-selected; this
  /// client does not recompute it.** Null when the contract sends
  /// `continue: null`, which means nothing is unlocked.
  final int? continueModuleId;
  final int? continueLessonId;

  /// The cohort's lesson under way or next to start — the dashboard's
  /// `EnrolledProgram.nextLesson`, from the `GET /cohorts` schedule. Null
  /// when the schedule names none. What decides whether check-in is live
  /// (Issue #202).
  final NextLesson? nextLesson;

  /// Whether today's class session already has an attendance record —
  /// `GET /me/attendance`'s `sessions[].status` for [nextLesson]'s date,
  /// which the backend leaves null until a record exists (Issue #410).
  /// Null when it is not known — not read (no [nextLesson]) or not
  /// readable: check-in then stays closed rather than risk offering one
  /// already recorded; the next reload asks again.
  final bool? attendanceRecorded;

  /// Every lesson completed, by the server's own `completed` flags — the
  /// program is done. Never true for a map with no nodes.
  bool get isComplete =>
      nodes.isNotEmpty &&
      nodes.every((node) => node.state == JuniorNodeState.completed);

  /// The lesson the attendance check-in belongs to (Issues #202, #410) — the
  /// one the frame draws with the QR mark: the lesson to continue with, the
  /// [JuniorNodeState.current] node ([withResumeLesson] leaves at most
  /// one; should a map carry several, the server's resume lesson among them,
  /// else the first). Null when there is none — a completed program, or
  /// nothing unlocked.
  JuniorMapNode? get checkInNode {
    final current = nodes.where((n) => n.state == JuniorNodeState.current);
    return current.where((n) => n.id == continueLessonId).firstOrNull ??
        current.firstOrNull;
  }

  /// Whether check-in is actionable at [now]: there is a [checkInNode], a
  /// lesson is under way by the cohort schedule — Adult Home's own rule
  /// ([NextLesson.isLiveAt]), not a backend-defined window — and today's
  /// session is known not to be recorded yet ([attendanceRecorded] false;
  /// unknown keeps it closed). Completing a lesson never enters into it:
  /// the two are separate.
  bool checkInOpenAt(DateTime now) =>
      checkInNode != null &&
      (nextLesson?.isLiveAt(now) ?? false) &&
      attendanceRecorded == false;
}
