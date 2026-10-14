import '../../course_learning/domain/lesson_access.dart';
import '../../home/domain/home_dashboard.dart';

/// How a lesson is drawn on the Junior map — **exactly the four product
/// states** (Issues #415, #417), each from [lessonPathStateFor] through
/// [juniorNodeStateOf], so derivation stays apart from styling:
///
/// * [completed] — LESSON_COMPLETED: a saved, non-empty note on the lesson:
///   the blue tick. Opens unless the server locks it ([JuniorMapNode.locked]).
/// * [attendanceCompleted] — ATTENDANCE_COMPLETED: the backend confirmed
///   attendance at its class, no note yet: the grey tick. Opens. Not derived
///   from data yet — the backend has no per-lesson attendance (#414).
/// * [checkInRequired] — CHECK_IN_REQUIRED: the QR mark in the accent frame;
///   a tap opens the scanner. A display state of the map's check-in node
///   while its class is live ([JuniorLearningMap.checkInOpenAt]); never
///   stored on a node.
/// * [locked] — LOCKED: every other lesson — before its class date, or not
///   attended or completed: the grey padlock; does not open.
enum JuniorNodeState { completed, attendanceCompleted, checkInRequired, locked }

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

  /// Whether this lesson opens on a tap — `lessonOpens`. Only
  /// LESSON_COMPLETED and ATTENDANCE_COMPLETED open a lesson (Issue
  /// #417) — never the lesson to continue with on its own — and never one
  /// the server locks.
  bool get opens => lessonOpens(
    locked: locked,
    completed: state == JuniorNodeState.completed,
    isResume: false,
    attended: state == JuniorNodeState.attendanceCompleted,
  );
}

/// The four product states of a lesson on the Junior path (Issue #415,
/// product-approved).
enum LessonPathState {
  /// Before the lesson's own class date: grey padlock; does not open.
  locked,

  /// On its class date while check-in is active: the QR mark in the accent
  /// frame; a tap opens the attendance scanner.
  checkInRequired,

  /// The backend confirmed attendance; no saved note yet: the grey tick; a
  /// tap opens the lesson.
  attendanceCompleted,

  /// The student has a saved, non-empty note on it: the blue tick; a tap
  /// opens the lesson.
  lessonCompleted,
}

/// What a tap on a lesson in [LessonPathState] does.
enum LessonPathTap { nothing, scanner, lesson }

/// The approved state of one lesson (Issue #415), from backend-confirmed
/// facts only:
///
/// * [hasSavedNote] — a persisted, non-empty note (`noteCompletesLesson`).
/// * [attendanceConfirmed] — the backend's attendance record for the
///   lesson's class; null when unknown.
/// * [classDateArrived] and [checkInActive] — the lesson's own class date
///   has come and check-in is open; null when unknown.
///
/// The note decides completion, so a saved note is LESSON_COMPLETED whatever
/// else holds; were it gone, confirmed attendance still shows
/// ATTENDANCE_COMPLETED. Unknown is never success: without confirmed
/// attendance or an open check-in on its date, a lesson is LOCKED.
///
/// The backend sends no per-lesson attendance or class date yet (#414), so
/// the live path passes null for both and shows only what notes and the
/// server's lock establish; this rule is what it switches to once they
/// exist.
LessonPathState lessonPathStateFor({
  required bool hasSavedNote,
  required bool? attendanceConfirmed,
  required bool? classDateArrived,
  required bool? checkInActive,
}) {
  if (hasSavedNote) return LessonPathState.lessonCompleted;
  if (attendanceConfirmed ?? false) return LessonPathState.attendanceCompleted;
  if ((classDateArrived ?? false) && (checkInActive ?? false)) {
    return LessonPathState.checkInRequired;
  }
  return LessonPathState.locked;
}

/// A tap on a lesson in [state]: the scanner on check-in, the lesson once
/// attended or completed — unless the server locks it — and nothing while
/// locked.
LessonPathTap lessonPathTap(
  LessonPathState state, {
  required bool serverLocked,
}) => switch (state) {
  LessonPathState.locked => LessonPathTap.nothing,
  LessonPathState.checkInRequired => LessonPathTap.scanner,
  LessonPathState.attendanceCompleted || LessonPathState.lessonCompleted =>
    serverLocked ? LessonPathTap.nothing : LessonPathTap.lesson,
};

/// How the Junior map draws [state]: LESSON_COMPLETED as a completed node,
/// ATTENDANCE_COMPLETED with the grey tick, CHECK_IN_REQUIRED with the QR
/// mark in the accent frame, LOCKED with the padlock.
JuniorNodeState juniorNodeStateOf(LessonPathState state) => switch (state) {
  LessonPathState.lessonCompleted => JuniorNodeState.completed,
  LessonPathState.attendanceCompleted => JuniorNodeState.attendanceCompleted,
  LessonPathState.checkInRequired => JuniorNodeState.checkInRequired,
  LessonPathState.locked => JuniorNodeState.locked,
};

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

  /// The lesson today's attendance check-in belongs to (Issues #202, #417):
  /// the server's `continue.lesson_id`, while it is LOCKED — neither
  /// completed nor attended — and the server does not lock it. Exactly the
  /// server's; no fallback. An interim association (#202's product
  /// decision): the backend links no class session to a lesson yet (#414).
  /// Null when there is none.
  JuniorMapNode? get checkInNode => nodes
      .where(
        (n) =>
            n.id == continueLessonId &&
            n.state == JuniorNodeState.locked &&
            !n.locked,
      )
      .firstOrNull;

  /// How [node] is drawn at [now] — its four-state look through
  /// [lessonPathStateFor]: CHECK_IN_REQUIRED for the [checkInNode] while
  /// check-in is open ([checkInOpenAt]), otherwise its own state.
  JuniorNodeState displayStateOf(JuniorMapNode node, DateTime now) =>
      juniorNodeStateOf(
        lessonPathStateFor(
          hasSavedNote: node.state == JuniorNodeState.completed,
          attendanceConfirmed: node.state == JuniorNodeState.attendanceCompleted
              ? true
              : null,
          classDateArrived: identical(node, checkInNode) ? true : null,
          checkInActive: identical(node, checkInNode) && checkInOpenAt(now),
        ),
      );

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
