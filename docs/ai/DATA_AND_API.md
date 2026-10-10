# Data and API

> The confirmed data boundary. **Only what is listed here as consumed or verified is real.** Everything else is `UNKNOWN` / `BACKEND GAP` — see the unknown-data policy in [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) §5.

## 1. Endpoints the app actually calls

Base URL `https://api.ai-academy.asia`, declared as `defaultBaseUrl` in each HTTP repository.

| Method | Path | Auth | Caller | Transport |
|---|---|---|---|---|
| POST | `/auth/login` | none | `HttpAuthRepository` | `postJson` (`auth_http.dart`) |
| POST | `/auth/refresh` | none | `HttpAuthRepository`, through `SessionRefresher` (§5) | `postJson` |
| POST | `/auth/logout` | none | `HttpAuthRepository`, from sign-out (§5) | `postJson` |
| POST | `/auth/change-password` | Bearer | `HttpPasswordRepository` | `postJson` |
| GET | `/auth/me` | Bearer | `HttpCurrentUserRepository` | `getRaw` |
| GET | `/courses` | none | `HttpCourseRepository.getCourses` | `getJson` |
| GET | `/courses/{slug}` | none | `HttpCourseRepository.getCourseDetail` | `getJson` |
| GET | `/cohorts` | none | `HttpCohortRepository` | `getJson` |
| GET | `/me/cohorts` | Bearer | `HttpEnrolledCohortsRepository` | `getRaw` |
| POST | `/cohorts/{cohort_id}/enroll` | Bearer | `HttpEnrollmentRepository` | `postWithoutBody` |
| GET | `/me/courses/{course_slug}/learning` | Bearer | `HttpCourseLearningRepository.getCourseLearning` | `getRaw` |
| GET | `/me/attendance?course={course_slug}` | Bearer | `HttpAttendanceRepository` | `getRaw` |
| GET | `/me/ledger` | Bearer | `HttpLedgerRepository` | `getRaw` |
| GET | `/teachers/{teacher_id}/schedule` | Bearer (teacher) | `HttpTeacherHomeRepository` (also Teacher Schedule, through `HttpTeacherScheduleRepository`) | `getRaw` |
| GET | `/teacher/cohorts/{cohort_id}/sessions?from=&to=` | Bearer (teacher) | `HttpTeacherScheduleRepository.getSessions` | `getRaw` |
| GET | `/teacher/sessions/{session_id}/attendance` | Bearer (teacher) | `HttpTeacherScheduleRepository.getAttendance` | `getRaw` |
| GET | `/teacher/cohorts/{cohort_id}/assignments` | Bearer (teacher) | `HttpTeacherGradebookRepository.getAssignments` | `getRaw` |
| GET | `/teacher/assignments/{assignment_id}/submissions` | Bearer (teacher) | `HttpTeacherGradebookRepository.getSubmissions` | `getRaw` |
| GET | `/teacher/submissions/{submission_id}` | Bearer (teacher) | `HttpTeacherGradebookRepository.getSubmission` | `getRaw` |

`HttpCourseLearningRepository` also calls `GET /me/modules/{id}/lessons`, `GET /me/lessons/{id}`, the lesson note, `POST /me/lessons/{id}/complete` (Issue #209, not yet called from the UI), the material download, `POST /me/assignments/{id}/submissions`, `POST /me/files` and the four §2.7 quiz endpoints (`POST /me/quizzes/{id}/attempts`, `POST /me/quiz-attempts/{id}/answers`, `POST /me/quiz-attempts/{id}/finish`, `GET /me/quiz-attempts/{id}`); each is documented, with its shape, on that repository's own method.

**Teacher Home** (Issue #229). `teacher_id` is the teacher's `GET /auth/me` `actor_id` (verified live with the teacher test account: the schedule answers for it, assignments' `teacher_id` and the public `cohort.teacher.id` carry it). The schedule answers `{teacher_id, cohorts: [...]}`, each cohort in exactly `GET /cohorts`'s shape, parsed by the same `cohortFromJson`. Fields read: `name`, `course.id`/`title_*`, `classroom.name` (nullable — omitted when null), `enrolled_count`, `start_time`, `end_time`, `start_date`, `end_date`, `meeting_days`. Each class's track badge is the public `GET /courses` `level` (`adult`/`junior`) matched on `course.id`, best-effort: no badge when the catalog cannot be read. A teacher token gets `403` from `GET /me/cohorts`, so no student endpoint is called for a teacher. The repository refuses an `actor_type` other than `teacher` before sending.

**Teacher Schedule** (Issue #231). Both teacher endpoints were verified in backend reconnaissance (task-supplied contract; no captured response is in the repository). `GET /teacher/cohorts/{cohort_id}/sessions` takes optional `from`/`to` (`YYYY-MM-DD`) and answers `{cohort_id, sessions: [{id, cohort_id, session_date, start_time, end_time, topic_id, created_at}]}`; read: `id`, `cohort_id`, `session_date`, `start_time`, `end_time` (wall-clock, read as local time like a cohort's times). Whether `to` is inclusive is `UNKNOWN`, so the app asks one day past the week and keeps only the week's days. It is asked once per class whose `start_date`…`end_date` reaches into the week on screen — one request per running class, never one per session; calendar blocks come only from these sessions, never from `meeting_days`. `GET /teacher/sessions/{session_id}/attendance` answers `{session, counts: {present, late, absent, excused}, students: [{student_id, name, status, method, checked_in_at}]}`; only `counts` is read. Unmarked students are returned as `absent` with `method: null` — there is no "not marked" status. The held-session summary shows `present + late` of the four counts' sum (the session's roster); `absent` and `excused` are not attended. It is read only for the session the teacher taps. A block is "held" (the reference's light block) once the session's end time has passed — a clock rule, `PRODUCT DECISION`: no endpoint reports that a session was "entered". Nothing in Teacher Schedule writes.

**`BACKEND GAP` — session change / teacher request ("Цаг солих" → "Багш нар").** No verified endpoint lists the teachers a session can be handed to, sends a session-change request, or reports its status (`Хүсэлт илгээх` / `Хүлээгдэж байна` / `Татгалзсан`), and no request body, response or status code is known. The "Багш нар" screen is built but shows a not-available line instead of rows, and sends nothing; its `TeacherRequestStatus` enum is UI-only and maps no backend value. Wiring it needs: a read of candidate teachers for a session (id, name, photo URL), a create-request call (method, path, body), and the request status values with their wire spelling.

**Teacher Gradebook** (Issue #233). Confirmed by captured responses (supplied with the task, cohort 2 / assignment 2). The classes are Teacher Home's read (every class, not only today's).
- `GET /teacher/cohorts/{cohort_id}/students` → `{cohort_id, students: [{enrollment_id, name, phone (nullable), student_id}]}`. Confirmed, **not called**: the Gradebook's rows are submissions, which carry their student.
- `GET /teacher/cohorts/{cohort_id}/assignments` → `{assignments: [...], cohort_id, count}`; each assignment has `id`, `cohort_id`, `lesson_id`, `title` / `title_mn` / `title_en`, `instructions`, `due_date`, `max_score`, `submitted_students`, `teacher_id`, `is_active`, `attachment` / `attachment_material_id`. Read: `id` and the title (`title_mn` / `title_en`, falling back to `title`). A body without the `assignments` list is a `server` failure.
- `GET /teacher/assignments/{assignment_id}/submissions` → `{assignment_id, count, max_score, submissions: [...]}`, the **latest submission per student** (older versions are a submission's `history`). Entry: `id`, `assignment_id`, `student {id, name, initials}`, `description`, `link`, `file`, `status` (`"submitted"` / `"reviewed"`), `score`, `feedback {created_at, mentor {id, initials, name, role}, message}` (null before review), `submitted_at`, `graded_at`, `version`, `version_count`. Read: `id`, `assignment_id`, `student`, `status`, `score`, `feedback.message`, `description`, `link`, `submitted_at`.
- `GET /teacher/submissions/{submission_id}` → the same submission fields plus `history`; read by the same parser.

The student list asks the class's assignments, then each one's submissions (one request per assignment), and lists every submission newest first — so only students who submitted appear, once per assignment; no single assignment is picked (`PRODUCT DECISION`: the reference names one, "Assignment 03 - Neural Nets", which no captured data maps to). Filters: `submitted` → Хүлээгдэж буй, `reviewed` → Дүгнэгдсэн, Бүгд both; any other status under Бүгд only. Avatars show the confirmed `initials`: no photo URL exists. The submission screen opens `link` with `openExternalUrl` and shows `description` in the "Тайлбар" box, then the status, score and feedback message.

**`BACKEND GAP` — Gradebook.** `GET /teacher/submissions/{submission_id}/file` — not verified (signed URL, redirect or bytes unknown), and `file` has only been seen as `null`: a file submission is not drawn. `POST /teacher/submissions/{submission_id}/review` — request body `{"score": number, "feedback": string}` confirmed; a live call answered `404`, and the success response and error contract are **not verified**: Mentor Feedback sends nothing. No exam/assessment endpoint exists (Шалгалтын дүн) and no teacher note endpoint (the Note tab). A per-student attendance figure ("1/20 · 10%") has no defined rule (`PRODUCT DECISION`) and is drawn as "—". The Gradebook card's "12/24 Даалгавар илгээсэн" is not drawn: which assignment's `submitted_students` it counts is not defined.

### 1.1 Fields read by the Home dashboards

Adult Home (`EnrolledHomeDashboardRepository`) and Junior "Сурлагын явц" (`ApiJuniorProgressRepository`, which maps that same dashboard) read only these fields. Each shape is the verified production response recorded on the repository; `mobile_api_v1_1.md` is the contract they were checked against.

| Endpoint | Fields read | Used for |
|---|---|---|
| `GET /me/cohorts` | entry `cohort_id`, `progress_pct` | which cohorts the student is in; progress fallback |
| `GET /cohorts` (still lists ended cohorts: 8 listed, 3 past `end_date`, statuses `closed`/`open`, verified live 2026-10-08 for the Certificate screen, PR #245; whether an archived cohort drops out is `UNKNOWN`) | `id`, `name`, `status`, `course.slug`/`title_*`, `start_date`, `end_date`, `start_time`, `end_time`, `meeting_days` | the cohort in view; `LessonSchedule` → next lesson, the attendance calendars' lesson days, and (`start_date`) the earliest month they page back to (Issue #200) |
| `GET /me/courses/{slug}/learning` | `progress.percent`, per-module `completed`/`locked`, `continue.module_id` | course progress (adult cohort card, Junior Home map); the Junior map's nodes, one per module, and its single current/check-in node: `continue.module_id` while unfinished, else the first unlocked, unfinished module (Issues #202, #204) |
| `GET /me/attendance?course=` | `summary.attended`, `summary.total_past`, `summary.percent`; per `sessions[]` entry `date`, `status` | the attendance card / badge — the server's figures, never re-derived; the attended and missed calendar marks (Adult attendance detail, Junior "Сурлагын явц") |
| `GET /me/ledger` | per enrollment `cohort.id`, `balance`, `next_due_date` | the payment card: due in N days, overdue, or absent when nothing is owed |
| `GET /me/contracts` — **the exception to this table's rule: documented by the backend's source, not a verified production response** (only `{"contracts": []}` has been seen live; Issue #300) | per item `status`, `can_sign`, `is_current` | the contract banner (Adult Home, Junior "Сурлагын явц"): the backend's rule picks the newest `can_sign` contract, else the newest `is_current`, the list being newest first; only a `pending` pick draws the "not signed" banner, which opens the E-Contract screen. A `signed` pick, another status, no pick or a failed call draws nothing |

**`/me/attendance` `sessions`** — confirmed populated by the junior test student's production response (cohort 7, `junior-ai-summer-10-14`, Issue #138). Each entry: `date` (`"2026-06-16"`), `start_time`, `end_time` (`"09:00"`/`"12:00"`), `session_id` (int), `status` (string), `topic_id` (int). Only `date` and `status` are modelled (`AttendanceSession`); the other four are confirmed but unread. The adult test account's response has `sessions: []`.

- **Status values seen:** `"present"`, `"late"`, `"absent"`, and **`null`** — kept as a raw `String?`, the set is not known to be closed. `absent` and `null` were confirmed by the adult `corp.s01`–`corp.s10` responses (cohort 3, `ai-corporate-leaders`, Issue #170): each lists 9 past sessions with a status and **3 future sessions (not held yet) with `"status": null`**. Before #170 the parser required a string, so a single future session failed the whole response and the attendance card disappeared.
- **`late` counts as attended:** that response lists 10 `present` + 1 `late`, and its `summary.attended` is 11 of `total_past` 11; the adult `corp.s01` response agrees (7 `present` + 1 `late` = `attended` 8 of `total_past` 9). `AttendanceSession.countsAsAttended` is true for exactly those two values; `absent`, `null` and anything unknown get no attended mark.
- **`absent` is marked missed, and only `absent`:** `AttendanceSession.countsAsMissed` is true for exactly that value. Its day gets the frames' missed mark — on the Adult attendance detail calendar (Issue #172, red-ringed) and the Junior "Сурлагын явц" calendar (Issue #180, "Хичээлээ тасалсан", unringed). An attended session wins on the same day. **No missed day is ever inferred** — not from a past lesson date with no session, not from a `null` or unknown status.

**Attendance check-in: endpoint/request confirmed, not called.** Postman (`Student/Attendance/Check in with teacher's QR`) and `mobile_api_v1_1.md` §8 confirm `POST /me/attendance/check-in` with the body `{"token": "<QR token>"}`, the token from the teacher's QR. Their notes say it records `present`, or `late` more than 15 minutes after the start, and is idempotent. Endpoint/request confirmed; response shape not yet verified (Postman holds no response). The app does not call it: the scanner submits nothing, and scanning needs a camera plugin (Issue #202). No backend sends a check-in window: the Junior Home check-in node's open window is the app's own rule from the `GET /cohorts` schedule (a lesson under way: `start_time` ≤ now < `end_time` on a meeting day inside `start_date`…`end_date`), the same rule as Adult Home's attendance action.

**Not read, because not confirmed:** `/me/ledger` `installments` (the verified response had it empty). No endpoint reports an exam/quiz result — a `BACKEND GAP`, and neither dashboard fills it in: no exam figure is worked out from assignment or quiz scores.

## 2. Verified to exist, but NOT consumed by the app

Student-facing endpoints confirmed by a request in the Postman collection (`postman/collections/AIAA Backend (prod)/`) and listed in the backend's endpoint index, `mobile_api_v1_1.md`, that the app does not call. Teacher, staff and admin endpoints are left out: apart from the teacher schedule, sessions, session attendance, assignment and submission reads (§1, Issues #229, #231, #233), the app is a student app. Wiring any of them is a task of its own, not a refactor.

**Response shape:** Postman holds requests only, no responses. Where this column says **not yet verified**, read: *Endpoint/request confirmed; response shape not yet verified.* A field the backend's own documents name is quoted as **documented**, which is still not a captured response. Model no field of either kind until a captured response confirms it (§8, rule 2).

| Method | Path | Request (as Postman sends it) | Response shape | Flutter status |
|---|---|---|---|---|
| POST | `/auth/logout-all` | Bearer, no body | not yet verified | not integrated |
| POST | `/auth/forgot-password` | no auth; `{"email"}` | documented: always `200 {"status": "ok"}`, and a 6-digit code is emailed (`mobile_api_v1_1.md` §1) | not integrated: Login sends a forgotten password to the manager contact (Issues #184, #186) |
| POST | `/auth/reset-password` | no auth; `{"email", "code", "new_password"}` | documented: any failure is `400 invalid_code`, and success revokes every session; the success body is not yet verified | not integrated |
| PATCH | `/me/profile` | Bearer; `{"first_name", "last_name", "phone"}` (student) | documented: carries `user_type`; the rest is not yet verified | not integrated |
| GET | `/cohorts/{cohort_id}` | no auth | not yet verified | not integrated |
| DELETE | `/cohorts/{cohort_id}/enroll` | Bearer, no body | not yet verified | not integrated |
| GET | `/me/assignments/{assignment_id}` | Bearer | documented: the §2.6 `assignment` object (`course_learning_api_contract_v1.md`) | not called: the lesson detail already carries the assignment |
| GET | `/me/files/{file_id}/download` | Bearer | not yet verified (§2.8 says only that a student file is read back through a pre-signed URL, like materials) | not integrated |
| GET | `/me/courses/{course_slug}/certificate` | Bearer | documented: contract §2.9 (`status` `not_eligible`/`eligible`/`issued`, `requirements`, `certificate {cert_number, issued_at, verify_url}`). **Verified live for `not_eligible` only** (2026-10-10, see §2.1 below); `eligible` and `issued` not yet verified live | **integrated** (Issue #155): `HttpCourseLearningRepository.getCourseCertificate` reads `status`, `cert_number`, `issued_at`, and `has_file` (Issue #296, `mobile_api_v1_1.md`; read inside `certificate`, then at the top level, since its place is undocumented). An explicit `false`, or no `cert_number`, draws Download disabled. `requirements` (documented in §2.9 as an object: `lessons_completed {done, percent}`, `quizzes_passed {done, passed, required}`, `payment_cleared {done}`) and `verify_url` are not read (no design) |
| GET | `/me/certificates/{cert_number}/download` | Bearer | documented: contract §2.9, `{"url", "expires_at"}`, pre-signed; not yet verified live | **integrated** (Issue #155): `getCertificateDownload`, fetched fresh per tap and opened with `openExternalUrl` |
| GET | `/certificates/verify/{cert_number}` | no auth | not yet verified | not integrated |
| POST | `/me/attendance/check-in` | Bearer; `{"token"}` | not yet verified (see §1.1) | not integrated: the scanner is UI only (Issue #202) |
| GET | `/me/notifications` | Bearer; `?limit=` | **verified live** (Phase 0, adult student, Issue #246): `{"notifications": [{id int, title str, body str, kind str (`general`, `assignment` seen), created_at ISO-8601, read_at ISO-8601\|null, data object\|null (`assignment`: `{"assignment_id": int}`)}], "unread_count": int}`; `read_at == null` is unread; only `limit` — no cursor/page/has_more | **integrated** (Issue #246): `HttpNotificationRepository.getNotifications`, latest 30; a malformed item is skipped and reported |
| POST | `/me/notifications/{notification_id}/read` | Bearer, no body | **verified live**: the notification with `read_at` set, and `unread_count`; idempotent on an already-read id; unknown id → `404 {"error": "notification_not_found"}`. Whether the item is wrapped or flat beside `unread_count` is `UNKNOWN` — both are read | **integrated** (Issue #246): `markRead` |
| POST | `/me/notifications/read-all` | Bearer, no body | **verified live**: `{"unread_count": 0, "updated": n}`; idempotent | **integrated** in the data/controller layers (Issue #246): `markAllRead`; no screen control — none in the Figma (`PRODUCT DECISION`) |
| POST | `/me/push-tokens` | Bearer; `{"token", "platform"}` (`ios`/`android`/`web`) | not yet verified | not integrated. `mobile_api_v1_1.md` §9: push delivery is not active yet |
| DELETE | `/me/push-tokens` | Bearer; `{"token"}` | not yet verified | not integrated |
| POST | `/payments/invoices` | Bearer; `{"provider", "enrollment_id", "amount", "description"}`, `provider` one of `qpay`/`storepay`/`golomt` | not yet verified | not integrated: the payment flow UI runs on fixtures (§10) |
| GET | `/payments/invoices/{invoice_id}` | Bearer | not yet verified (documented as carrying the QR and bank deeplinks) | not integrated |
| GET | `/payments/invoices/{invoice_id}/status` | Bearer | not yet verified (Postman: re-checks the gateway rather than a cache; `mobile_api_v1_1.md`: poll until `paid`) | not integrated |
| GET | `/me/invoices` | Bearer; `?limit=` | not yet verified | not integrated |
| GET | `/me/receipts` | Bearer | not yet verified (documented: eBarimt receipts, `is_temp_mode` = not yet filed) | not integrated |
| GET | `/me/receipts/{receipt_id}` | Bearer | not yet verified | not integrated |
| GET | `/me/contracts` | Bearer | **verified live: the envelope only** (developer's Postman call, Adult student, Issue #294): `{"contracts": []}` — only ever seen empty. **Documented by the backend's source, not observed** (`ai-academy-backend` `docs/e_contract_api_v1.md`, commit `208e1c9`): items newest first, each `{id, contract_number, status (pending/signed/cancelled), enrollment_id, course_id, course {id, slug, title {mn, en}, level}, cohort {id, name, start_date, end_date}, created_at, signed_at, cancelled_at, can_view, can_sign, is_current, document_url}`. **Not side-effect free:** the call creates `pending` rows for the student's own eligible enrollments (`core.sync()`), by design | **integrated** (Issues #294, #300): `HttpContractRepository.getContracts` reads every documented field leniently (a missing or mistyped field is null/false, never a failure); it drives the Home / Junior Progress banner (§1.1). The E-Contract list (Issue #312) draws one card per contract from `status`, `course.level` / `title`, `cohort.name`, `can_sign`, `document_url` and `contract_number` (fallback title); download goes through `getContractDownload`; empty / error + retry are unchanged |
| GET | `/me/contracts/{contract_id}` | Bearer | **documented by the backend's source, not observed** (`docs/e_contract_api_v1.md`, `student._detail`; re-checked at backend `8dc89df`): the list item plus `form` (11 strings, `""` when empty; prefilled with names, phone, e-mail while pending), `rules {guardian_required, final_payment_date_required, final_payment_date_min, final_payment_date_max\|null}`, `finance {total_due, total_paid, balance, discount_percent, currency}`, `document {format: "pdf", preview\|null, download\|null}`. Creates `pending` rows like the list (`core.sync()`) | **data layer only** (Issue #302): `HttpContractRepository.getContractDetail` → `ContractDetail`. The summary is read leniently; `form`, `rules`, `finance` and `document` are required with their documented types, otherwise a server failure. No UI calls it |
| POST | `/me/contracts/{contract_id}/preview` | Bearer; `{"form": {…all eleven fields}}` (any subset; not validated by the backend) | **documented by the backend's source, not observed** (`routes/contracts.py`, `student.preview`): the contract PDF filled with `form`, unsigned, **nothing saved**, as raw `application/pdf` bytes; `409` `already_signed` / `contract_cancelled` for a signed or cancelled contract, `409` `contract_template_missing` / `contract_template_invalid`, `502 storage_error` | **data layer only** (Issue #308): `getContractPreview(id, form:)` → `Uint8List`, returned only when the status is 2xx, the `Content-Type` is `application/pdf` and the body starts with `%PDF`, otherwise a `server` failure (whose detail names the content type at most, never form values or bytes). No viewer yet |
| POST | `/me/contracts/{contract_id}/sign` | Bearer; `{form, agreed, signature}`: all eleven form fields, `agreed` must be `true`, `signature` a PNG data URL or bare base64 (≤ 2 MB, ≤ 8 MP, something drawn) | **documented by the backend's source, not observed**: `200` with the detail shape, `status: "signed"`, `signed_at` and `document.download` set. **Irreversible for the student** (staff reset only). The backend decided signing happens in the app | **data layer only** (Issue #302): `signContract` sends `agreed` as the caller gives it, never assumed; `signatureDataUrl` builds the data URL. Tested against `MockClient` only — **never called live**, no UI calls it |
| GET | `/me/contracts/{contract_id}/download` | Bearer | **documented by the backend's source, not observed**: `{url, expires_at}`, a pre-signed link valid 5 minutes; `409 not_signed` before signing | **data layer only** (Issue #302): `getContractDownload` → `ContractDownload` (an http(s) `url` and a timestamp, or a server failure). Nothing opens it yet |

`GET /me/ledger`, in the same Postman folder (`Student/Payments & receipts`), is consumed (§1). Its `installments` element is still an unverified shape (§9).

### 2.1 Certificate — live observations (Issue #298)

**Observed, not documented:** two read-only responses captured in Postman on **2026-10-10** from an **Adult student test account**, for one course (`ai-corporate-leaders`) in the **`not_eligible`** state. Only the fields that matter here are shown. The other `/learning` keys (`continue`, `modules`, the course's other fields) and the account-specific `enrollment_id` are left out. The title text is replaced by `"…"`. No personal data, credentials, tokens or URLs are recorded.

`GET /me/courses/ai-corporate-leaders/certificate`:

```json
{
  "certificate": null,
  "requirements": {
    "lessons_completed": {"done": false, "percent": 41},
    "payment_cleared": {"done": false},
    "quizzes_passed": {"done": true, "passed": 2, "required": 2}
  },
  "status": "not_eligible"
}
```

`GET /me/courses/ai-corporate-leaders/learning` (excerpt):

```json
{
  "certificate": {"status": "not_eligible"},
  "cohort_id": 3,
  "course": {"id": 9, "slug": "ai-corporate-leaders", "title": {"mn": "…", "en": "…"}},
  "progress": {"completed_lessons": 5, "percent": 41, "total_lessons": 12}
}
```

What these two responses show, for this one account and course:

- **Both status sources agreed on `not_eligible`.** The certificate endpoint's `status` matched `/learning`'s nested `certificate.status`. One sample does not prove they can never disagree (the requirements spec's G8 stays open).
- **`certificate` was `null`** on the certificate endpoint while not eligible.
- **The `requirements` object was present**, with the three keys contract §2.9 documents: lessons 41% (not done), quizzes 2 of 2 passed (done), payment not cleared.
- **The progress percentages agreed at 41%.** `requirements.lessons_completed.percent` matched `progress.percent`, and 5 of 12 lessons rounds down to 41, as contract §2.1 describes.
- **`has_file` was absent**, at the top level and anywhere else, in this response where `certificate` was `null`. **Nothing follows about issued certificates:** whether `has_file` appears there, where it sits, and what `/download` answers without a file are still `BACKEND GAP`s.
- **The app's parsing matches.** `getCourseCertificate` reads `not_eligible` with nothing issued (Download not offered). `getCourseLearning` reads `"not_eligible"` and 41. The Certificate screen draws the not-yet card ("41% complete", Continue learning).

**Still documented only, not observed live:** the `eligible` and `issued` states, the issued `certificate` object, `has_file`'s place and behaviour, `GET /me/certificates/{cert_number}/download`, `GET /certificates/verify/{cert_number}`, and every error case (403, 404, archived, foreign `cert_number`).

### 2.2 E-Contract errors (Issue #302)

**Documented by the backend's source, not observed live** (`app/services/errors.py`: `{"error": "<code>", ...extra}`; codes from `app/services/contracts/`). `contractFailureFor` gives each documented code its own `ContractFailureKind`, but only under the status that code is documented with:
- `400`: `invalid_fields` (its `fields` map becomes `ContractFailure.fieldErrors`: `required`, `too_long`, `cyrillic_only`, `invalid_format`, `out_of_range`, else `unknown`), `agreement_required`, `signature_required`, `invalid_signature`, `empty_signature`;
- `413`: `signature_too_large`;
- `403`: `forbidden`;
- `404`: `contract_not_found`;
- `409`: `already_signed`, `contract_cancelled`, `contract_template_missing`, `contract_template_invalid`, `not_signed`;
- `502`: `storage_error`.

Any other combination keeps the list's earlier reading (Issue #294): 5xx is `server`, anything else `unexpected`. A 401 still ends the session.

**Client-side form check (Issue #306).** `ContractFormValidator` mirrors `fields.py` (`clean`, `validate`, `_date_problem`) so a screen can say the same thing before sending. The server stays authoritative; where the two differ, the client is deliberately stricter:
- `final_payment_date` must be `YYYY-MM-DD`; the backend's Python 3.12 `date.fromisoformat` also accepts forms like `20261015`;
- digits are ASCII; Python's `\d` also matches other scripts' digits.

Length is counted in code points, as Python's `len` counts. None of the new kinds has copy of its own yet (no screen): `ContractStrings` shows the existing generic lines.

## 3. Transport layer

Two entry points, split by failure family — not by accident:

- **`lib/core/api/api_client.dart`** — `getJson` (throws `ApiFailure` on any non-2xx), `getRaw` and `postWithoutBody` (return **every** status so an authenticated caller can read 401 as "sign in again"). All three turn a request that never completed into `ApiFailureKind.network`.
- **`lib/features/auth/data/auth_http.dart`** — `postJson`, which encodes a JSON body and reports `AuthFailure`.

`getJson`'s shared status mapping has no 401 case on purpose: it serves endpoints confirmed to need no auth, so a 401 there would be the API misbehaving, and giving it a "session expired" reading would force that case onto every public caller's `switch`.

## 4. Failure taxonomy

Eight failure types, each scoped to a domain so no caller has to `switch` over cases that cannot occur in its context.

| Type | Kinds |
|---|---|
| `ApiFailure` (`core/api`) | `network`, `server`, `notFound`, `unexpected` |
| `AuthFailure` (`auth`) | `invalidCredentials`, `sessionExpired`, `network`, `server`, `unexpected` |
| `CurrentUserFailure` (`auth`) | `rejected`, `network`, `server`, `unexpected` |
| `EnrollmentFailure` (`enrollments`) | `rejected`, `network`, `server`, `unexpected` |
| `HomeFailure` (`home`) | `network`, `server`, `unexpected` |
| `AttendanceFailure` (`attendance`) | `sessionExpired`, `rejected`, `network`, `server`, `unexpected` |
| `LedgerFailure` (`payments`) | `sessionExpired`, `rejected`, `network`, `server`, `unexpected` |
| `CourseLearningFailure` (`course_learning`) | `sessionExpired`, `notEnrolled`, `notFound`, `locked`, `contentRequired`, `contentTooLong`, `submissionEmpty`, `invalidLink`, `descriptionTooLong`, `pastDue`, `noAttemptsLeft`, `attemptFinished`, `alreadyAnswered`, `unsupportedFileType`, `fileTooLarge`, `network`, `server`, `unexpected` |
| `ContractFailure` (`contracts`) | `sessionExpired`, `network`, `server`, `unexpected`, and from the body's `error` code (§2.2): `forbidden`, `contractNotFound`, `invalidFields` (+ `fieldErrors`), `agreementRequired`, `signatureRequired`, `invalidSignature`, `emptySignature`, `signatureTooLarge`, `alreadySigned`, `contractCancelled`, `templateMissing`, `templateInvalid`, `notSigned`, `storageError` |

`notFound` exists on `ApiFailure`, because a 404 on `GET /courses/{slug}` is a real, distinguishable outcome (stale link, removed course) a screen may want to word differently, and on `CourseLearningFailure`, for the contract's `*_not_found` 404s. `CourseLearningFailure`'s 400/409/413 kinds are read from the body's `error` code, which the contract (§0) says the app branches on.

**Controllers convert these into `String? errorMessage`.** Widgets never catch failures.

## 5. Authentication and session

```
LoginScreen → LoginController → AuthRepository.login()
                                      ↓ AuthSession {accessToken, expiresIn?}
                              AuthSessionStore.instance.save(session)
                                      ↓
   every authenticated repository reads AuthSessionStore.authorizationHeader
                                      → {'Authorization': 'Bearer <token>'}
```

Facts that constrain any auth-adjacent work:

- **Persisted across restarts** (Issue #235). `main` calls `AuthSessionStore.instance.attach(SecureSessionPersistence())` before `runApp`: the stored session (access token, refresh token, absolute access-token expiry, `user_type`, and since Issue #286 `user_id`, as one JSON value under `aia.auth.session` in `flutter_secure_storage`) is restored, and every `save`/`clear` is written through in order — so a rotated refresh token is what the next launch uses, and sign-out or a dead session leaves nothing behind. An unreadable value restores nothing. A store never attached (every test's `AuthSessionStore()`) is in memory only. Nothing listens to app lifecycle events: backgrounding never touches the session.
- **The signed-in account's id** (Issue #286) is `GET /auth/me`'s top-level `id` (`CurrentUser.id`), the user account. It is not `actor_id` (the student or teacher record), not `profile.id`, and not the role or email. The login and refresh responses don't carry it.
  - Every successful `/auth/me` read records it on the session it was asked for (`AuthSessionStore.identify`), guarded by `accountEpoch` so a late answer never identifies a later sign-in.
  - It is persisted with the session as `user_id` and kept across a renewal (`save(…, renewal: true)`).
  - A new sign-in starts unidentified, and `clear()` forgets it. A session saved before #286 has no `user_id` until the next `/auth/me`.
  - The theme preference is kept per account under it.
  - `BACKEND GAP`: no endpoint stores the preference, so it is per device and per account, not synced across devices.
- **Singleton with injection** — `AuthSessionStore.instance` is the app's store; every repository accepts one so tests can pass their own.
- **Sign-out** (`signOutToLogin`, the Adult, Junior and Teacher Profiles' log-out, each behind `confirmSignOut`): `POST /auth/logout` with the login response's `refresh_token` (kept on `AuthSession.refreshToken`, and rotated by every renewal), then `AuthSessionStore.clear()` **whatever the revoke did**, then the stack is replaced with `/login`. A failed revoke is never shown.
- **Refresh and retry** (Issue #176). Every authenticated repository sends through `AuthenticatedClient.instance` (`auth/data/authenticated_client.dart`), which acts only on requests carrying `Authorization`:
  - **before sending**, an access token past its reported `expires_in` is renewed first (`isAccessTokenExpired()`);
  - **on a 401** whose `error` is one of the contract's token codes — `authentication_required`, `token_expired`, `invalid_token`, `account_inactive` — the session is renewed and the request **retried once** (body buffered, so uploads replay too). A second refusal is returned as is: no loop. Any other 401 (`invalid_credentials` from change-password's wrong current password, or no code) passes through untouched.
  - **Renewal** is `SessionRefresher.instance`: `POST /auth/refresh {refresh_token}` → the login response's shape with a **rotated** refresh token (confirmed live; a spent token answers `401 refresh_token_reused`, an unknown one `invalid_refresh_token`). It is **single-flight** — concurrent 401s wait for one refresh, and a request refused on an already-replaced token just retries — because two refreshes with one token would end the session.
  - **When renewal is refused** (a 401/403 from `/auth/refresh`, or no refresh token), the session is cleared — no `/auth/logout`, the token is already dead — and `onSessionEnded` fires once. **When it merely could not complete** (network, timeout, 5xx — `SessionRefresher.transientFailures`), the session is kept and the next request tries again (Issue #235); `main` wires it (`returnToLoginWhenSessionEnds`) to replace the whole stack with `/login` through `appNavigatorKey`.
  - `isExpired()` now means the *session* is dead: access token past its lifetime **and** no refresh token to renew it. When the backend sent no `expires_in`, the 401 is the authority.
- **`GET /auth/me`** returns `CurrentUser { id, actorId, actorType, email, role, isActive, mustChangePassword, profile }` with `UserProfile { id, firstName, lastName, phone, uiMode }`. `profile.uiMode` is what drives the Home track badge — nothing on a cohort or course reports it.
- **`must_change_password` gates Home** (Issue #182). Right after sign-in, and when Splash restores a held session, `GET /auth/me` is read; when `must_change_password` is true, `openSignedIn` (`auth/presentation/home_route.dart`) replaces the route with the existing "Нууц үгээ тохируулах" screen (`ResetPasswordScreen`, `POST /auth/change-password`) instead of Home. It is required: there is no skip, and nothing is underneath to pop back to. Home opens once the change succeeds. The flag is read from `/auth/me` because that is where it is confirmed; whether the login response carries it is `UNKNOWN`. When the check itself fails, sign-in continues to Home as before (`PRODUCT DECISION`, #182), and the next sign-in asks again. Whether the change clears the flag server-side is `UNKNOWN`: the app does not re-check.

## 6. Bilingual and unconfirmed-shape handling

- **`LocalizedText {en?, mn?}`** (`core/models`) — the `{"en": …, "mn": …}` wire shape, first seen on `Course.title`/`tagline`. Note the cohort list endpoint sends **flat `title_en`/`title_mn` instead**; `CohortCourse` builds a `LocalizedText` from those. The two endpoints genuinely differ.
- **`describeJsonLines`** (`core/utils/describe_json.dart`) — for fields whose *name* is confirmed but whose *shape* is not (`curriculum`, `instructors`, `prerequisites`, `whats_included` on course detail). Those stay `Object?` on the model and are rendered generically rather than asserted into a guessed structure. **This is the house pattern for "confirmed name, unconfirmed shape" — reuse it instead of inventing a type.**
- **Nullable fields confirmed by production responses.** The models make a field nullable only once a real response shows it `null`, and the parsers fail loudly on anything else — so such a failure means *loosen the model*, not *the backend is broken*. Confirmed so far, beyond each model's original nullable set:
  - `GET /cohorts` → **`classroom` may be `null`** (the online `ai-applied-online` cohort). `Cohort.classroom` is `CohortClassroom?`; a present classroom must still be an object with `id`, `name`, `center_name`. Nothing in the app draws it.
  - `GET /auth/me` → **`profile.ui_mode` may be `null`** (the adult `corp.s01`/`corp.s02` test accounts, Issue #168). `UserProfile.uiMode` is `String?`; any other non-string is still rejected. A null `ui_mode` means no Home track badge — none is guessed. Before this, the whole response failed, so the Profile header fell back to its placeholder name.
  - `GET /courses` → **`age_max` may be `null`** (the adult courses: `age_min: 18`, no upper bound). `Course.ageMax` is `int?`; the age range then reads **"18+ нас"** (`CourseCatalogStrings.ageRange`) — the open end is shown, never filled in with a guessed upper age.

  Because both lists parse all-or-nothing, one such field used to reject the whole response as a `server` failure ("Серверт алдаа гарлаа") — breaking every `/cohorts`-backed screen, including both Home dashboards (Issue #136).

## 7. Course Learning integration and the sample boundary

**`lib/features/course_learning/` runs on the real API.** `CourseLearningRepository` declares twelve methods — the learning path, a module's lessons, a lesson's detail, the note save, the lesson completion, a material's download link, the assignment submission, the student file upload, and the four quiz-attempt calls — and `HttpCourseLearningRepository` implements every one against `course_learning_api_contract_v1.md` §2.1–§2.8. Each method documents its endpoint and the shape it reads; the screens default to it. See [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) §2 for the endpoint list and what is deliberately not integrated.

`SampleCourseLearningRepository` still implements the same interface with fixed, hand-authored content that ignores `courseSlug`/`moduleId`/`lessonId` — the note save and the quiz attempt are simulated locally, while its submission, upload and material download throw — but **only tests construct it** (the quiz goldens among them). Consequences to keep in mind:

- Models carry **pre-formatted display strings** — `scheduleLabel` `"08/04 • Да • 09:00"`, `durationLabel` `"24:15"`, `sizeLabel` `"10 MB"`, `timestampLabel` `"Today, 14:20"`. `HttpCourseLearningRepository` builds them on the client from the contract's raw fields (dates, `duration_seconds`, `size_bytes`, timestamps); they are frontend requirements, **not** proposed backend fields.
- **The quiz carries no answer key** (Issue #150). Correctness arrives one answered question at a time from `POST /me/quiz-attempts/{id}/answers`, and the score from `finish`. The sample quiz grades inside `SampleCourseLearningRepository` only; no model holds a key, and none should be proposed as a response field.
- Sample-only fields (`CourseExercise.assignmentFeedback`, `assignmentAttachment`, `simulatesWrites: true`) are empty or false on every backend lesson — the real flow reads `assignment.submission.feedback`, and `assignment.attachment` is listed with the lesson's Course materials (`CourseExercise.allMaterials`, Issue #194), never in `AssignmentTab`.

The contract is the source of truth for the API. `docs/course_learning_frontend_backend_requirements_v1.md` holds the field-by-field analysis that preceded it — historical context where the two differ.

## 8. Rules for touching this layer

1. **Never invent an endpoint, field, status code or business rule.** If a task needs one that is not in §1 or §2, stop and report it as a `BACKEND GAP`.
2. **Never widen a model on speculation.** A field is modelled non-nullable only where a confirmed response showed a value; `HttpCourseRepository` fails loudly on a missing required field precisely so the gap surfaces as a parse error rather than a silent wrong value.
3. **Do not convert sample data into an API contract.** Sample fields describe what the UI needs, not what the backend sends.
4. **Keep failure families separate.** Do not merge the failure enums to "simplify"; the split is what keeps `switch` statements honest.
5. **A new authenticated endpoint** reads its token from an injected `AuthSessionStore`, defaults its `http.Client` to `AuthenticatedClient.instance` (so an expired token is renewed and the request retried), uses `getRaw`/`postWithoutBody` (which return all statuses), and maps a 401 that survives renewal to that feature's "session expired" case.

## 9. Payment screen and its temporary fixtures (Issue #196)

The Adult Payment screen ("Төлбөр", `home/presentation/payment_screen.dart`) is built from three Figma references — 1 partly paid, 2 paid off, 3 overdue — **before any `/me/ledger` response with installments has been seen**. The only verified response had `"installments": []`, so the screen is fed nothing from the API yet.

**What feeds it now — temporary, debug-only.** `PaymentPlanUiFixtures` (`payments/data/payment_plan_ui_fixtures.dart`) holds the three references' own figures, typed in by hand; `PaymentPreviews` (`home/presentation/payment_previews.dart`) pairs each with that reference's row placement. They describe no real student. `HomeScreen.showPaymentPreview` defaults to `!kReleaseMode`: in debug/profile builds the Adult Home payment card's "Дэлгэрэнгүй" and its live (overdue) pay pill open the overdue or the partly-paid preview; **release builds leave the card exactly as before**. The rows' chevrons are inert. "Төлбөр төлөх" opens the payment flow UI (§10), which also runs on fixtures only — no QPay, invoice, payment processing, polling, receipt or eBarimt is integrated. Fixture values kept verbatim because Figma is the visual source of truth:

- the rows' date labels ("Ня, 3 сарын 8", "Бя, 3 сарын 12", "Да, 3 сарын 17", "Ням, 3 сарын 22"; reference 2 repeats "Ня, 3 сарын 8"), though they follow no single format and match no real calendar;
- the progress fill, 114 of the bar's 361 points (≈32%), not 500,000 ÷ 2,000,000;
- each reference's own row placement, where the three disagree by about 2pt.

**What the backend still has to provide (`BACKEND GAP`)** — the shape of one `installments` element: its due date, its amount, and whether it is paid (a flag, a status, or a paid amount); its number/order; possibly a pre-formatted date label.

**Mapping to confirm against the first real sample** onto the domain model `PaymentPlan` (`payments/domain/payment_plan.dart`, not tied to any response shape):

| `PaymentPlan` | Source | State |
|---|---|---|
| `totalDue`, `totalPaid`, `balance` | `total_due`, `total_paid`, `balance` | Field names verified; that they are the plan's totals is to confirm |
| `courseTitle` | `course.title` | Verified field; whether the summary always names the course is a `PRODUCT DECISION` (only reference 3 does) |
| `paidFraction` | — | `PRODUCT DECISION`: paid ÷ due, installments paid ÷ all, or a backend value |
| `installments[]` → `PaymentInstallment` (`number`, `dueDate`, `dueDateLabel`, `amount`, `paid`) | `installments` | `UNKNOWN` shape |
| paid / next (N days) / overdue / upcoming | worked out by `PaymentPlan.statusesOn` from due dates and paid flags | `UNKNOWN` whether the backend sends these states itself |
| `dueDateLabel` format | — | `PRODUCT DECISION`: the weekday abbreviation ("Ня" vs "Ням") |

When the sample arrives: map it in the `payments` data layer into `PaymentPlan`, open the screen with it in every build, and delete `PaymentPlanUiFixtures`, `PaymentPreviews` and `HomeScreen.showPaymentPreview`. The fixtures stay only for tests until then; never convert them into a contract (§8 rule 3).

## 10. Payment flow UI and its temporary fixtures (Issue #198)

The screens after "Төлбөр төлөх" (`home/presentation/payment_flow/`) are built from eight Figma references. They are **UI only**: no endpoint is called, and every value comes from `PaymentCheckoutUiFixtures` (`payments/data/payment_checkout_ui_fixtures.dart`), mapped onto the domain model `PaymentCheckout` (`payments/domain/payment_checkout.dart`). That model isn't tied to any response shape. The flow is reachable only from the debug-only Payment screen previews (§9), so release builds never show it.

**Flow:**
1. Amount screen: a slider from the due installment to the whole balance, with local method selection.
2. "Төлбөр шалгах" opens the method screen ("3-р төлөлт 500,000₮", with four methods).
3. Шилжүүлэх opens the bank sheet.
4. Choosing a bank opens the transfer details sheet.
5. Closing that sheet leaves Шилжүүлэх selected, with the details inline.
6. "Төлбөр шалгах" shows the success dialog.
7. "Ойлголоо" opens the eBarimt receipt.

The copy buttons write to the clipboard. "Татаж авах" is live but inert.

**Temporary values and assets:**
- **Amounts:** 500,000–1,500,000₮, with 2 later installments.
- **"3-р төлөлт" header:** shown verbatim, not tied to the slider or the plan.
- **Bank list and transfer account:** Голомт банк, "Хиймэл Оюун Ухааны Хаб", 3215155471 / 820015003215155471, reference "Test".
- **Receipt:** #TRX-992104, Nov 25, 2024, UV37143572 and the ДДТД.
- **Images:** the payment logos, bank logos, method icons and eBarimt QR in `assets/images/payments/` are cut from the 3x reference exports. Replace them with official assets of the same size.

**Built as drawn (Figma is the visual source of truth):**
- **Slider positions:** the thumb sits where references 1–3 place it (`PaymentReferenceSlider`), which isn't evenly spread.
- **Two method-screen headers:** the state behind the sheets is 16pt higher, with a smaller amount than reference 7.
- **Row placement:** each method row's logo and name sit where they are drawn.

**Deviations from the references, with reasons:**
- **Reference 3's amount:** the reference prints "Таны төлөх дүн 750,000₮" with the slider at 1,500,000₮. The brief says the amount follows the slider.
- **Success dialog spelling:** the reference reads "амжиттай"; the brief's "амжилттай" is used.
- **Selection behind the sheets:** the references draw Qpay selected behind both sheets, while the brief opens the bank sheet from Шилжүүлэх. So Шилжүүлэх becomes selected only once the details sheet closes.

**Still needed (`BACKEND GAP`):**
- the invoice responses and their states. The requests are confirmed (`POST /payments/invoices`, `GET /payments/invoices/{id}`, `GET /payments/invoices/{id}/status`, §2), but no response has been verified. A "payment checking" frame is also needed (`UNKNOWN`: there is none, so the success dialog follows immediately);
- the bank list and logos;
- the receiving account(s);
- eBarimt receipt data and its QR (`GET /me/receipts` and `GET /me/receipts/{id}` are confirmed requests, §2; their response shape is not yet verified);
- the receipt file for "Татаж авах".

**Product decisions to confirm (`PRODUCT DECISION`):**
- **Slider:** its step (50,000₮ here) and how the thumb maps to amounts.
- **Later installments:** the rule "(balance − amount) ÷ later installments", which matches all three references.
- **Transfer account:** whether it depends on the chosen bank (one fixed account here).
- **Copy feedback:** whether copying shows any confirmation (none here).
- **After eBarimt:** where back leads (it returns to the method screen here).
- **Header:** whether the method header follows the chosen amount.
