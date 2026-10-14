import '../../home/domain/home_dashboard.dart';
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
/// Every value is the updated reference's (`junior-homepage-u[date.png`,
/// Issue #410): the course title and its 40%, twelve lessons in the order
/// the route draws them — two done, the third open with check-in live, nine
/// locked — and the certificate panel's lines. It carries no `continue` and
/// no certificate `status` — those come from the server, and a sample has
/// none to report.
///
/// The frame draws its check-in node (lesson 3) active, so the sample has a
/// lesson under way — 6 October 2026, 09:00–11:00 ([sampleLessonTime] is
/// inside it) — with no attendance recorded yet. At any other time the node
/// is lesson 3 itself (Issues #202, #410).
JuniorLearningMap sampleJuniorLearningMap() => JuniorLearningMap(
  nextLesson: NextLesson(
    startsAt: DateTime(2026, 10, 6, 9),
    endsAt: DateTime(2026, 10, 6, 11),
  ),
  progress: const JuniorCourseProgress(
    title: 'Prediction and Probabilities',
    percentComplete: 40,
  ),
  attendanceRecorded: false,
  // Lesson 3 is the one to continue with: LOCKED, and the check-in node
  // while its class is live (Issue #417).
  continueLessonId: 3,
  nodes: [
    for (var id = 1; id <= 12; id++)
      JuniorMapNode(
        id: id,
        state: id <= 2 ? JuniorNodeState.completed : JuniorNodeState.locked,
        // Lesson 3's class has come: LOCKED by the four-state rule, not by
        // the server.
        locked: id > 3,
      ),
  ],
  certificate: const JuniorCertificate(
    track: 'Junior',
    courseName: 'AI BootCamp',
    description: 'Earn a Certificate of completion',
  ),
);

/// A moment inside the sample's lesson — when its check-in node is open.
final DateTime sampleLessonTime = DateTime(2026, 10, 6, 10);
