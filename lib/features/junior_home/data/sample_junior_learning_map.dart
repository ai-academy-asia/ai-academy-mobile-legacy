import '../domain/junior_learning_map.dart';

/// The Figma frame's own map, transcribed field by field.
///
/// **Tests and previews only — production does not read this.** Junior Home
/// now loads from `GET /me/courses/{course_slug}/learning` through
/// `ApiJuniorHomeRepository`; this is what `FakeJuniorHomeRepository` hands
/// back so the screenshot test keeps capturing the exact frame its golden was
/// taken from, and so the widget tests have content with all three node
/// states in it.
///
/// Every value is the reference frame's: the course title and its 40%, five
/// nodes in the order the route draws them, and the certificate panel's
/// lines. It carries no `continueModuleId` and no certificate `status` —
/// those come from the server, and a sample has none to report.
JuniorLearningMap sampleJuniorLearningMap() => const JuniorLearningMap(
  progress: JuniorCourseProgress(
    title: 'Prediction and Probabilities',
    percentComplete: 40,
  ),
  nodes: [
    JuniorMapNode(id: 1, state: JuniorNodeState.completed),
    JuniorMapNode(id: 2, state: JuniorNodeState.completed),
    JuniorMapNode(id: 3, state: JuniorNodeState.current),
    JuniorMapNode(id: 4, state: JuniorNodeState.locked),
    JuniorMapNode(id: 5, state: JuniorNodeState.locked),
  ],
  certificate: JuniorCertificate(
    track: 'Junior',
    courseName: 'AI BootCamp',
    description: 'Earn a Certificate of completion',
  ),
);
