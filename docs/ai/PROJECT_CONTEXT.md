# Project Context

> **Purpose of this file:** the first thing a new Claude/Cursor session should read. It says what this project is, what state it is in, and which claims in this repository are trustworthy.
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
| Size | 121 Dart files under `lib/`, 46 under `test/` |
| Languages in UI copy | Mixed Mongolian and English, **verbatim from the design** — there is no localization framework and none should be added without an explicit task |

### Runtime dependencies (deliberately few)

`http ^1.6.0`, `flutter_svg ^2.2.1`, `cupertino_icons ^1.0.8`, `url_launcher ^6.3.2` (opens a lesson material's download link), `file_selector ^1.1.0` (the OS document picker behind assignment file submission). Dev: `flutter_lints ^6.0.0`, `flutter_launcher_icons ^0.14.4` (build-time only).

**There is no state-management package, no routing package, no DI container, no secure-storage package, and no HTTP interceptor layer.** Every one of those roles is filled by hand-written code described in [ARCHITECTURE.md](ARCHITECTURE.md). Adding a dependency is a decision that needs its own task and justification.

## 2. Feature map and maturity

Eight features under `lib/features/`. **Maturity differs sharply between them** — this is the single most important thing to understand before touching anything.

| Feature | Data source | State |
|---|---|---|
| `auth` | **Real API** — `POST /auth/login`, `POST /auth/change-password`, `GET /auth/me` | Implemented. Session is **in-memory only** (see §4) |
| `courses` | **Real API** — `GET /courses`, `GET /courses/{slug}` | Implemented |
| `cohorts` | **Real API** — `GET /cohorts` | Implemented |
| `enrollments` | **Real API** — `GET /me/cohorts`, `POST /cohorts/{id}/enroll` | Implemented. Cancel-enrollment is **not** wired though the endpoint exists |
| `home` | **Real API, composed** — assembles `/me/cohorts` + `/cohorts` + `/auth/me` + `/courses` | Implemented, with sections deliberately left empty (see §3) |
| `profile` | **Real API**, reusing `auth`'s `CurrentUserRepository` | Implemented. Presentation-only feature (no `data/`, no `domain/`) |
| `splash` | None | Implemented. Presentation-only |
| `course_learning` | **100% SAMPLE DATA** — `SampleCourseLearningRepository` | UI complete, **zero backend integration** |

### `course_learning` is the outlier — read this before working in it

Everything in `lib/features/course_learning/` (Module List, Lesson List, Exercise Detail, Assignment, Course Materials, Note, Mentor Feedback, Quiz, Quiz Result, Certificate section) renders from hand-authored sample data. Specifically:

- `CourseLearningRepository` declares **three read methods and zero write methods**, and deliberately has **no failure model** — there is no HTTP call behind it that could fail.
- `SampleCourseLearningRepository` **ignores its arguments**: every `courseSlug` returns the same path, every `moduleId` returns the same exercise.
- Every user "write" (submit assignment, save note, answer a quiz, download a file) is local widget state that never leaves the device.

Three existing documents analyse this in depth. **Read them before proposing any Course Learning backend work:**

- `docs/course_learning_backend_api_audit_v2.md` — what the backend API actually provides today, audited against the current Postman collection
- `docs/course_learning_frontend_backend_requirements_v1.md` — exactly what the current frontend needs from a backend, field by field
- `docs/course_learning_backend_contract_v1.md` — the earlier investigation (historical context)

## 3. What is deliberately missing (not bugs)

These gaps are intentional and documented in code. **Do not "fix" them as drive-by work.**

- **Home dashboard sections** — module count, attendance tally, payment state and e-contract warning are left null because no endpoint reports them (`enrolled_home_dashboard_repository.dart` states this explicitly).
- **Lesson video playback** — `ExerciseVideoHeader` renders a flat placeholder. There is no video URL field on any model and no player dependency.
- **Certificate** — the certification section renders two bundled PNGs. There is no per-student certificate status, availability or download.
- **Lesson List screen** — built and tested, but nothing navigates to it; the design goes Module List → Exercise Detail directly.
- **Profile rows** — Terms of Service, Privacy Policy, language and theme controls have no destination yet.

## 4. Known constraints and sharp edges

1. **The auth session does not survive an app restart.** `AuthSessionStore` is in-memory only (a deliberate choice documented in the class — persisting a bearer token means a keychain dependency and platform entitlements). There is also **no token refresh**, even though `/auth/refresh` exists on the backend. A 401 means "send the user back to login".
2. **`/dev/course-exercise-preview` is a temporary dev-only route** registered in `lib/app.dart`. It exists so Exercise Detail can be opened without the full navigation chain. Its own comment says to remove it once the real flow lands. Do not treat it as product navigation.
3. **Three iOS files carry persistent local changes that must never be reverted.** See [DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) §3 — this is a hard rule.
4. **One pre-existing test failure and one pre-existing analyzer warning** exist on `main` and are unrelated to any new work. Record them as pre-existing in reports rather than fixing them in an unrelated task. See [DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) §5.
5. **Some doc comments have drifted.** For example `course_exercise.dart` still refers to a `QuizTab` widget that was replaced by `QuizPreviewCard` + `CourseQuizScreen`. Treat doc comments as high-signal but verify against the code.

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
When a fact is not established by the repository, the Postman collection or the task itself: say `UNKNOWN`, explain what would confirm it, and proceed without it. Do not fill the gap with a plausible guess, and do not carry an assumption forward from an earlier conversation.

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
