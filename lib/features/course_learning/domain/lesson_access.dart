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
bool lessonOpens({
  required bool locked,
  required bool completed,
  required bool isResume,
}) => !locked && (completed || isResume);
