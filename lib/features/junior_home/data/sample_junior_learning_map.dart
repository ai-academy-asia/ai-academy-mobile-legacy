import '../domain/junior_learning_map.dart';

/// The one hand-authored map the Junior Home screen shows today.
///
/// **Static presentation data, not a contract.** Issue #98 is UI only — there
/// is no Junior endpoint, and none is invented here. Every value is
/// transcribed from the Figma frame this screen was built against: the course
/// title and its 40%, five nodes in the order the route draws them, and the
/// certificate panel's three lines.
///
/// Kept in `data/` behind a plain function rather than a repository interface
/// on purpose: adding `JuniorHomeRepository` now would be inventing a
/// contract for a backend that has not been specified. When one is, this
/// function is what an implementation replaces.
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
