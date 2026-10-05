# Project Context

> **Purpose of this file:** the first project document to read after the root [AGENTS.md](../../AGENTS.md) (modes, authority order, safety rules). It says what this project is, what state it is in, and which claims in this repository are trustworthy.
>
> **Scope rule:** this describes the codebase **as it is today**, not a target architecture. Where something is unknown, it says `UNKNOWN`. Nothing here is aspirational.

## 1. What this project is

**AI Academy Mobile** (`aia_mobile`) — the student-facing Flutter mobile app for AI Academy Asia, an education provider running cohort-based courses.

| | |
|---|---|
| Repo | `ai-academy-asia/ai-academy-mobile-legacy` |
| Flutter/Dart SDK | Dart `^3.12.2` (records, patterns and switch expressions are available and used) |
| App id | `com.aiacademyasia.aia_mobile` (Android `applicationId` + `namespace`) |
| Display name | "AI Academy Asia" (Android `android:label`, iOS `CFBundleDisplayName`) |
| API base URL | `https://api.ai-academy.asia` |
| Size | 171 Dart files under `lib/`, 72 under `test/` |
| Languages in UI copy | Mixed Mongolian and English, **verbatim from the design** — there is no localization framework and none should be added without an explicit task |

### Runtime dependencies (deliberately few)

`http ^1.6.0`, `flutter_svg ^2.2.1`, `cupertino_icons ^1.0.8`, `url_launcher ^6.3.2` (opens a lesson material — a file's signed download link, or a link material's own URL), `file_selector ^1.1.0` (the OS document picker behind assignment file submission). Dev: `flutter_lints ^6.0.0`, `flutter_launcher_icons ^0.14.4` (build-time only).

**There is no state-management package, no routing package, no DI container, no secure-storage package, and no HTTP interceptor layer.** Every one of those roles is filled by hand-written code described in [ARCHITECTURE.md](ARCHITECTURE.md). Adding a dependency is a decision that needs its own task and justification.

## 2. Feature map and maturity

Eleven features under `lib/features/`. **Maturity differs sharply between them** — this is the single most important thing to understand before touching anything.

| Feature | Data source | State |
|---|---|---|
| `auth` | **Real API** — `POST /auth/login`, `POST /auth/change-password`, `GET /auth/me` | Implemented. Session is **in-memory only** (see §4) |
| `courses` | **Real API** — `GET /courses`, `GET /courses/{slug}` | Implemented |
| `cohorts` | **Real API** — `GET /cohorts` | Implemented |
| `enrollments` | **Real API** — `GET /me/cohorts`, `POST /cohorts/{id}/enroll` | Implemented. Cancel-enrollment is **not** wired though the endpoint exists |
| `home` | **Real API, composed** — assembles `/me/cohorts` + `/cohorts` + `/auth/me` + `/courses` | Implemented, with sections deliberately left empty (see §3) |
| `profile` | **Real API**, reusing `auth`'s `CurrentUserRepository` | Implemented. Presentation-only feature (no `data/`, no `domain/`) |
| `splash` | None | Implemented. Presentation-only |
| `course_learning` | **Real API** — the student learning endpoints of `course_learning_api_contract_v1.md` §2.1–§2.8, through `HttpCourseLearningRepository` | Implemented, with the gaps below and in §3 |
| `junior_home` | **Real API, composed** — reuses `home`'s dashboard (`EnrolledHomeDashboardRepository`) plus `GET /me/courses/{course_slug}/learning`; Junior Profile reads `GET /auth/me` | Implemented (Junior Home, Сурлагын явц, Junior Profile, Junior Course Detail) |
| `attendance` | **Real API** — `GET /me/attendance?course={course_slug}` | Data layer only (no `presentation/`); consumed by `home` |
| `payments` | **Real API** — `GET /me/ledger` | Data layer only (no `presentation/`); consumed by `home` |

### `course_learning` — read this before working in it

`course_learning` is backed by the real API. `HttpCourseLearningRepository` implements every method of `CourseLearningRepository` against the backend's `course_learning_api_contract_v1.md` (maintained outside this repository; the code cites it by section):

- `GET /me/courses/{course_slug}/learning` (§2.1) — Module List, Junior Home, Home progress
- `GET /me/modules/{module_id}/lessons` (§2.2) — Lesson List, opened from an unlocked module card (Issue #148), with an empty state (Issue #156)
- `GET /me/lessons/{lesson_id}` (§2.3) — Exercise Detail, including its `materials`, `note`, `assignment` and `quiz`
- `GET /me/materials/{material_id}/download` (§2.4) — file materials; `link` materials open their own URL (Issue #152)
- `PUT /me/lessons/{lesson_id}/note` (§2.5)
- `POST /me/assignments/{assignment_id}/submissions` (§2.6) — link submission and resubmission
- `POST /me/files` (§2.8) — built and tested, but no lesson draws the file form yet (see §3)
- `POST /me/quizzes/{quiz_id}/attempts`, `POST /me/quiz-attempts/{attempt_id}/answers`, `POST /me/quiz-attempts/{attempt_id}/finish`, `GET /me/quiz-attempts/{attempt_id}` (§2.7) — server-graded; no answer key on the client (Issue #150)

Not integrated, each for a recorded reason (§3): `POST /me/lessons/{lesson_id}/complete` (no player or "done" control), `GET /me/courses/{course_slug}/certificate` and `GET /me/certificates/{cert_number}/download` (no certificate UI design — Issue #155), `assignment.attachment` (no design — Issue #154), and `GET /me/assignments/{assignment_id}` (the lesson detail already carries the assignment).

`SampleCourseLearningRepository` remains, hand-authored and ignoring its arguments, but **only tests construct it** — the quiz goldens among them. No production navigation reaches it.

Three older in-repo documents record the investigation that preceded the contract — historical context, superseded by the contract where they differ:

- `docs/course_learning_backend_api_audit_v2.md` — what the backend API provided at the time, audited against the Postman collection
- `docs/course_learning_frontend_backend_requirements_v1.md` — what the frontend needed from a backend, field by field
- `docs/course_learning_backend_contract_v1.md` — the earlier investigation

## 3. What is deliberately missing (not bugs)

These gaps are intentional and documented in code. **Do not "fix" them as drive-by work.**

- **Home dashboard sections** — module count, attendance tally, payment state and e-contract warning are left null because no endpoint reports them (`enrolled_home_dashboard_repository.dart` states this explicitly).
- **Lesson video playback** — `ExerciseVideoHeader` renders a flat placeholder. There is no video URL field on any model and no player dependency.
- **Student file submission** — the picker, the upload (`POST /me/files`) and the `file_id` submission are built and tested, but **no backend lesson shows the file form**: nothing confirmed says whether an assignment takes a link or a file, so every one keeps the link form. `BACKEND GAP` — see `_formFor` in `course_exercise_detail_screen.dart`.
- **Certificate** — the certification section renders two bundled PNGs. There is no per-student certificate status, availability or download.
- **Lesson List step** — the design goes Module List → Exercise Detail directly, but a module card knows no lesson id, so an unlocked module card opens `LessonListScreen` (`GET /me/modules/{module_id}/lessons`) and the student picks the lesson there (Issue #148). "Continue learning" still opens the server's `continue.lesson_id` directly.
- **Quiz gaps** — the quiz runs against §2.7 (Issue #150), but some of what it sends has no place in the design and is held or skipped rather than drawn: `passed`/`pass_percent` (no pass/fail treatment), `open_attempt_id` (starting resumes it, but there is no "continue quiz" state), a question's `image` (`mobile_api_v1_1.md` addition). A resumed attempt's already-answered questions are skipped, because the shape of their `answer` is `UNKNOWN` — no source documents it.
- **Lesson material gaps** — both §2.4 kinds are shown (Issue #152): a `file` opens its signed `GET /me/materials/{id}/download` link, a `link` opens its own `url` exactly as sent. The Figma pack draws no link variant, so a link uses the file row unchanged — file glyph, download button, no size line. `file_name` and `content_type` are not shown: the row draws a name and a size only. The assignment's own `attachment` material is still not read (assignment scope).
- **Profile rows** — Terms of Service, Privacy Policy, language and theme controls have no destination yet. The same holds on Junior Profile.
- **Junior Course Detail has no Notes** (Issue #174) — a completed or current Junior Home map node (each node is a module; locked nodes stay inert) opens the **Adult course-learning screens** on the same `GET /me/courses/{slug}/learning` data: `CourseModuleListScreen(showNotes: false)`, which passes the flag to `LessonListScreen` and `CourseExerciseDetailScreen`. Junior lessons therefore offer only the Assignment and Course materials tabs — no Note tab, no `NoteTab`, no note save. Every Adult call site keeps the default `showNotes: true`. There is no separate Junior course screen.
- **Junior "Сурлагын явц" gaps** — `JuniorProgressScreen` is backend-driven through `ApiJuniorProgressRepository` (the adult dashboard's sources: payment, attendance summary, next lesson, and the cohort schedule's lesson days on the calendar). Attendance marks are real: a `present` or `late` session from `/me/attendance` `sessions` marks its day attended (Issue #138), and an `absent` one marks it missed — "Хичээлээ тасалсан" (Issue #180); no missed day is inferred from a past lesson date without a session. What it cannot show stays off rather than faked (`BACKEND GAP`): the **exam result** badge (no exam/grade endpoint), and the **contract banner** (no signed-state endpoint). The calendar opens on the current month and its previous/next arrows page to any other (Issue #140), so a finished cohort's lessons, attended and missed days — e.g. a June–July summer camp — are reachable. See `DATA_AND_API.md` §1.1.

## 4. Known constraints and sharp edges

1. **The auth session does not survive an app restart.** `AuthSessionStore` is in-memory only (a deliberate choice documented in the class — persisting a bearer token means a keychain dependency and platform entitlements). An expired access token is renewed with the refresh token and the request retried once (Issue #176, `DATA_AND_API.md` §5); only a session that cannot be renewed sends the user back to Login.
2. **There is no dev-only route any more.** `/dev/course-exercise-preview` was removed once Exercise Detail became reachable through Module List → Lesson List (Issue #148). The sample-backed Exercise Detail is now reached only from tests; a real lesson's quiz runs against the backend (Issue #150).
3. **Three iOS files carry persistent local changes that must never be reverted.** See [DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) §3 — this is a hard rule.
4. **One pre-existing test failure** exists on `main` and is unrelated to any new work. Record it as pre-existing in reports rather than fixing it in an unrelated task. (`flutter analyze` reports no issues.) See [DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) §5.
5. **Some doc comments have drifted.** Treat doc comments as high-signal but verify against the code.

## 5. Source-of-truth rules

These three rules override habit, precedent and anything a previous session may have assumed.

### Visual: Figma is the source of truth
The **existing Flutter UI is not the design authority.** It may contain visual mismatches against Figma, and where it does, Figma wins and the Flutter code is what changes. Treat the current implementation as *implementation context* — useful for knowing what exists and what can be reused, never as evidence that a spacing, colour or size is correct.

**Figma MCP is unavailable** (monthly quota exhausted). Do not plan work that depends on it. Figma **screenshots/exports supplied in the task** are the working visual source of truth.

### Backend: only confirmed contracts are authoritative
Only endpoints and response shapes confirmed by the Postman collection, a captured live response, or an already-integrated repository are real. **Never invent an endpoint, a response field, a business rule or user data.** If something is not confirmed, label it `UNKNOWN` or `BACKEND GAP` and stop there. "Absent from Postman" does **not** mean "absent from the backend" — it means unconfirmed.

### Implementation: reuse, but do not let it override
Existing architecture, theme tokens and widgets should be reused where they genuinely fit. Reuse never outranks Figma on visuals or a confirmed contract on data.

### Unknown-data policy
When a fact is not established by the repository, the Postman collection or the task itself: say `UNKNOWN` (or `BACKEND GAP` / `PRODUCT DECISION`, as defined in [AGENTS.md](../../AGENTS.md) §3), explain what would confirm it, and proceed without it. Do not fill the gap with a plausible guess, and do not carry an assumption forward from an earlier conversation.

## 6. Where to go next

| You need | Read |
|---|---|
| Layering, state, navigation, testing | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Endpoints, failures, auth, sample-data boundaries | [DATA_AND_API.md](DATA_AND_API.md) |
| Git workflow, validation, protected files | [DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) |
| Driving a GitHub Issue from discovery to PR | [AGENT_WORKFLOW.md](AGENT_WORKFLOW.md) |
| Tokens, spacing, colour, type | [../design-system/DESIGN_SYSTEM.md](../design-system/DESIGN_SYSTEM.md) |
| Buttons, fields, cards, states | [../design-system/COMPONENT_PATTERNS.md](../design-system/COMPONENT_PATTERNS.md) |
| Per-screen layout conventions | [../design-system/SCREEN_PATTERNS.md](../design-system/SCREEN_PATTERNS.md) |
| Turning a Figma frame into Flutter | [../design-system/FIGMA_TO_FLUTTER.md](../design-system/FIGMA_TO_FLUTTER.md) |
