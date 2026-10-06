import '../../course_learning/data/http_course_learning_repository.dart';
import '../../course_learning/domain/course_learning_failure.dart';
import '../../course_learning/domain/course_learning_path.dart';
import '../../course_learning/domain/course_learning_repository.dart';
import '../../course_learning/domain/course_module.dart';
import '../../home/data/enrolled_home_dashboard_repository.dart';
import '../../home/domain/home_dashboard.dart';
import '../../home/domain/home_dashboard_repository.dart';
import '../../home/domain/home_failure.dart';
import '../domain/junior_home_repository.dart';
import '../domain/junior_learning_map.dart';
import 'junior_home_content.dart';

/// Junior Home over the real API.
///
/// **Composed, not new.** This adds no transport and no parsing of its own —
/// both already exist and are reused whole:
///
///  * `HomeDashboardRepository` answers *which* course this student is on.
///    `EnrolledProgram.courseSlug` is the app's existing resolution of that
///    question (`/me/cohorts` + `/cohorts` + `/courses`), and it is why no
///    Junior slug is hardcoded here — there is no such constant in the
///    project, and inventing one would pin every kid to one course.
///  * `CourseLearningRepository` answers *what the course looks like*, over
///    `GET /me/courses/{course_slug}/learning` — the same call, the same
///    `HttpCourseLearningRepository`, that `CourseModuleListScreen` makes.
///
/// So this file is a mapper: [CourseLearningPath] in, [JuniorLearningMap]
/// out. Composing feature repositories this way is the established shape —
/// `EnrolledHomeDashboardRepository` already reaches across `auth`,
/// `cohorts`, `courses` and `enrollments` for the same reason.
///
/// **What the backend does not send stays client-side**, exactly as the
/// contract says: a node's icon and accent come from `order` via the bundled
/// palette, and the certificate panel's artwork and its "Junior" label are
/// the design's. None of that is invented data — it is design the API was
/// never asked to carry.
class ApiJuniorHomeRepository implements JuniorHomeRepository {
  ApiJuniorHomeRepository({
    HomeDashboardRepository? dashboardRepository,
    CourseLearningRepository? courseLearningRepository,
  }) : _dashboard = dashboardRepository ?? EnrolledHomeDashboardRepository(),
       _learning = courseLearningRepository ?? HttpCourseLearningRepository();

  final HomeDashboardRepository _dashboard;
  final CourseLearningRepository _learning;

  @override
  Future<JuniorLearningMap?> getLearningMap() async {
    final String slug;
    final NextLesson? nextLesson;
    try {
      final dashboard = await _dashboard.getDashboard();
      final program = dashboard.program;
      // Enrolled in nothing: an empty screen, not an error — the same
      // reading `HomeController.isEmpty` gives the adult dashboard.
      if (program == null) return null;
      slug = program.courseSlug;
      nextLesson = program.nextLesson;
    } on HomeFailure catch (failure) {
      throw CourseLearningFailure(
        _kindFor(failure.kind),
        detail: 'resolving the enrolled course: ${failure.detail}',
      );
    }

    return juniorMapFrom(
      await _learning.getCourseLearning(slug),
      nextLesson: nextLesson,
    );
  }
}

/// `HomeFailureKind` into this screen's family.
///
/// Total and one-to-one: every kind the dashboard reports has the same
/// meaning in [CourseLearningFailureKind]. A separate `JuniorHomeFailure`
/// enum is deliberately not added — `docs/ai/DATA_AND_API.md` §4 keeps
/// failure families apart *per domain*, and Junior Home's domain is this
/// endpoint, whose failures are already modelled.
CourseLearningFailureKind _kindFor(HomeFailureKind kind) => switch (kind) {
  HomeFailureKind.sessionExpired => CourseLearningFailureKind.sessionExpired,
  HomeFailureKind.network => CourseLearningFailureKind.network,
  HomeFailureKind.server => CourseLearningFailureKind.server,
  HomeFailureKind.unexpected => CourseLearningFailureKind.unexpected,
};

/// One course's learning path, read as the Junior map.
///
/// Public so the mapping can be tested directly against a [CourseLearningPath]
/// built from a contract response, without standing up two repositories.
///
/// [nextLesson] is the dashboard's, from the cohort's schedule — what the
/// check-in node's live state reads (Issue #202).
JuniorLearningMap juniorMapFrom(
  CourseLearningPath path, {
  NextLesson? nextLesson,
}) => JuniorLearningMap(
  nextLesson: nextLesson,
  courseSlug: path.courseSlug,
  progress: JuniorCourseProgress(
    title: path.courseTitle,
    // Displayed, never derived: the contract computes this server-side from
    // lessons, which is why it does not match "completed modules / total".
    percentComplete: path.percentComplete,
  ),
  // `modules` arrives in `order`, and the map draws its nodes in list order
  // along the route, so position is preserved by sorting on `order` rather
  // than trusting the array.
  nodes: [
    for (final module
        in path.modules.toList()..sort((a, b) => a.order.compareTo(b.order)))
      JuniorMapNode(
        id: module.id,
        state: _stateFor(module),
        title: module.title,
      ),
  ],
  certificate: JuniorCertificate(
    track: JuniorHomeContent.track,
    // The one course name the contract carries. The Figma frame happens to
    // show a different placeholder here than in the progress card; both are
    // this field.
    courseName: path.courseTitle,
    description: JuniorHomeContent.certificateDescription,
    status: _certificateStatusFor(path.certificateStatus),
  ),
  continueModuleId: path.continueModuleId,
  continueLessonId: path.continueLessonId,
);

/// Both booleans are server-sent and neither is recomputed here. "Open and
/// unfinished" is what is left once they are both false — see
/// [JuniorNodeState.current].
JuniorNodeState _stateFor(CourseModule module) {
  if (module.completed) return JuniorNodeState.completed;
  if (module.locked) return JuniorNodeState.locked;
  return JuniorNodeState.current;
}

/// The contract's three `certificate.status` values. Anything else — or
/// nothing — is null rather than a guessed fourth state.
JuniorCertificateStatus? _certificateStatusFor(String? status) =>
    switch (status) {
      'not_eligible' => JuniorCertificateStatus.notEligible,
      'eligible' => JuniorCertificateStatus.eligible,
      'issued' => JuniorCertificateStatus.issued,
      _ => null,
    };
