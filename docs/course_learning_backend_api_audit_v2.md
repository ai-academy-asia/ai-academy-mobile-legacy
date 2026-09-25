# Course Learning Backend API Audit V2

**Type:** Investigation + documentation only. No production (Flutter or backend) code was changed for this task.

## 1. Purpose

Re-check the **current** AI Academy Asia Postman collection against every Course Learning feature the mobile app's Exercise Detail flow either already implements with sample data or will eventually need, and record, per feature, exactly one of:

- **VERIFIED EXISTING** — the collection documents a real endpoint for it.
- **VERIFIED MISSING** — the collection (or another authoritative source) explicitly states the functionality does not exist.
- **NEEDS BACKEND CONFIRMATION** — no endpoint is present, and nothing explicitly confirms it is truly absent from the backend. Per the original requirements doc's own rule, **"not present in Postman" is never treated as "confirmed absent."**

This is a re-audit, not a rewrite from scratch: §7 below calls out everything that differs from the previous investigation (`docs/course_learning_backend_contract_v1.md`).

## 2. Sources

1. **`AIAA Backend (prod).postman_collection.json`** — the current collection, located at `/Users/bayarmaa/Documents/internship/ai-academy/AIAA Backend (prod).postman_collection.json` (one level above this repo), last modified 2026-09-24. Parsed programmatically (Postman Collection v2.1.0 schema): **79 requests**, 0 of which carry a saved example response. Treated as the primary source of truth for **endpoint existence**, per this task's instructions.
2. `course_learning_api_requirements_v1.md` (original requirements doc, Mongolian) — historical context for what the Figma Course Learning flow needs; terminology (`§4.x`, `§6`) below refers to it.
3. `docs/course_learning_backend_contract_v1.md` (previous audit) — historical baseline; re-verified below, not assumed current.
4. Current Flutter implementation (read only, not modified):
   - `lib/features/courses/domain/course.dart`, `lib/features/courses/data/http_course_repository.dart`
   - `lib/features/cohorts/domain/cohort.dart`, `lib/features/cohorts/data/http_cohort_repository.dart`
   - `lib/features/course_learning/domain/*.dart` (`course_module.dart`, `lesson.dart`, `course_learning_path.dart`, `course_exercise.dart`, `course_quiz.dart`, `course_learning_repository.dart`)
   - `lib/features/course_learning/data/sample_course_learning_repository.dart`
   - `lib/features/course_learning/presentation/course_module_list_screen.dart`, `course_exercise_detail_screen.dart`, and the Assignment/Course Materials/Note/Mentor Feedback/Quiz widgets under `presentation/widgets/`

**Important source-transparency note:** the Postman collection JSON itself stores **zero example responses** for all 79 requests (verified by inspecting every `item.response` array). Every "confirmed response shape" claim below for `Course`/`Cohort`/`Auth` therefore does **not** come from this JSON file — it comes from the existing Flutter code's own doc comments (`course.dart`, `cohort.dart`), which state those shapes were checked against a live captured response at integration time. For every Course Learning feature that has no endpoint at all, there is by definition no response to describe either way.

## 3. Existing Verified APIs

Carried over from the previous audit, unchanged — re-confirmed present in the current collection (path, method and auth all re-checked against the live JSON):

| Area | Method | Endpoint | Auth | Notes |
|---|---|---|---|---|
| Login | POST | `/auth/login` | `noauth` (explicit) | Body: `{ "email", "password" }` |
| Refresh token | POST | `/auth/refresh` | `noauth` (explicit) | Body: `{ "refresh_token" }` |
| Current user | GET | `/auth/me` | Inherits collection Bearer | No request body/params |
| Change password | POST | `/auth/change-password` | Inherits collection Bearer | Body: `{ "current_password", "new_password" }` |
| Logout (this device) | POST | `/auth/logout` | `noauth` (explicit) | Body: `{ "refresh_token" }` |
| Logout all | POST | `/auth/logout-all` | Inherits collection Bearer | No body |
| Course list | GET | `/courses` | `noauth` (explicit) | `{ "courses": [...] }` |
| Course detail | GET | `/courses/{slug}` | `noauth` (explicit) | Course object, no envelope; 404 on unknown slug |
| Cohort list | GET | `/cohorts` | `noauth` (explicit) | `{ "cohorts": [...] }`, each with nested `course{id,slug,title_en,title_mn}` |
| Cohort detail | GET | `/cohorts/{cohort_id}` | `noauth` (explicit) | Present; not yet consumed by any Flutter repository |
| My cohorts | GET | `/me/cohorts` | Inherits collection Bearer | Consumed by `HomeDashboardRepository`/cohort features |
| Enroll self | POST | `/cohorts/{cohort_id}/enroll` | Inherits collection Bearer; description explicitly says **"Needs a STUDENT access token. Cohort must be 'open' with seats available."** | |
| Cancel own enrollment | DELETE | `/cohorts/{cohort_id}/enroll` | Inherits collection Bearer | Present; not yet consumed |

None of these carry Module, Lesson, progress, assignment, material, note, feedback, quiz, or student-certificate data — same conclusion as the previous audit, re-verified against the current 79-request collection, not just assumed carried over.

## 4. Course Learning API Audit

| # | Feature | Endpoint | Method | Status | Request | Response | Flutter compatibility | Notes |
|---|---|---|---|---|---|---|---|---|
| 1 | Modules | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — `CourseModule` is 100% sample data | `Course.curriculum` exists but is a flat string array (see §5), not a Module API |
| 2 | Lessons / Exercises | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — `Lesson`/`CourseExercise` are 100% sample data | No lesson-shaped endpoint anywhere in the 79 requests |
| 3 | Course → Module → Lesson relationship | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — app currently has no real Lesson List; `CourseExercise` is keyed 1:1 by `moduleId` | Cardinality (1:N:N vs. something else) unconfirmed |
| 4 | Course progress | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — `CourseLearningPath.percentComplete` is a hand-authored int | No endpoint computes or returns this anywhere in the collection |
| 5 | Lesson progress | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — `CourseModule.completed`/`.locked` are hand-authored sample booleans | |
| 6 | Continue Learning | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — `_continueLearningTarget()` is a **client-side heuristic**, not a backend rule (see §5) | Requirements doc `§4.3` explicitly defers "which rule" question |
| 7 | Assignment | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — `AssignmentTab` fields are unwired to any network call | |
| 8 | Assignment submission | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — Submit only ever drives local `_AssignmentStage` state | |
| 9 | Assignment resubmission | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — "Resubmit" reopens the same local form; no distinct resubmit endpoint is assumed | Flutter does not model resubmission as a different action from submission at the API layer |
| 10 | File upload (student-facing) | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — attachment "download" is a local `Timer`, no real transfer | An **admin-side** template upload exists (`PUT /courses/{course_id}/templates/cert`) but is unrelated — see §5 |
| 11 | Course Materials | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — `CourseExerciseMaterial{id,name,sizeLabel}` is sample data, no URL field | |
| 12 | Student Notes | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — `NoteTab` reads/writes only in-memory state | |
| 13 | Mentor Feedback | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — `MentorFeedbackCard` renders canned `AssignmentMentorFeedback` sample entries | |
| 14 | Quiz | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — `CourseQuiz` is entirely sample data | |
| 15 | Quiz Questions / Options | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — `QuizQuestion{prompt, options, correctOptionIndex, explanation}` is sample data | |
| 16 | Quiz Attempt / Start | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — `CourseQuizScreen` starts an attempt as pure local widget state | |
| 17 | Quiz Submission | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — answers are graded on-device (`quizScore()`) | |
| 18 | Quiz Result / Score | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — score is computed client-side from the local answer key | |
| 19 | Quiz Retry | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — "retake" just re-pushes `CourseQuizScreen`, clearing local state | |
| 20 | Certificate status | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — no per-student check exists in the app | Distinct from the admin template endpoints — see §5 |
| 21 | Certificate availability | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable | Same distinction as #20 |
| 22 | Certificate download (student-facing) | — | — | NEEDS BACKEND CONFIRMATION | — | — | Not usable — `_CertificatePreview` renders one bundled static image | An **admin-side** cert-template download exists (`GET /courses/{course_id}/templates/cert`) but is a design asset, not an issued student certificate — see §5 |

No row above is classified **VERIFIED MISSING**: nothing in the current Postman collection, or in either historical document, explicitly states that any of these 22 features do not exist on the backend. Absence from the collection is documented as **NEEDS BACKEND CONFIRMATION** in every case, per this task's Case A/B/C rule.

## 5. Detailed API Findings

### Modules

No module-shaped endpoint exists anywhere in the current 79-request collection. One relevant, previously under-examined data point: the **admin "Create course" request body** (`POST /courses`, folder `Admin / Course content (course:edit)`) includes a `curriculum` field with the example value:

```json
"curriculum": ["Week 1", "Week 2", "Week 3"]
```

This is a **request-body example on an admin create endpoint**, not a captured GET response — but it is concrete evidence (new since the previous audit, which had marked `curriculum`'s shape as entirely unconfirmed in `course.dart`'s own doc comment) that `curriculum` is a **flat array of plain marketing-copy strings**, not a queryable Module list with ids, ordering, or per-module status. This closes one ambiguity without confirming a Module API exists: **`curriculum` is not a substitute for a Module endpoint.**

Requirements doc `§4.1`'s candidate `GET /courses/{course_id}/modules` remains unconfirmed — it does not appear anywhere in the collection.

**Flutter currently expects** (`CourseModule`, 100% sample data): `id`, `order`, `title`, `scheduleLabel` (one pre-formatted display string, not separate date/time/weekday fields), `iconAsset`, `accentColor`, `completed`, `locked`. No `course_id`, no `description` field exists on the model at all.

**Status: NEEDS BACKEND CONFIRMATION.**

### Lessons / Exercises

No lesson-shaped endpoint exists anywhere in the collection. Requirements doc `§4.2`'s candidate `GET /modules/{module_id}/lessons` remains unconfirmed.

**Flutter currently expects:**
- `Lesson` (sample data): `id`, `moduleId`, `order`, `title`, `durationLabel`, `completed`, `locked`.
- `CourseExercise` (sample data, the Exercise Detail screen's content): `moduleId`, `moduleCaption`, `title`, `durationLabel`, `recordingBadgeLabel`, `summary`, `extraSections[{title, body, bullets}]`, `materials`, `note`, `assignmentFeedback`, `assignmentAttachment`, `quiz`.
- **Unresolved cardinality gap, unchanged since the previous audit:** `CourseLearningRepository.getExercise(int moduleId)` is still keyed by `CourseModule.id`, not `Lesson.id` — every lesson in a module opens the same Exercise Detail content today. A real Module→Lesson→Exercise contract would need this re-keyed.

**Status: NEEDS BACKEND CONFIRMATION.**

### Progress (course + lesson)

No progress-shaped endpoint, field, or query parameter appears anywhere in the collection — including in the admin `List students`, `Get student`, and `List cohort students (roster)` endpoints, which were specifically checked for a hidden per-student progress field and show none.

**Flutter currently expects:**
- `CourseLearningPath.percentComplete` — a single hand-authored `int` (0–100), not derived from `modules` (the Figma reference shows "30% complete" against 2/5 completed modules, a different figure than a naive 40%, so the app deliberately does not compute one from the other).
- `CourseModule.completed`/`.locked` and `Lesson.completed`/`.locked` — hand-authored sample booleans, not read from any progress record.

**Status: NEEDS BACKEND CONFIRMATION** (both course-level and lesson-level).

### Continue Learning

Not an endpoint question at all — no candidate endpoint has even been proposed in the requirements doc (`§4.3` explicitly defers "which rule selects the module/lesson"). Confirmed by reading the current code: `_continueLearningTarget()` in `course_module_list_screen.dart:163-171` is a **pure client-side heuristic** —

```dart
CourseModule? _continueLearningTarget(List<CourseModule> modules) {
  for (final module in modules) {
    if (!module.completed && !module.locked) return module;
  }
  for (final module in modules.reversed) {
    if (module.completed) return module;
  }
  return null;
}
```

— documented in its own comment as a "frontend-only judgement call," not a claim about backend behavior. No rule is assumed to exist on the backend.

**Status: NEEDS BACKEND CONFIRMATION.**

### Assignment / Submission / Resubmission / File Upload

No assignment-, submission-, or student-file-upload-shaped endpoint exists anywhere in the collection.

**Flutter currently expects** (all sample/local state, `AssignmentTab` + `AssignmentAttachmentCard`):
- Two free-text fields: a link and a description.
- One optional attachment (`CourseExerciseMaterial{id, name, sizeLabel}`) with a client-simulated download (an integer tick counter driving a `Timer`, not a real transfer) that gates Submit.
- Three states only: not-submitted (editable), pending-review (transient, ~900ms, cosmetic), submitted (a fixed "Assignment submitted successfully" card with a "Resubmit" action that reopens the same form). There is no distinct "resubmission" endpoint/state in the model — resubmission is modelled as simply doing the same submit action again.
- No file is actually uploaded by the student anywhere in the app; `assets/images/course_learning/exercise_upload.svg` is bundled but unused, reserved for this future flow.

The collection's only file-transfer-shaped requests remain the **admin-side** course template endpoints:

```
PUT    /courses/{course_id}/templates/cert   (formdata: file — Admin, course:edit)
GET    /courses/{course_id}/templates/cert   (Admin, course:edit)
DELETE /courses/{course_id}/templates/cert   (Admin, course:edit)
```

These manage a **course's certificate/contract template** (an admin design asset), not a **student's assignment submission file**. They must not be reused for student file upload — same conclusion as the previous audit, re-confirmed against the current collection.

**Status: NEEDS BACKEND CONFIRMATION** for all four (Assignment, Submission, Resubmission, File upload).

### Course Materials

No course-material-shaped endpoint exists anywhere in the collection.

**Flutter currently expects** (`CourseExerciseMaterial`, sample data, shared by both the Assignment attachment and the Course Materials tab): `id`, `name`, a single pre-formatted `sizeLabel` string (e.g. `"10 MB"`) — no file URL, no MIME/type field, no attach-to-course/module/lesson scoping field. `CourseMaterialCard`'s download button is `onTap: () {}` locally (flips to a checked state, nothing fetched), deliberately unwired pending this endpoint.

**Status: NEEDS BACKEND CONFIRMATION.**

### Student Notes

No note-shaped endpoint exists anywhere in the collection.

**Flutter currently expects** (`CourseExerciseNote`, sample data): `authorInitials`, `authorName`, `authorLabel` (e.g. `"Me"`), `message`, `timestampLabel`. `NoteTab` creates/edits entirely in local widget state (lifted up to `CourseExerciseDetailScreen` only so it survives a tab switch within the same screen instance) — nothing is fetched, created, or persisted across sessions.

**Status: NEEDS BACKEND CONFIRMATION.**

### Mentor Feedback

No mentor-feedback-shaped endpoint exists anywhere in the collection.

**Flutter currently expects** (`AssignmentMentorFeedback`, sample data): `mentorInitials`, `mentorName`, `mentorRole` (e.g. `"Lead Mentor"`), `message`, `timestampLabel`. Rendered from a fixed, hand-authored list on `CourseExercise.assignmentFeedback` — whether a student can leave feedback of their own remains an open question the requirements doc (`§4.8`) already flagged and this audit found nothing to resolve.

**Status: NEEDS BACKEND CONFIRMATION.**

### Quiz

No quiz-, question-, option-, attempt-, or result-shaped endpoint exists anywhere in the collection.

**Flutter currently expects:**
- `CourseQuiz{title, resultTitle, questions}` — `title` is the preview card's heading; `resultTitle` is a separate, distinct string shown on the Result screen (the reference shows a different, more general caption there, e.g. "Level 2 - Language Model Training", than the exercise-specific quiz title) — sample data invents both independently, no backend field is assumed for either.
- `QuizQuestion{prompt, options: List<String>, correctOptionIndex, explanation}` — a flat multiple-choice shape with the "correct answer" and its explanation embedded directly in the same object the client reads before answering. **This is a meaningful, worth-flagging gap:** a real backend almost certainly would not send `correctOptionIndex` to the client before an attempt is graded (a student could read it from the network response) — the sample shape should not be read as a proposal for how a real quiz-grading contract ought to work, only as what today's fully-offline demo needs.
- Score/result: computed on-device by `quizScore()`, comparing chosen options against `correctOptionIndex` locally — no submission ever leaves the device.
- Retry: re-opens the same local quiz screen with cleared answers — no distinct "attempt" concept exists (there is no attempt id, no start-timestamp, nothing to retry against on a server).

**Status: NEEDS BACKEND CONFIRMATION** for Quiz, Quiz Questions/Options, Quiz Attempt/Start, Quiz Submission, Quiz Result/Score, and Quiz Retry alike — none of the six have any backend evidence, positive or negative.

### Quiz Attempt / Result

See "Quiz" immediately above — same conclusion, nothing exists on either side yet beyond the fully-local implementation.

### Certificate

Module List's `_CertificationSection`/`_CertificatePreview` (`course_module_list_screen.dart`) renders one bundled static image pair (`certificate.png` + `certificate_backround.png`) — there is no per-student "has this student earned a certificate" check, status field, availability flag, or download URL anywhere in the app. This is unchanged from the previous audit.

**Important distinction, re-confirmed against the current collection — do not conflate:**

```
GET    /courses/{course_id}/templates/cert   (Admin, course:edit — download template)
PUT    /courses/{course_id}/templates/cert   (Admin, course:edit — upload template)
DELETE /courses/{course_id}/templates/cert   (Admin, course:edit — delete template)
```

These manage the **course's certificate template** (an admin-side design asset used to generate certificates for a cohort, not a specific student's issued certificate). Also present, unrelated to student certificates: `Course.certTemplateName`/`hasCertTemplate` (course-level fields, confirmed by name only per `course.dart`'s own doc comment, unconfirmed type).

Requirements doc `§4.10`'s three asks — certificate **status**, **availability**, and **download URL**, all scoped to one student — remain fully unconfirmed. Nothing in the collection speaks to any of the three.

**Status: NEEDS BACKEND CONFIRMATION** for all three (status, availability, student-facing download).

## 6. Flutter vs Backend Gap Analysis

| Feature | Frontend today | Backend (verified) | Backend (missing) | Backend (needs confirmation) |
|---|---|---|---|---|
| Modules | Sample-only (`CourseModule`) | — | — | Endpoint + shape + relation to `Course.curriculum` (now known to be unrelated) |
| Lessons/Exercises | Sample-only (`Lesson`, `CourseExercise`) | — | — | Endpoint + shape + Module↔Lesson cardinality |
| Course progress | Sample-only (`percentComplete`) | — | — | Endpoint + computation source |
| Lesson progress | Sample-only (`completed`/`locked`) | — | — | Endpoint + update method |
| Continue Learning | Client-side heuristic, not backend-driven | — | — | The selection rule itself |
| Assignment | Sample-only (`AssignmentTab`, unwired) | — | — | View/description/link/submit contract |
| Assignment submission | Local state only | — | — | Submit endpoint + status shape |
| Assignment resubmission | Same local form reopened | — | — | Whether resubmission is a distinct action at all |
| File upload | Simulated locally, nothing transferred | Admin **template** upload exists (unrelated) | — | Student-facing upload flow |
| Course Materials | Sample-only, download unwired | — | — | Endpoint + file URL/type/scope |
| Student Notes | Local widget state, not persisted | — | — | Create/get/update endpoints |
| Mentor Feedback | Fixed sample list | — | — | Endpoint + whether students can author feedback |
| Quiz (all sub-areas) | Fully local: model, grading, retry | — | — | Everything — get quiz/questions, attempt, submit, result, retry |
| Certificate (status/availability/download) | Static bundled image, no per-student check | Admin **template** endpoints exist (unrelated) | — | Student-facing status/availability/download |

Every row above is currently **frontend sample-only**; no Course Learning feature beyond the Course/Cohort/Auth layer in §3 has moved from sample data to a real backend call since the previous audit.

## 7. Recommended Integration Order

Based strictly on **verified** backend availability today — since nothing beyond Course/Cohort/Auth is verified, there is no Course Learning feature that can be integrated yet. This section instead orders the **confirmation requests**, so that whichever gets answered first unblocks the most downstream work, matching the previous audit's own reasoning (unchanged, since nothing has been resolved in the interim):

1. **Course → Module → Lesson relationship + Module API** — settles the data model everything else hangs off.
2. **Lesson API** — needed before a real Lesson List can replace today's Module→Exercise shortcut.
3. **Student course/lesson progress + Continue Learning rule** — turns Module List's `completed`/`locked` state and CTA from static sample values into real ones.
4. **Video/lesson recording info** — unblocks the Exercise Detail video header (still no candidate endpoint of any kind; this area was already out of scope for the 22-feature list above but remains open from the previous audit).
5. **Assignment + submission + file upload** — the largest remaining chunk of Exercise Detail.
6. **Course materials** — independent of assignment; can be parallelized with step 5.
7. **Student Note + Mentor Feedback** — depends on lesson identity from step 2, otherwise independent.
8. **Quiz / Attempt / Result / Retry** — no UI-blocking urgency for a *real* backend (the current implementation already fully demonstrates the flow offline), but see the grading-shape flag in §5 before ever proposing a contract that echoes `correctOptionIndex` to the client pre-attempt.
9. **Certificate status/availability/download (student-facing)** — last, since it depends on progress (step 3) being complete to know when a certificate is earned.

**Do not treat this as an implementation order for code that can start today** — no step above has a confirmed endpoint to build against yet.

## 8. Backend Confirmation Questions

Every question the previous audit raised remains open; this re-audit did not resolve any of them. One clarifying sub-question was added (marked *new*) from the `curriculum` finding in §5.

1. Module API endpoint name + response shape.
2. Lesson API endpoint name + response shape.
3. Course → Module → Lesson relationship (cardinality) — including whether the app's current lack of a separate Lesson concept needs to change.
4. *(new)* Given `Course.curriculum` is a plain string array (e.g. `["Week 1", "Week 2", "Week 3"]`) and not a Module list — is there any plan to make `curriculum` structured, or will Modules always be a fully separate resource?
5. Student course/lesson progress source + response shape.
6. Continue Learning selection rule (confirm whether this should ever move server-side, or whether the current client heuristic is acceptable long-term).
7. Lesson video/recording storage (URL field, streaming vs. static, player requirements).
8. Assignment + submission API shape (including whether "resubmit" is a distinct action/endpoint or the same submit call again).
9. Student-facing file upload flow — confirmed distinct from the existing admin template upload.
10. Course material API (endpoint, file URL/type, and whether materials attach to course, module, or lesson).
11. Student Note API (create/get/update; scoped to lesson).
12. Mentor Feedback API — including whether a student can leave feedback of their own.
13. Quiz / Question / Option / Attempt / Submission / Result / Retry API — and specifically, whether the correct answer is ever sent to the client before grading (a real contract almost certainly should not mirror the current sample shape here).
14. Certificate status/availability/download API (student-facing; distinct from the existing admin template endpoints).
15. Admin role/permission model for learning content (Module/Lesson/Assignment/Material/Quiz CRUD, mentor feedback management, student progress view) — the current collection's admin permission scopes (`course:edit`, `cohort:manage`, `student:manage`, etc.) cover Course/Cohort/Student/Teacher/Classroom, but none map to any Course Learning content area.
