# Course Learning Frontend → Backend Requirements V1

**Type:** Documentation only. No Flutter production code, no backend code, and no API contract was created, changed, or implemented for this task.

## 1. Purpose

Answer one question, from the frontend's side only:

> **What exactly does the current Flutter Course Learning implementation need from the backend in order to replace its sample data?**

This document maps, per feature: what the app renders today, which exact fields its widgets read, which *actions* (read/write) it would have to perform against a real API, and whether any **verified** endpoint supports that today.

It is deliberately the mirror image of `docs/course_learning_backend_api_audit_v2.md`: that document walks the Postman collection and asks "what exists?", this one walks the Flutter code and asks "what is needed?". Neither invents an endpoint.

**Rule applied throughout:** a field that exists in `SampleCourseLearningRepository` is a **frontend requirement**, never a backend contract. Every such field is labelled *"Frontend sample field — backend contract not confirmed."* Sample data is **not** converted into a proposed API schema anywhere in this document.

## 2. Sources

1. **Current Flutter implementation** (read only) — all 35 Dart files under `lib/features/course_learning/`:
   - `domain/` — `course_learning_path.dart`, `course_module.dart`, `lesson.dart`, `course_exercise.dart`, `course_quiz.dart`, `course_learning_repository.dart`
   - `data/` — `sample_course_learning_repository.dart`
   - `presentation/` — `course_module_list_screen.dart`, `lesson_list_screen.dart`, `course_exercise_detail_screen.dart`, `course_quiz_screen.dart`, `course_quiz_result_screen.dart`, the three controllers, `course_learning_strings.dart`
   - `presentation/widgets/` — Assignment (`assignment_tab.dart`, `assignment_attachment_card.dart`), Materials (`course_materials_tab.dart`, `course_material_card.dart`), Note (`note_tab.dart`), Mentor Feedback (`mentor_feedback_card.dart`), Quiz (`quiz_preview_card.dart`, `quiz_progress_header.dart`, `quiz_answer_card.dart`, `quiz_feedback_card.dart`, `quiz_result_question_row.dart`), and the shared Exercise Detail chrome
2. **`docs/course_learning_backend_api_audit_v2.md`** — the latest Postman audit (79-request collection, 2026-09-24). Every "Existing backend evidence" cell below is taken from it; no endpoint outside its verified list is cited as existing.
3. `docs/course_learning_backend_contract_v1.md` and `course_learning_api_requirements_v1.md` — historical context only.

## 3. Current Frontend Architecture

```
CourseModuleListScreen ──► CourseLearningController ──► CourseLearningRepository.getCourseLearning(courseSlug)
   │                                                         └─► CourseLearningPath { modules[] }
   │
   ├─(unlocked module card / "Continue learning")──► CourseExerciseDetailScreen
   │                                                     └─► CourseExerciseDetailController
   │                                                            └─► .getExercise(moduleId) ─► CourseExercise
   │                                                                 ├── Assignment tab  (+ attachment, mentor feedback)
   │                                                                 ├── Course materials tab
   │                                                                 ├── Note tab
   │                                                                 └── QuizPreviewCard (below the tab card)
   │                                                                        └─► CourseQuizScreen ─► CourseQuizResultScreen
   │
   └─ (LessonListScreen exists + is tested, but nothing navigates to it today)
            └─► LessonListController ──► .getLessons(moduleId) ─► List<Lesson>
```

**The single most important architectural fact for backend planning:**

`CourseLearningRepository` (`domain/course_learning_repository.dart`) currently declares **three read methods and zero write methods**:

```dart
Future<CourseLearningPath> getCourseLearning(String courseSlug);
Future<List<Lesson>> getLessons(int moduleId);
Future<CourseExercise> getExercise(int moduleId);
```

Everything the user "writes" today — submitting an assignment, saving a note, downloading a file, answering and submitting a quiz, retrying it — is **local widget state that never leaves the device**. There is no repository method, no controller path, and no error/failure model for any write action. Integrating any write feature therefore requires new repository methods *and* a failure contract (`CourseLearningRepository`'s own doc comment notes it deliberately has no `ApiFailure` model yet, "there is no backend endpoint behind this yet… nothing that can fail the way a real HTTP call can").

Also note: the only sample-data implementation, `SampleCourseLearningRepository`, ignores its arguments entirely — every `courseSlug` returns the same path and every `moduleId` returns the same exercise.

## 4. API Requirement Matrix

Status vocabulary used below:

- **VERIFIED BY CURRENT API** — a verified endpoint in the audit already returns this data; the frontend could consume it today.
- **NOT CURRENTLY SUPPORTED BY VERIFIED API** — a verified endpoint exists *nearby* but factually does not cover this need (e.g. admin certificate-template endpoints vs. a student's issued certificate). A statement about today's verified surface only — **not** a claim that the backend lacks the capability.
- **NEEDS BACKEND CONFIRMATION** — no verified endpoint covers this and no source confirms its absence; the contract must be confirmed before any integration work.

| Feature | Flutter Screen/Model | Frontend Data Needed | Action | Existing Backend Evidence | Status |
|---|---|---|---|---|---|
| 1. Module List | `CourseModuleListScreen` / `CourseLearningPath`, `CourseModule` | course title, description, illustration, percent complete, modules[id, order, title, schedule, icon, accent, completed, locked] | list | `GET /courses/{slug}` supplies title/description/slug only; `Course.curriculum` is a flat string array, not modules | Course identity: **VERIFIED BY CURRENT API**; module list: **NEEDS BACKEND CONFIRMATION**; via `curriculum`: **NOT CURRENTLY SUPPORTED BY VERIFIED API** |
| 2. Lesson / Exercise Detail | `CourseExerciseDetailScreen`, `LessonListScreen` / `CourseExercise`, `Lesson` | caption, title, video duration + badge, summary, extra sections, materials, note, feedback, attachment, quiz | list (lessons), detail (exercise) | none | NEEDS BACKEND CONFIRMATION |
| 3. Course progress | `_ProgressCtaRow`, `_CertificationSection` / `CourseLearningPath.percentComplete` | percent 0–100 | read | none | NEEDS BACKEND CONFIRMATION |
| 4. Lesson progress | `CourseModuleCard`, `LessonListItem` / `.completed`, `.locked` | per-module and per-lesson completed + locked flags | read (+ update, if completion is ever reported by the app) | none | NEEDS BACKEND CONFIRMATION |
| 5. Continue Learning | `_ContinueLearningButton` / `_continueLearningTarget()` | which module/lesson to open next | read (or client rule) | none; today a documented client-side heuristic | NEEDS BACKEND CONFIRMATION |
| 6. Assignment | `AssignmentTab` / no domain model | assignment prompt/description, link field, description field, attachment | detail | none | NEEDS BACKEND CONFIRMATION |
| 7. Assignment submission | `AssignmentTab._submit()` | link text, description text, submission status | submit (write) | none | NEEDS BACKEND CONFIRMATION |
| 8. Assignment resubmission | `AssignmentTab._resubmit()` | same payload as #7 | submit again (write) | none | NEEDS BACKEND CONFIRMATION |
| 9. File upload (student) | not implemented; `exercise_upload.svg` bundled unused | file bytes/handle + submission linkage | upload (write) | admin `PUT /courses/{course_id}/templates/cert` exists but is a course design asset | NOT CURRENTLY SUPPORTED BY VERIFIED API |
| 10. File download (attachment + materials) | `AssignmentAttachmentCard`, `CourseMaterialCard` | file URL or download mechanism, total size, content type | download (read) | admin `GET /courses/{course_id}/templates/cert` exists but is unrelated | NOT CURRENTLY SUPPORTED BY VERIFIED API |
| 11. Course Materials | `CourseMaterialsTab` / `CourseExerciseMaterial` | id, name, size, (needed but absent: URL, type) | list | none | NEEDS BACKEND CONFIRMATION |
| 12. Student Note | `NoteTab` / `CourseExerciseNote` | author identity, message, timestamp; (needed but absent: note id, lesson/student relation) | read, create, update | none | NEEDS BACKEND CONFIRMATION |
| 13. Mentor Feedback | `MentorFeedbackCard` / `AssignmentMentorFeedback` | mentor initials, name, role, message, timestamp | read only | none | NEEDS BACKEND CONFIRMATION |
| 14. Quiz | `QuizPreviewCard` / `CourseQuiz` | quiz title, result-screen title, question count | detail | none | NEEDS BACKEND CONFIRMATION |
| 15. Quiz Questions / Options | `CourseQuizScreen` / `QuizQuestion` | prompt, ordered options, explanation, (currently also `correctOptionIndex` — see §5) | detail | none | NEEDS BACKEND CONFIRMATION |
| 16. Quiz Attempt | `CourseQuizScreen` state | an attempt identity + question set; today there is none | start (write) | none | NEEDS BACKEND CONFIRMATION |
| 17. Quiz Submission | `CourseQuizScreen._continue()` (last question) | chosen option per question | submit (write) | none | NEEDS BACKEND CONFIRMATION |
| 18. Quiz Result / Score | `CourseQuizResultScreen`, `quizScore()` | correct count, total, percent, per-question correctness | read (server-graded) | none | NEEDS BACKEND CONFIRMATION |
| 19. Quiz Retry | `QuizPreviewCard` ("Дахин quiz өгөх") | whether retry is allowed; a fresh attempt | start again (write) | none | NEEDS BACKEND CONFIRMATION |
| 20. Certificate status | `_CertificationSection` | earned / not earned for this student | read | admin cert **template** endpoints only | NOT CURRENTLY SUPPORTED BY VERIFIED API |
| 21. Certificate availability | `_CertificationSection` | eligibility rule / availability flag | read | admin cert **template** endpoints only | NOT CURRENTLY SUPPORTED BY VERIFIED API |
| 22. Certificate download | `_CertificatePreview` | issued certificate file/URL for this student | download (read) | admin cert **template** endpoints only | NOT CURRENTLY SUPPORTED BY VERIFIED API |

*(21 features were requested; file download is split out as row 10 because two separate widgets — the assignment attachment and the materials list — share exactly the same unmet need.)*

## 5. Detailed Requirements

### Module

**Current Flutter implementation**
- Screen/component: `CourseModuleListScreen`, `_Hero`, `_ProgressCtaRow`, `_ModuleList`, `CourseModuleCard`
- Domain model: `CourseLearningPath`, `CourseModule`
- Repository: `CourseLearningRepository.getCourseLearning(String courseSlug)` (read-only)
- Sample source: `SampleCourseLearningRepository.getCourseLearning()` — one fixed path with five modules, returned for any slug
- UI states: loading spinner → loaded list; per card: completed / open / locked (three visual states, two data booleans)

**Frontend data requirements**

`CourseLearningPath`: `courseSlug`, `courseTitle`, `description`, `illustrationAsset`, `percentComplete`, `modules[]`
`CourseModule`: `id`, `order`, `title`, `scheduleLabel`, `iconAsset`, `accentColor`, `completed`, `locked`

- `courseSlug`, `courseTitle`, `description` — the only three with a real counterpart today (`Course.slug`, `Course.title`, `Course.description` from `GET /courses/{slug}`). Note `Course.description` is currently modelled as `Object?` in `course.dart` because its shape was never confirmed, while `CourseLearningPath.description` is a plain `String` — **a real integration must reconcile those two shapes.**
- `illustrationAsset` — *Frontend sample field — backend contract not confirmed.* A bundled asset path (`assets/images/course_learning/how_ai_works.svg`), i.e. a client-side presentation choice; a backend would more plausibly send an image URL or an icon key, which is itself unconfirmed.
- `percentComplete` — *Frontend sample field — backend contract not confirmed.* See "Progress".
- `id`, `order`, `title` — *Frontend sample fields — backend contract not confirmed.* These three are the least controversial and most likely to map 1:1, but nothing confirms it.
- `scheduleLabel` — *Frontend sample field — backend contract not confirmed.* One pre-formatted display string (`"08/04 • Да • 09:00"`). The model's own comment records that the two Figma examples disagree on shape, so no structured date/time/weekday split was chosen. A real API sending raw date/time fields would require new client-side formatting that does not exist yet.
- `iconAsset`, `accentColor` — *Frontend sample fields — backend contract not confirmed.* A bundled SVG path and a hardcoded `Color`. These are almost certainly **not** backend fields; the real question is whether the backend sends any stable per-module identifier the app can map to a bundled icon/colour.
- `completed`, `locked` — *Frontend sample fields — backend contract not confirmed.* Two independent booleans (per `CourseModule.locked`'s doc comment, there is deliberately no "available, not started" third state, because the Figma sample never shows one).

**Backend actions required:** `list` (modules for a course). No create/update/delete — the student app never writes module data.

**Existing backend evidence:** `GET /courses/{slug}` (VERIFIED) covers course identity/title/description only. `Course.curriculum` is verified to exist but the audit found it is a flat array of strings (e.g. `["Week 1","Week 2","Week 3"]`) — **NOT CURRENTLY SUPPORTED BY VERIFIED API** as a module source. Module list itself: **NEEDS BACKEND CONFIRMATION**.

### Lesson / Exercise

**Current Flutter implementation**
- Screen/component: `CourseExerciseDetailScreen` (+ `ExerciseVideoHeader`, `ExerciseInfoSection`, `ExerciseTabs`); `LessonListScreen`/`LessonListItem` exist and are tested but nothing navigates to them
- Domain model: `CourseExercise` (+ `CourseExerciseSection`), `Lesson`
- Repository: `.getExercise(int moduleId)`, `.getLessons(int moduleId)` (read-only)
- Sample source: one fixed "Nesting loops" exercise and one fixed three-lesson list, returned for any `moduleId`
- UI states: loading spinner → loaded; description collapsed (3 lines) / expanded (adds `extraSections`); three tabs

**Frontend data requirements**

`CourseExercise`: `moduleId`, `moduleCaption`, `title`, `durationLabel`, `recordingBadgeLabel`, `summary`, `extraSections[]`, `materials[]`, `note?`, `assignmentFeedback[]`, `assignmentAttachment?`, `quiz?`
`CourseExerciseSection`: `title`, `body`, `bullets[]`
`Lesson`: `id`, `moduleId`, `order`, `title`, `durationLabel`, `completed`, `locked`

- `moduleCaption` (`"Modules 2"`) — *Frontend sample field — backend contract not confirmed.* A pre-formatted caption string, duplicating information the module already carries.
- `durationLabel` (`"24:15"`) and `recordingBadgeLabel` (`"Live Classroom Recording"`) — *Frontend sample fields — backend contract not confirmed.* Both pre-formatted display strings.
- **There is no video URL field anywhere in the model.** The video header renders a flat navy placeholder with an inert play button. A real lesson-video integration needs a playback source the app currently has no field for at all, plus a player package the app does not depend on.
- `summary`, `extraSections[]` — *Frontend sample fields — backend contract not confirmed.* Note the expanded description is structured (`title` + `body` + `bullets[]`), not one rich-text blob, so a backend sending HTML/Markdown would not drop into this model unchanged.
- **Key relational gap:** `getExercise()` is keyed by `moduleId`, not `Lesson.id` — the repository's own doc comment flags this. Every lesson in a module currently resolves to the same exercise. Re-keying is a prerequisite for a real Module→Lesson→Exercise hierarchy.

**Backend actions required:** `list` (lessons in a module), `detail` (one lesson/exercise's content).

**Existing backend evidence:** none. **NEEDS BACKEND CONFIRMATION.**

### Progress

**Current Flutter implementation**
- Screen/component: `_ProgressCtaRow` (rendered twice: hero + certification footer), `CourseModuleCard._CompletedCheck`, `LessonListItem`
- Domain model: `CourseLearningPath.percentComplete` (`int`, 0–100); `CourseModule.completed`/`.locked`; `Lesson.completed`/`.locked`
- Sample source: hand-authored constants (`percentComplete: 30`; modules 1–2 completed, 3–5 locked)
- UI states: a `LinearProgressIndicator` at `percentComplete / 100` plus a `"N% complete"` label

**Frontend data requirements**
- Course-level: a single integer percentage. *Frontend sample field — backend contract not confirmed.*
- Per-module and per-lesson: `completed`, `locked` booleans. *Frontend sample fields — backend contract not confirmed.*
- **Deliberate non-derivation:** `CourseLearningPath`'s doc comment records that `percentComplete` is stored rather than computed from module counts, because the Figma reference shows "30% complete" against 2-of-5 completed modules (which would be 40%). The frontend therefore needs the percentage as **its own value**, not something it can calculate — unless the backend confirms a formula.

**Backend actions required:** `read` (course progress, per-module/lesson progress). A `update`/`report-completion` action is **not** currently needed: nothing in the app ever marks a lesson complete (there is no video player to finish, no "mark done" control).

**Existing backend evidence:** none — no progress field, endpoint, or query parameter was found anywhere in the verified collection. **NEEDS BACKEND CONFIRMATION.**

### Continue Learning

**Current Flutter implementation**
- Component: `_ContinueLearningButton`, fed by the top-level function `_continueLearningTarget()` (`course_module_list_screen.dart:163-171`)
- Rule today: first module that is neither completed nor locked; else the last completed module; else `null` (button disabled)
- Its own doc comment explicitly labels this **"A frontend placeholder, not a confirmed backend rule."**

**Frontend data requirements:** either (a) a server-selected target module/lesson id, or (b) confirmation that the client-side rule is acceptable. Nothing more.

**Backend actions required:** `read` — *only if* the rule is server-side. If the backend confirms the client rule is fine, this needs **no endpoint at all** and only depends on progress data.

**Existing backend evidence:** none. **NEEDS BACKEND CONFIRMATION** (specifically: whose responsibility the rule is).

### Assignment

**Current Flutter implementation**
- Component: `AssignmentTab` (+ `ExerciseTextField` ×2, `ExerciseSubmitButton`, `_AssignmentSuccessCard`, `_ResubmitButton`, `AssignmentAttachmentCard`, `MentorFeedbackCard`)
- Domain model: **none** — there is no `Assignment` class. The tab is driven entirely by widget state plus `CourseExercise.assignmentAttachment` and `.assignmentFeedback`
- Repository: none (no write method exists)
- Sample source: `_AssignmentStage` enum, local `TextEditingController`s, and a canned `assignmentFeedback` list
- UI states: `notSubmitted` (editable form) → `pendingReview` (fields locked, ~900 ms cosmetic `Future.delayed`) → `submitted` (success card + Resubmit). Submit is enabled only when both text fields are non-blank **and** (when an attachment exists) it has finished its simulated download

**Frontend data requirements**

*Assignment metadata:* **the app currently displays none** — there is no assignment title, instructions, due date, or max-score field anywhere. The tab shows only input controls. A real assignment API would likely carry metadata the UI has no place for yet.

*Submission payload the UI can produce today:*
- link text (single-line, free text, unvalidated — placeholder `"Link оруулна уу"`)
- description text (multiline, free text — floating label `"Тайлбар"`)
- optionally, a reference to the attachment the student downloaded (the app has no way to attach an *uploaded* file)

*Submission status the UI can render today:* exactly three states, and `pendingReview` is a fixed ~900 ms client-side delay, not a server state. *Frontend sample behaviour — backend contract not confirmed.*

*Resubmission:* `_resubmit()` simply returns the stage to `notSubmitted` with the previously typed text preserved. **The app does not model resubmission as a different API action** — it would call the same submit action again. Whether the backend treats it as a new submission, a version, or an update is unconfirmed.

*Submitted file:* **not supported by the app at all** — see "File Upload".

**Backend actions required:** `detail` (fetch assignment + current submission status), `submit` (create submission), `submit again` (resubmission — shape unconfirmed). No delete/withdraw action is needed; the UI has no such control.

**Existing backend evidence:** none. **NEEDS BACKEND CONFIRMATION.**

### File Upload

**Current Flutter implementation**
- **Upload: not implemented anywhere.** `assets/images/course_learning/exercise_upload.svg` is bundled but referenced by no widget. There is no file picker dependency in `pubspec.yaml`, no upload control, and no field on any model to hold a chosen file.
- **Download: simulated.** `AssignmentAttachmentCard` runs a `Timer.periodic` for 10 ticks × 150 ms and derives a byte-progress label by parsing the sample `sizeLabel` string (`_downloadedLabel()` → e.g. `"102 KB / 1 MB"`). `CourseMaterialCard` simply flips a local `_downloaded` boolean. **Nothing is ever fetched over the network.**

**Frontend data requirements**
- To download: a file URL (or a download endpoint + auth scheme), a real total size (currently only a pre-formatted `sizeLabel` string exists), and a content type (currently the UI hardcodes `", PDF"` — see §6).
- To upload: a submission-scoped upload target, accepted types/size limits, and a returned file identifier to attach to the submission. **All of this is new surface for the app**, not just a new endpoint: a file picker, permissions, progress/cancel plumbing against a real transfer, and failure handling would all have to be added.

**Backend actions required:** `download` (student-facing), `upload` (student-facing).

**Existing backend evidence:** `PUT`/`GET`/`DELETE /courses/{course_id}/templates/cert` are verified, but the audit records them as admin-side **course certificate/contract template** management (`course:edit`), explicitly not a student submission file. **NOT CURRENTLY SUPPORTED BY VERIFIED API** (and the student-facing contract **NEEDS BACKEND CONFIRMATION**).

### Course Materials

**Current Flutter implementation**
- Component: `CourseMaterialsTab` → `CourseMaterialCard` (one 329×72 row each)
- Domain model: `CourseExerciseMaterial { id, name, sizeLabel }` — **the same class is reused for the Assignment attachment**, so any change to it affects both features
- Sample source: two fixed materials (`"Course material 1"`, `"10 MB"` / `"12 MB"`)
- UI states: idle (download glyph) → downloaded (green check, button inert). Purely local; tapping fetches nothing

**Frontend data requirements**

| UI need | Model field today | Status |
|---|---|---|
| material id | `id` (`int`) | *Frontend sample field — backend contract not confirmed.* |
| title / filename | `name` (one string, doubling as both) | *Frontend sample field — backend contract not confirmed.* |
| type | **absent** — the Assignment attachment's "Complete" row hardcodes `", PDF"` | needed, no field exists |
| size | `sizeLabel` — a pre-formatted display string (`"10 MB"`), no byte count | *Frontend sample field — backend contract not confirmed.* |
| download URL / mechanism | **absent** | needed, no field exists |
| download state | local widget boolean only; not persisted, not per-device, not server-known | frontend-only concept |

**Backend actions required:** `list` (materials for a lesson/module/course — the scope itself is unconfirmed), `download`.

**Existing backend evidence:** none. **NEEDS BACKEND CONFIRMATION.**

### Student Note

**Current Flutter implementation**
- Component: `NoteTab`, with the current note lifted into `CourseExerciseDetailScreen._note` so it survives a tab switch (but not leaving the screen)
- Domain model: `CourseExerciseNote { authorInitials, authorName, authorLabel, message, timestampLabel }`
- Repository: none — `onSave` is a `ValueChanged` callback into parent widget state; nothing is persisted
- Sample source: one fixed note, or `null` for the empty state
- UI states: empty (textarea + disabled Submit) → saved (note card + "Засах") → editing (textarea pre-filled). Submit is gated on non-blank, trimmed text

**Frontend data requirements**

| Requested field | Present in the app today? |
|---|---|
| note id | **No.** The model has no identifier at all. |
| student relation | **No** — implied by `authorLabel: "Me"` only |
| lesson/exercise relation | **No** — implied by which screen holds it |
| content | Yes — `message` |
| created_at | **No** — only `timestampLabel`, a pre-formatted string (`"Today, 14:20"`, or the literal `"Just now"` for a freshly saved note, chosen precisely because the app has no real clock source it trusts). *Frontend sample field — backend contract not confirmed.* |
| updated_at | **No** — editing overwrites `timestampLabel` with `"Just now"`; the app draws no created/updated distinction |

Display-only extras the UI does need: `authorInitials` (rendered in the avatar circle), `authorName`, `authorLabel`.

**Backend actions required:** `read` (existing note for this lesson), `create` (first save), `update` (edit). No delete — the UI has no delete control.

**Existing backend evidence:** none. **NEEDS BACKEND CONFIRMATION.**

### Mentor Feedback

**Current Flutter implementation**
- Component: `MentorFeedbackCard`, rendered at the bottom of the Assignment tab in every stage
- Domain model: `AssignmentMentorFeedback { mentorInitials, mentorName, mentorRole, message, timestampLabel }`
- Sample source: `CourseExercise.assignmentFeedback` — a **list** indexed by how many times the student has submitted (`_resolvedSubmissions`), clamped to the last entry. *Frontend sample behaviour — backend contract not confirmed:* this "one canned reply per submission" sequencing is a demo device, not a proposal for how feedback should be modelled.
- UI states: empty ("No feedback yet") → populated (one card)

**Frontend data requirements vs. the requested list**

| Requested field | Present today? |
|---|---|
| mentor id | **No** — the model carries no identifier |
| mentor name | Yes — `mentorName` |
| mentor role | Yes — `mentorRole` (e.g. `"Lead Mentor"`) |
| avatar | **No image URL.** The card draws a blue circle containing `mentorInitials`. The app needs *initials*, not an avatar image — adding an avatar URL would be new UI, not just a new field. |
| feedback text | Yes — `message` |
| created_at | **No** — only `timestampLabel`, a pre-formatted string. *Frontend sample field — backend contract not confirmed.* |

**Backend actions required:** `read` only. Confirmed by inspection: there is no compose field, no submit control, and no callback for feedback anywhere in the widget — the student can only view it. (Whether students *should* be able to author feedback remains an open product question inherited from the requirements doc; the current frontend does not need it.)

**Existing backend evidence:** none. **NEEDS BACKEND CONFIRMATION.**

### Quiz

**Current Flutter implementation**
- Components: `QuizPreviewCard` (a card below the tab card on Exercise Detail) → `CourseQuizScreen` (full screen, one question at a time) → `CourseQuizResultScreen` (full screen)
- Domain model: `CourseQuiz { title, resultTitle, questions[] }`, `QuizQuestion { prompt, options[], correctOptionIndex, explanation }`, plus the top-level `quizScore(quiz, answers)` helper
- Repository: none — the quiz arrives embedded in `CourseExercise.quiz`; no quiz-specific fetch or write method exists
- Navigation/state: the preview pushes the quiz screen and awaits a `({int correct, int total})` record; the last question `pushReplacement`s the result screen, passing that record as the replaced route's result; "Дуусгах" pops back. The score is held by `CourseExerciseDetailScreen._quizResult` and is **lost when the screen is disposed**
- UI states: preview-start → preview-result (percent + "Дахин quiz өгөх"); per question: unanswered (Continue disabled) → answered-correct (green border/check + explanation card) → answered-wrong (red border/✗, correct letter named, explanation card); result: percent, summary line, per-question ✓/✗ list

**Per-area requirements**

- **Quiz metadata:** `title` (preview heading), `resultTitle` (a *different* string shown on the result screen), and the question **count** (rendered as `"Total N questions"`, derived from `questions.length`, not a separate field). `resultTitle` is *a frontend sample field — backend contract not confirmed*: it exists only because the reference shows a different caption on the result screen. There is **no quiz id** in the model.
- **Questions:** `prompt` plus an **ordered** `options` list. Order matters — the UI derives the displayed letter from the index (`String.fromCharCode(65 + i)` → A/B/C/D), so a backend that returns unordered options, or option objects with their own ids, would not drop in unchanged. There is **no question id** and **no option id**.
- **Options:** plain `List<String>`. Single-select only; the UI has no multi-select, free-text, or ordering question type.
- **Correct-answer handling — the important one.** Today `QuizQuestion.correctOptionIndex` sits in the client model and `quizScore()` grades entirely on-device. **This is a demo-only arrangement and must not be treated as a production contract:** shipping the answer key to the client before an attempt is graded would let a student read it off the wire. What the frontend actually *needs* is: (a) to know, immediately after answering a question, whether that answer was right and what the explanation is — because the UI reveals feedback inline, before the next question — and (b) a final per-question correct/incorrect list and score. **How the backend supplies that securely (per-answer grading round-trip, signed attempt, deferred reveal, or something else) is entirely for the backend to define — NEEDS BACKEND CONFIRMATION.** This document deliberately proposes no shape for it.
- **Explanation:** shown inside the feedback card after answering. Needed per question, and — given the point above — needed *at the moment an answer is graded*, not necessarily up-front.
- **Attempt:** the app has **no attempt concept** — no attempt id, no started-at, no expiry, no resume. Starting a quiz is just a `Navigator.push`. If the backend models attempts, all of that is new client surface.
- **Answer submission:** the app currently sends nothing. It holds `Map<int,int>` (question index → option index) locally. A real flow could be per-answer or batched at the end; the UI's inline feedback makes **per-answer** the more natural fit, but this is unconfirmed.
- **Score:** computed on-device (`quizScore()`), displayed as `correct/total` and as a rounded percentage in two places. Needs to come from the server once grading moves server-side.
- **Result:** per-question correctness for the result list. Note the list rows render the generic label `"Асуулт"` for every row (matching the reference), **not** each question's own prompt — so the result screen needs only correctness per index, not the question text again.
- **Retry:** "Дахин quiz өгөх" re-pushes the same screen with cleared local state. The frontend needs to know **whether retry is permitted** (and, if attempts are limited, how many remain) — it currently assumes unlimited retries. *Frontend sample behaviour — backend contract not confirmed.*
- **Persistence:** the completed-quiz score lives only in `CourseExerciseDetailScreen._quizResult`; navigating away and back resets the preview card to "Start quiz". Any real integration needs the last attempt's result to be readable on load.

**Backend actions required:** `detail` (quiz + questions/options), `start` (attempt — if attempts are modelled), `submit` (answers, per-answer or batched), `read result` (score + per-question correctness), `retry` (new attempt, subject to a confirmed policy).

**Existing backend evidence:** none for any of the six quiz rows. **NEEDS BACKEND CONFIRMATION.**

### Certificate

**Current Flutter implementation**
- Component: `_CertificationSection` + `_CertificatePreview` in `CourseModuleListScreen`
- Domain model: **none**
- Sample source: two bundled PNGs (`certificate.png` over `certificate_backround.png`) plus two fixed strings (`"CERTIFICATION"`, `"Earn a Certificate of completion"`)
- UI states: **exactly one.** The section renders identically regardless of progress; there is no earned/not-earned branch and no download control at all

**Frontend data requirements**
- eligibility/status: whether this student has earned it (would introduce a second UI state that does not exist yet)
- availability: when/whether it becomes downloadable
- certificate metadata: at minimum an issued date or title, if the preview is ever to show real data instead of a static image
- download URL/file: **no download affordance exists in the UI today** — adding one is new UI work, not just a new field

**Backend actions required:** `read` (status/availability), `download` (issued file) — both student-scoped.

**Existing backend evidence:** the verified collection contains only `GET`/`PUT`/`DELETE /courses/{course_id}/templates/cert` (admin, `course:edit`), which manage the **course's certificate template**, not a student's issued certificate. Two related fields also exist on the course object itself — `cert_template_name` and `has_cert_template` (confirmed field *names* per `course.dart`'s own doc comment and the v1 contract investigation, not per the v2 Postman audit, which records no example responses) — but both are course-level, not student-level. **NOT CURRENTLY SUPPORTED BY VERIFIED API**; the student-facing contract **NEEDS BACKEND CONFIRMATION**.

## 6. Frontend Sample Data → Backend Contract Gaps

Every item below is a **frontend sample assumption**, not a backend field. None should be copied into an API contract without confirmation.

**Pre-formatted display strings that hide structured data**
1. `CourseModule.scheduleLabel` — `"08/04 • Да • 09:00"`; no separate date/time/weekday fields, and no client-side formatter exists to build one from raw values.
2. `CourseExercise.durationLabel` / `Lesson.durationLabel` — `"24:15"`; no seconds/duration value.
3. `CourseExercise.moduleCaption` — `"Modules 2"`; duplicates module identity as prose.
4. `CourseExercise.recordingBadgeLabel` — `"Live Classroom Recording"`; a free string, not a recording-type enum.
5. `CourseExerciseMaterial.sizeLabel` — `"10 MB"`; no byte count. `AssignmentAttachmentCard._downloadedLabel()` *parses this string back* with a regex to fake byte progress — a demo device that would be replaced wholesale by a real byte count.
6. `CourseExerciseNote.timestampLabel` / `AssignmentMentorFeedback.timestampLabel` — `"Today, 14:20"` / `"Just now"`; no machine-readable timestamp anywhere.

**Hardcoded UI strings standing in for missing fields**
7. `CourseLearningStrings.attachmentTypeLabel()` renders `"$sizeLabel, PDF"` — **"PDF" is hardcoded**; there is no file-type field on any model.
8. `NoteTab` hardcodes the note author as `"БП"` / `"Болд Батаа"` (`_studentInitials`/`_studentName` constants) for newly written notes, rather than reading the signed-in user. A real integration should source this from the authenticated user (`GET /auth/me` is verified, though the app does not use it here today).

**Missing identity fields (nothing to key a write against)**
9. No `Assignment` model or id; no submission id; no note id; no mentor-feedback id; no quiz id; no question id; no option id; no attempt id. Of the whole feature, only `CourseModule.id`, `Lesson.id` and `CourseExerciseMaterial.id` exist — and all three are hand-authored sample integers.

**Client-side presentation choices unlikely to be backend fields**
10. `CourseModule.iconAsset` + `accentColor`, `CourseLearningPath.illustrationAsset` — bundled asset paths and hardcoded colours.
11. `CourseModule.locked` / `Lesson.locked` — modelled as data, but may well be a rule the backend computes, or one the client derives from progress.

**Behavioural fakes that look like contract**
12. `AssignmentTab`'s ~900 ms `pendingReview` delay — cosmetic only; not a server state.
13. `CourseExercise.assignmentFeedback` as an **indexed sequence** consumed one entry per submission — a demo device for showing feedback states, not a feedback model.
14. `AssignmentAttachmentCard`'s 10-tick timer "download" — no transfer occurs.
15. `CourseMaterialCard._downloaded` — a per-widget boolean, reset on rebuild; not device state, not server state.
16. **`QuizQuestion.correctOptionIndex` — the client-side answer key.** Flagged separately and emphatically in §5: this exists so the offline demo can grade itself, and must not become a production response field.
17. `CourseQuiz.resultTitle` — a second, unrelated title string invented for one screen.
18. Unlimited quiz retries — assumed, never confirmed.
19. Quiz result persistence — held in one screen's `State`; lost on dispose.

**Structural**
20. `SampleCourseLearningRepository` ignores `courseSlug` and `moduleId` entirely — every course and module yields identical content. No caller has ever exercised a per-id code path.
21. `CourseLearningRepository` has **no write methods and no failure model**. Every write feature below needs both added before it can be integrated.

## 7. Backend Confirmation Questions

Only questions that remain unanswered after reading the current code and the latest Postman audit.

**Structure**
1. Module endpoint + response shape; does a module carry its own progress/lock state, or does the client derive it?
2. Lesson endpoint + response shape; is the Course→Module→Lesson hierarchy 1:N:N?
3. Should `getExercise` be re-keyed from `moduleId` to `lessonId` — i.e. is exercise content per-lesson?
4. Is there any stable per-module key the client can map to its bundled icon/accent colour, or will the backend send an image URL?

**Progress**
5. Course progress percentage: server-computed value, or a formula the client should apply? (The frontend cannot derive today's value from module counts — see §5.)
6. Are `completed`/`locked` server-sent, or client-derived from progress?
7. Does the app ever need to *report* progress (e.g. lesson completion), or is progress written only by other systems?
8. Continue Learning: server-selected target, or is the existing client heuristic acceptable?

**Assignment**
9. Assignment metadata shape — does an assignment carry a title/instructions/due date the UI would need to display (it currently shows none)?
10. Submission payload: are `link` and `description` the real fields, and is either required?
11. Is resubmission the same action as submission, a new version, or an update to an existing submission?
12. What submission statuses exist server-side, and how do they map onto the app's three states?
13. Student file upload: endpoint, accepted types/sizes, and how an uploaded file is attached to a submission.

**Materials**
14. Are materials scoped to course, module, or lesson?
15. Download mechanism: direct URL, signed URL, or an authenticated endpoint? Is a byte count and content type available (both are currently missing client-side)?

**Note**
16. Note identity and scoping (student + lesson?), plus real `created_at`/`updated_at`.
17. One note per student per lesson, or many?

**Mentor feedback**
18. Feedback shape and identity, real timestamp, and whether an avatar image exists (the app renders initials today).
19. Is feedback tied to a specific submission, or to the assignment/lesson as a whole?

**Quiz**
20. **How should grading work securely?** The frontend needs per-answer correctness *immediately after each answer* (it reveals feedback inline) plus a final per-question result list — without the client ever holding the answer key. The mechanism is entirely the backend's to define.
21. Does the backend model attempts (id, start, expiry, resume)?
22. Per-answer submission or batched-at-the-end?
23. Is retry allowed, and is there an attempt limit the UI must show?
24. Should a previous attempt's score be readable on load (so the preview card can show it after the screen is disposed)?

**Certificate**
25. Student-facing certificate status/availability/download — distinct from the verified admin template endpoints.
26. What determines eligibility (progress threshold, exam, final project)?

**Cross-cutting**
27. Which of these endpoints require auth, and which role/permission scopes apply to a student token?
28. What is the error contract (status codes, body shape) for Course Learning endpoints — the feature currently has no failure model at all?

## 8. Suggested Integration Order

Ordered by frontend dependency first, then by how much already-built UI each step un-mocks. **No step below can start until its contract is confirmed** — nothing in Course Learning is currently integratable.

**Step 0 — prerequisite refactor (no backend needed).** Add a failure model and write methods to `CourseLearningRepository`, mirroring `CourseRepository`'s existing `ApiFailure` contract, and give the three controllers an error state. Every later step depends on this, and it can be done against sample data today.

1. **Module list** *(unblocks: Module List screen, and the identity every later call needs)* — depends on Q1, Q4. The course-identity half of this screen is already **VERIFIED BY CURRENT API** (`GET /courses/{slug}`), so only the module list itself is blocking.
2. **Lesson list + exercise detail** *(unblocks: Lesson List screen, all of Exercise Detail)* — depends on Q2, Q3. Settles whether `getExercise` is re-keyed, which every tab inherits.
3. **Progress + Continue Learning** *(unblocks: both progress rows, module/lesson completed+locked states, the CTA)* — depends on Q5–Q8. Cheap once #1/#2 land, and it is what makes the screens stop looking static.
4. **Course materials** *(unblocks: the Materials tab and, via the shared model, the assignment attachment)* — depends on Q14, Q15. Sequenced before assignment because `CourseExerciseMaterial` is shared by both, and materials is read-only — the smallest first real download.
5. **Student note** *(unblocks: the Note tab, end to end)* — depends on Q16, Q17. The simplest full read+create+update cycle in the feature; a good first write integration.
6. **Assignment + submission + mentor feedback** *(unblocks: the whole Assignment tab)* — depends on Q9–Q12, Q18, Q19. Feedback is read-only and rides along with submission status.
7. **Student file upload** *(unblocks: a real submitted file; also upgrades #4's download)* — depends on Q13. Sequenced last among assignment work because it needs genuinely new client surface (file picker, permissions, real transfer progress), not just an endpoint.
8. **Quiz** *(unblocks: preview card, question screen, result screen)* — depends on Q20–Q24. Deliberately late: the offline implementation already demonstrates the full flow, so this buys correctness and integrity rather than new capability — and **Q20 (secure grading) must be answered first**, because the answer determines the shape of every quiz screen's data flow.
9. **Certificate (student-facing)** *(unblocks: a real certification section)* — depends on Q25, Q26, and on #3 being complete to know when it is earned. Also needs new UI (an earned/not-earned state and a download control), both of which are absent today.
10. **Lesson video/recording** — not in the 21 features above but worth flagging: the video header has no URL field and the app has no player dependency. Whenever this is contracted, it is a larger piece of work than a field addition.
