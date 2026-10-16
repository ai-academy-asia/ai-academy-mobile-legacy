/// Whether a lesson may be opened — **the one rule, on every screen**
/// (Issue #410, product-confirmed).
///
/// A lesson opens only when the server leaves it unlocked ([locked] false:
/// its module's first class date has come — the backend's only lock) **and**
/// it is either already [completed] or **the lesson to continue with**
/// ([isResume]: the server's own `continue.lesson_id`, "the first unlocked,
/// uncompleted lesson"). Every other unfinished lesson waits its turn, even
/// once its class date has come.
///
/// Junior Home's nodes, Course Detail's "Continue learning" and the Lesson
/// List's rows all ask this, through `openLesson`. It is a client rule,
/// stricter than the server: the backend locks by class date alone and
/// enforces no order (`BACKEND GAP`, `docs/ai/DATA_AND_API.md` §7).
///
/// [attended] — the backend confirmed the student's attendance at the
/// lesson's class (Issue #415's ATTENDANCE_COMPLETED) — opens it too. No
/// backend data supplies it per lesson yet (#414), so every caller passes
/// false today.
///
/// [reached] — the server's own progress on the lesson (§2.2
/// `lesson.completed`, a `LessonProgress` row): the student has already been
/// through it, so it opens again even without the note that would tick it
/// (Issue #439). The server's continue lesson is the first unlocked lesson
/// without that progress, so every unlocked lesson before it is reached.
/// Only Course Detail passes it; Junior Home's nodes do not, and are
/// unchanged.
bool lessonOpens({
  required bool locked,
  required bool completed,
  required bool isResume,
  bool attended = false,
  bool reached = false,
}) => !locked && (completed || isResume || attended || reached);
