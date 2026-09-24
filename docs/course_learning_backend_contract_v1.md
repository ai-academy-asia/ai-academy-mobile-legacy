# Course Learning — Backend API Contract Investigation

**Issue:** #56 — feat: investigate Course Learning backend API contract
**Branch:** feat/course-learning-backend-contract
**Status:** Investigation only. No production code changed.

## Sources inspected

1. `course_learning_api_requirements_v1.md` (v1 requirements reference) — terminology and section numbers below (`§4.x`, `§6`) refer to this document.
2. `AIAA Backend (prod).postman_collection.json` — 73 requests, walked in full (see Appendix A).
3. Current Flutter implementation:
   - `lib/features/courses/data/http_course_repository.dart`, `lib/features/courses/domain/course.dart`
   - `lib/features/cohorts/data/http_cohort_repository.dart`, `lib/features/cohorts/domain/cohort.dart`
   - `lib/features/course_learning/**` (domain, data, presentation) — the sample-data implementation this issue investigates a real backend for.

No endpoint name, field name, or response shape below is invented. Where the requirements doc or the Flutter code already names a *candidate* (not confirmed) endpoint, it is quoted and marked as unconfirmed, per the requirements doc's own rule: **"not present in the Postman collection" does not mean "does not exist in backend."**

---

## Per-area findings

### 1. Course → Module → Lesson relationship

**BACKEND DECISION REQUIRED** (relationship itself) / see #2, #3 for Module and Lesson individually.

- `Course` (id, slug) is confirmed — see #1a below.
- The Course→Module→Lesson hierarchy the requirements doc (`§3`, `§5`) diagrams is not verified against any real response; nothing in the Postman collection or current app confirms whether it is exactly 1 course → N modules → N lessons, or some other shape (e.g. a module containing lesson-like content directly).
- **Current Flutter gap worth flagging to backend/product:** the app today has no separate "Lesson" concept. `CourseModule` (module) and `CourseExercise` (the Exercise Detail screen's content) are keyed 1:1 by the same `moduleId` — there is no Lesson List between them yet (it is a distinct, not-yet-built increment). If the real backend models Module 1:N Lesson, the current `CourseExercise.moduleId` key will need to become a `lessonId`, and a Lesson List screen will need to sit between Module List and Exercise Detail. This should be confirmed before that screen is designed.

#### 1a. Course (EXISTING / VERIFIED)

| | |
|---|---|
| Method | `GET` |
| Endpoint | `/courses` |
| Auth | None (`noauth`, confirmed in Postman collection) |
| Response | `{ "courses": [ {Course}, ... ] }` |

| | |
|---|---|
| Method | `GET` |
| Endpoint | `/courses/{slug}` |
| Auth | None (`noauth`, confirmed in Postman collection) |
| Response | The `Course` object itself, no envelope |

`Course` fields, as `HttpCourseRepository`/`course.dart` already parse them from a confirmed response:

- List response: `id`, `slug`, `title{en,mn}`, `tagline{en,mn}`, `category`, `level`, `format`, `status`, `age_min`, `age_max`, `duration_weeks`, `start_date`, `end_date`, `price_amount`, `final_price_amount`, `discount_percent`, `currency`, plus nullable `duration_label`, `banner_image_url`, `icon`, `sort_order`, `target_audience`.
- Detail response adds: `attendance_method`, `capacity`, `cert_template_name`, `contract_template_name`, `created_at`, `curriculum`, `description`, `final_project_type`, `google_classroom_url`, `has_attendance`, `has_cert_template`, `has_contract_template`, `has_exam`, `has_final_project`, `instructors`, `prerequisites`, `updated_at`, `whats_included`.

Relevant IDs: `Course.id` (int), `Course.slug` (string) — `CourseModule`/`CourseLearningPath` will need one of these as the foreign key once a real Module endpoint exists; `CourseLearningPath.courseSlug` already borrows `Course.slug` today (see `CourseLearningRepository`'s own doc comment).

### 2. Module API

**NOT PRESENT IN CURRENT POSTMAN COLLECTION.** **BACKEND DECISION REQUIRED.**

- No module-shaped endpoint anywhere in the 73 requests (Appendix A).
- Requirements doc `§4.1` names a *candidate*, explicitly unconfirmed: `GET /courses/{course_id}/modules`. Endpoint name and response shape are not confirmed and must not be assumed.
- Needed fields per requirements doc: `id`, `course_id`, `title`, `description`, `order`, `status`/`availability`, progress.
- Current Flutter model (`CourseModule`, sample data only) has: `id`, `order`, `title`, `scheduleLabel`, `iconAsset`, `accentColor`, `completed`, `locked` — no `course_id`, no `description`. Its own doc comment already states every field is "this app's own choice for local sample data, not a claim about what a real API will eventually send." `scheduleLabel` is a single pre-formatted display string (e.g. `"08/04 • Да • 09:00"`) invented for the sample UI — a real API would need separate date/time/weekday fields (or its own confirmed formatted string) before this can be un-mocked.
- To confirm with backend: endpoint name, response envelope (list vs `{modules: [...]}`), and exact field names/types for the six items above, plus whether per-module progress/lock state is server-computed or client-derived from lesson progress.

### 3. Lesson API

**NOT PRESENT IN CURRENT POSTMAN COLLECTION.** **BACKEND DECISION REQUIRED.**

- No lesson-shaped endpoint anywhere in the collection.
- Requirements doc `§4.2` candidate, unconfirmed: `GET /modules/{module_id}/lessons`.
- Needed fields: `id`, `module_id`, `title`, `description`, `order`, video/recording info, duration, scheduled date/time, status.
- Current Flutter: no `Lesson` model exists at all. `CourseExercise` stands in for it today, keyed by `moduleId` (see #1's cardinality flag).

### 4. Student course progress

**NOT PRESENT IN CURRENT POSTMAN COLLECTION.** **BACKEND DECISION REQUIRED.**

- Needed: course progress %, completed/total modules, completed/total lessons, Continue Learning target module/lesson.
- Current: `CourseLearningPath.percentComplete` (an `int`, e.g. `30`) is a single hand-authored value in `SampleCourseLearningRepository` — not derived from any request. No endpoint in the collection computes or returns this.

### 5. Student lesson progress

**NOT PRESENT IN CURRENT POSTMAN COLLECTION.** **BACKEND DECISION REQUIRED.**

- Needed fields per requirements doc `§4.4`: `lesson_id`, `student_id`, `progress`, `completed`, `completed_at`.
- Nothing in the app or collection models this. `CourseModule.completed`/`.locked` are the closest existing fields, and both are hand-authored sample booleans, not read from a progress record.

### 6. Continue Learning rule

**BACKEND DECISION REQUIRED** (no candidate endpoint even proposed yet in the requirements doc — this is a rule/logic question, not just an endpoint).

- The UI already has the affordance: Course Detail's CTA and Module List's `_ProgressCtaRow`/`_ContinueLearningButton` (see `lib/features/course_learning/presentation/course_module_list_screen.dart`). Neither is wired to a rule — they don't currently compute or navigate to a specific "next" module/lesson at all.
- Requirements doc `§4.3` explicitly defers this: "`Continue learning` ямар rule-аар module/lesson сонгохыг баталгаажуулна" (which rule selects the module/lesson must be confirmed). No rule is assumed here.

### 7. Video / lesson recording information

**NOT PRESENT IN CURRENT POSTMAN COLLECTION.** **BACKEND DECISION REQUIRED** (requirements doc `§6.6`: "Lesson video/recording storage").

- `ExerciseVideoHeader` renders a static navy placeholder plus two hand-authored strings (`CourseExercise.durationLabel` = `"24:15"`, `.recordingBadgeLabel` = `"Live Classroom Recording"`) — no video URL, no player, no streaming/storage field of any kind.

### 8. Assignment

**NOT PRESENT IN CURRENT POSTMAN COLLECTION.** **BACKEND DECISION REQUIRED.**

- `AssignmentTab` (UI only) has a link field and a description field, per the Exercise Detail screen's Figma spec — but there is no `Assignment` domain model and no endpoint. Needed per requirements doc `§4.5`: assignment view, description, link input, file upload, description/comment, submit/resubmit, submission status.

### 9. Assignment submission

**NOT PRESENT IN CURRENT POSTMAN COLLECTION.**

- The submit button (`ExerciseSubmitButton`) in `AssignmentTab`/`NoteTab` is permanently disabled by design in the current build — deliberately out of scope for the screens already shipped (assignment progression/submission was explicitly reserved for a separate issue). No endpoint exists to wire it to yet regardless.

### 10. File upload

**NOT PRESENT IN CURRENT POSTMAN COLLECTION.**

- `assets/images/course_learning/exercise_upload.svg` is bundled but unused — reserved for this future flow, not wired to anything.
- The collection's only file-transfer-shaped requests are admin-side: `PUT /courses/{course_id}/templates/cert` and `GET /courses/{course_id}/templates/cert` (course certificate/contract *template* upload/download, `course:edit` permission). These are unrelated to a student uploading an assignment file and should not be reused for it.

### 11. Course materials

**NOT PRESENT IN CURRENT POSTMAN COLLECTION.** **BACKEND DECISION REQUIRED.**

- `CourseExerciseMaterial{id, name, sizeLabel}` is sample data only — no file URL field exists because there is nothing to point it at yet. `CourseMaterialCard`'s download button (`lib/features/course_learning/presentation/widgets/course_material_card.dart`) has `onTap: () {}`, deliberately unimplemented pending this endpoint.
- Requirements doc `§4.6` needs: file, title, type, URL, download — and confirmation of whether materials attach to course, module, or lesson.

### 12. Student Note

**NOT PRESENT IN CURRENT POSTMAN COLLECTION.** **BACKEND DECISION REQUIRED.**

- `NoteTab` renders one of two states purely from whether `CourseExercise.note` is `null` in the sample data — nothing is fetched, created, or updated. Requirements doc `§4.7` needs: create, get, update, scoped to student + lesson.

### 13. Mentor Feedback

**NOT PRESENT IN CURRENT POSTMAN COLLECTION.**

- `MentorFeedbackCard` only ever renders the static "No feedback yet" empty state — the feedback-populated state is explicitly out of scope for the screens already shipped. Requirements doc `§4.8` needs: `feedback`, `mentor`/`teacher`, `created_at`, plus confirmation of whether a student can leave feedback of their own.

### 14. Quiz

**NOT PRESENT IN CURRENT POSTMAN COLLECTION.**

- No quiz UI, model, or reference of any kind exists in the app yet. Requirements doc `§4.9` needs: get quiz, get questions, get options, start attempt, submit answers, get result, retry (if allowed) — all unconfirmed, all unbuilt.

### 15. Quiz Attempt / Result

**NOT PRESENT IN CURRENT POSTMAN COLLECTION.**

- Same as #14 — nothing exists on either side yet.

### 16. Certificate status / download

**EXISTING BUT NEEDS CONFIRMATION** (partial — see distinction below). **BACKEND DECISION REQUIRED** for the student-facing part.

- Module List's `_CertificationSection`/`_CertificatePreview` renders one bundled static image (`certificate.png`) — there is no per-student "has this student earned a certificate" check, status, or download URL anywhere in the app.
- **Important distinction, do not conflate:** the Postman collection *does* have a certificate-shaped set of endpoints —
  ```
  GET    /courses/{course_id}/templates/cert   (Admin, course:edit — download template)
  PUT    /courses/{course_id}/templates/cert   (Admin, course:edit — upload template)
  DELETE /courses/{course_id}/templates/cert   (Admin, course:edit — delete template)
  ```
  These manage the **course's certificate template** (an admin-side design asset used to generate certificates), not a **student's issued certificate** (status/availability/download URL for one learner). Requirements doc `§4.10` asks about the latter, which remains fully unconfirmed.

---

## 1. Verified existing API inventory

| Area | Method | Endpoint | Auth | Notes |
|---|---|---|---|---|
| Course list | GET | `/courses` | None | `{ "courses": [...] }` |
| Course detail | GET | `/courses/{slug}` | None | Course object, no envelope; 404 on unknown slug |
| Cohort list | GET | `/cohorts` | None | `{ "cohorts": [...] }`, each with nested `course{id,slug,title_en,title_mn}` |
| Cohort detail | GET | `/cohorts/{cohort_id}` | None | Present in collection; not yet consumed by any Flutter repository |
| My cohorts | GET | `/me/cohorts` | Bearer (student token) | Consumed by `HomeDashboardRepository`/cohort features |
| Enroll self | POST | `/cohorts/{cohort_id}/enroll` | Bearer (student token) | "Cohort must be `open` with seats available" (Postman description) |
| Cancel own enrollment | DELETE | `/cohorts/{cohort_id}/enroll` | Bearer (student token) | Present in collection; not yet consumed |

None of these carry Module, Lesson, progress, assignment, material, note, feedback, quiz, or student-certificate data. They establish only the Course/Cohort layer the app already integrates.

## 2. Missing/unconfirmed API inventory

| # | Area | Classification |
|---|---|---|
| 1 | Course→Module→Lesson relationship (the hierarchy itself) | BACKEND DECISION REQUIRED |
| 2 | Module API | NOT PRESENT IN POSTMAN COLLECTION |
| 3 | Lesson API | NOT PRESENT IN POSTMAN COLLECTION |
| 4 | Student course progress | NOT PRESENT IN POSTMAN COLLECTION |
| 5 | Student lesson progress | NOT PRESENT IN POSTMAN COLLECTION |
| 6 | Continue Learning rule | BACKEND DECISION REQUIRED |
| 7 | Video/lesson recording info | NOT PRESENT IN POSTMAN COLLECTION |
| 8 | Assignment | NOT PRESENT IN POSTMAN COLLECTION |
| 9 | Assignment submission | NOT PRESENT IN POSTMAN COLLECTION |
| 10 | File upload (student-facing) | NOT PRESENT IN POSTMAN COLLECTION |
| 11 | Course materials | NOT PRESENT IN POSTMAN COLLECTION |
| 12 | Student Note | NOT PRESENT IN POSTMAN COLLECTION |
| 13 | Mentor Feedback | NOT PRESENT IN POSTMAN COLLECTION |
| 14 | Quiz | NOT PRESENT IN POSTMAN COLLECTION |
| 15 | Quiz Attempt/Result | NOT PRESENT IN POSTMAN COLLECTION |
| 16 | Certificate status/download (student-facing) | EXISTING BUT NEEDS CONFIRMATION (template endpoints exist; student-issuance endpoint does not) |

Per the requirements doc's own rule, none of the "NOT PRESENT" rows above are claims that the backend lacks these features — only that this Postman collection does not document them.

## 3. Required backend confirmations

Carried over from requirements doc `§6`, cross-checked against the actual collection (all 14 remain open — the Postman inspection did not resolve any of them):

1. Module API + sample response
2. Lesson API + sample response
3. Course → Module → Lesson relationship (including whether it's really 1:N:N, given the app currently has no separate Lesson concept — see area #1/#3 above)
4. Student progress source + sample response
5. Continue Learning rule
6. Lesson video/recording storage
7. Assignment + submission API
8. File upload flow (student-facing; distinct from the existing admin template upload)
9. Course material API
10. Student Note API
11. Mentor Feedback API (including whether a student can leave feedback)
12. Quiz / Attempt / Result API
13. Certificate status/download API (student-facing; distinct from the existing admin template endpoints)
14. Admin role/permission for learning content (Module/Lesson/Assignment/Material/Quiz CRUD, mentor feedback management, student progress view)

## 4. Current Flutter sample-data dependencies

Everything below is served by `SampleCourseLearningRepository` (`lib/features/course_learning/data/sample_course_learning_repository.dart`) and is hand-authored, not backend-derived:

| Screen / widget | Sample-only data | Depends on backend confirmation of |
|---|---|---|
| Module List hero | `courseTitle`, `description`, `illustrationAsset`, `percentComplete` | #4 (student course progress) |
| Module List cards | `CourseModule.{title, scheduleLabel, iconAsset, accentColor, completed, locked}` for 5 fixed modules | #2 (Module API), #5 (lesson progress → derived `completed`/`locked`) |
| Module List "Continue learning" CTA | Always enabled, no target computed | #6 (Continue Learning rule) |
| Module List certification section | Static bundled image, no per-student check | #16 (student certificate status) |
| Exercise Detail video header | `durationLabel`, `recordingBadgeLabel`, no playable video | #7 (video/recording info) |
| Exercise Detail info section | `summary`, `extraSections` | #3 (Lesson API — this is lesson-level content, currently modelled as module-level) |
| Assignment tab | Link/description fields present but unwired; submit permanently disabled | #8, #9 (Assignment, submission) |
| Course Materials tab | `CourseExerciseMaterial{id, name, sizeLabel}`, download button unwired | #11 (Course materials) |
| Note tab | Presence/absence of a note, and its content, hardcoded per sample fixture | #12 (Student Note) |
| Mentor Feedback card | Always renders the empty state | #13 (Mentor Feedback) |
| Quiz | Not implemented in any form | #14, #15 (Quiz, Attempt/Result) |

The one thing in this feature that is **not** sample data: `CourseLearningPath.courseSlug`, which borrows the already-confirmed `Course.slug` rather than inventing its own identifier (see `CourseLearningRepository`'s doc comment).

## 5. Recommended backend implementation order

Ordered so each step unblocks the next screen/feature without leaving a built UI pointed at nothing, and so the cardinality question (area #1) is settled before anything is built on top of it:

1. **Course → Module → Lesson relationship + Module API** — settles the data model everything else hangs off; without it, nothing past Module List can be un-mocked correctly.
2. **Lesson API** — needed before a real Lesson List can replace today's Module→Exercise shortcut.
3. **Student course/lesson progress + Continue Learning rule** — turns Module List's `completed`/`locked` state and CTA from static sample values into real ones.
4. **Video/lesson recording info** — unblocks the Exercise Detail video header.
5. **Assignment + submission + file upload** — the largest remaining chunk of Exercise Detail; submission and file upload naturally follow assignment-viewing.
6. **Course materials** — independent of assignment; can be parallelized with step 5.
7. **Student Note + Mentor Feedback** — depends on lesson identity from step 2, otherwise independent.
8. **Quiz / Attempt / Result** — no UI exists yet; lowest urgency of the confirmed gaps.
9. **Certificate status/download (student-facing)** — last, since it depends on progress (step 3) being complete to know when a certificate is earned.

Admin-side CRUD for each of the above (requirements doc `§5`) should be confirmed alongside its student-facing counterpart, not after.

---

## Appendix A — Full Postman collection endpoint list (73 requests)

Grouped by whether they relate to Course Learning:

**Course/Cohort layer (relevant, listed in §1 above):** `GET /courses`, `GET /courses/{slug}`, `GET /cohorts`, `GET /cohorts/{cohort_id}`, `GET /me/cohorts`, `POST /cohorts/{cohort_id}/enroll`, `DELETE /cohorts/{cohort_id}/enroll`.

**Everything else in the collection (Auth, Admin Classrooms/Cohorts/Students/Teachers/Course content/eBarimt/Invoices/Payments/Ledger/Schedules, Payment gateway callbacks, PosAPI) — confirmed present, but unrelated to Module/Lesson/Progress/Assignment/Materials/Notes/Feedback/Quiz/student-Certificate, and out of scope for this investigation.** No endpoint anywhere in the collection (73 requests total, all namespaces) matches any of areas #2–#15 above.
