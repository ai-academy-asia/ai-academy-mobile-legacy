# Data and API

> The confirmed data boundary. **Only what is listed here as consumed or verified is real.** Everything else is `UNKNOWN` / `BACKEND GAP` — see the unknown-data policy in [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) §5.

## 1. Endpoints the app actually calls

Base URL `https://api.ai-academy.asia`, declared as `defaultBaseUrl` in each HTTP repository.

| Method | Path | Auth | Caller | Transport |
|---|---|---|---|---|
| POST | `/auth/login` | none | `HttpAuthRepository` | `postJson` (`auth_http.dart`) |
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

`HttpCourseLearningRepository` also calls `GET /me/modules/{id}/lessons`, `GET /me/lessons/{id}`, the lesson note, the material download, `POST /me/assignments/{id}/submissions`, `POST /me/files` and the four §2.7 quiz endpoints (`POST /me/quizzes/{id}/attempts`, `POST /me/quiz-attempts/{id}/answers`, `POST /me/quiz-attempts/{id}/finish`, `GET /me/quiz-attempts/{id}`); each is documented, with its shape, on that repository's own method.

### 1.1 Fields read by the Home dashboards

Adult Home (`EnrolledHomeDashboardRepository`) and Junior "Сурлагын явц" (`ApiJuniorProgressRepository`, which maps that same dashboard) read only these fields. Each shape is the verified production response recorded on the repository; `mobile_api_v1_1.md` is the contract they were checked against.

| Endpoint | Fields read | Used for |
|---|---|---|
| `GET /me/cohorts` | entry `cohort_id`, `progress_pct` | which cohorts the student is in; progress fallback |
| `GET /cohorts` | `id`, `name`, `status`, `course.slug`/`title_*`, `start_date`, `end_date`, `start_time`, `end_time`, `meeting_days` | the cohort in view; `LessonSchedule` → next lesson and the Junior calendar's lesson days |
| `GET /me/courses/{slug}/learning` | `progress.percent`, per-module `completed` | course progress (adult cohort card, Junior Home map) |
| `GET /me/attendance?course=` | `summary.attended`, `summary.total_past`, `summary.percent`; per `sessions[]` entry `date`, `status` | the attendance card / badge — the server's figures, never re-derived; the Junior calendar's attended marks |
| `GET /me/ledger` | per enrollment `cohort.id`, `balance`, `next_due_date` | the payment card: due in N days, overdue, or absent when nothing is owed |

**`/me/attendance` `sessions`** — confirmed populated by the junior test student's production response (cohort 7, `junior-ai-summer-10-14`, Issue #138). Each entry: `date` (`"2026-06-16"`), `start_time`, `end_time` (`"09:00"`/`"12:00"`), `session_id` (int), `status` (string), `topic_id` (int). Only `date` and `status` are modelled (`AttendanceSession`); the other four are confirmed but unread. The adult test account's response has `sessions: []`.

- **Status values seen:** `"present"` and `"late"` only — kept as a raw `String`, the set is not known to be closed.
- **`late` counts as attended:** that response lists 10 `present` + 1 `late`, and its `summary.attended` is 11 of `total_past` 11. `AttendanceSession.countsAsAttended` is true for exactly those two values; anything else is unknown and gets no mark.
- **No missed/absent value has been seen**, so no day is ever marked missed — and none is inferred from a past lesson date with no session.

**Not read, because not confirmed:** `/me/ledger` `installments` (the verified response had it empty). No endpoint reports an e-contract's signed state or an exam/quiz result. These are `BACKEND GAP`s, and neither dashboard fills them in: no exam figure is worked out from assignment or quiz scores.

## 2. Verified to exist, but NOT consumed by the app

Present in the Postman collection (see `docs/course_learning_backend_api_audit_v2.md` §3), deliberately unused here. Wiring any of them is a task of its own, not a refactor.

`POST /auth/refresh` · `POST /auth/logout-all` · `GET /cohorts/{cohort_id}` · `DELETE /cohorts/{cohort_id}/enroll`

The absence of `/auth/refresh` in the app is why an expired token means "sign in again" and nothing else.

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

- **In memory only.** `AuthSessionStore` holds the session in a field. **The token does not survive an app restart.** Persisting it means a keychain dependency and platform entitlements, which the codebase deliberately has not taken on.
- **Singleton with injection** — `AuthSessionStore.instance` is the app's store; every repository accepts one so tests can pass their own.
- **Sign-out** (`signOutToLogin`, both Profiles' "Гарах"): `POST /auth/logout` with the login response's `refresh_token` (kept on `AuthSession.refreshToken` for this alone), then `AuthSessionStore.clear()` **whatever the revoke did**, then the stack is replaced with `/login`. A failed revoke is never shown.
- **No refresh.** Nothing renews a token. `isExpired()` only reports expiry when the backend supplied `expires_in`; when it did not, the session is never locally considered expired and the backend's 401 is the authority.
- **`GET /auth/me`** returns `CurrentUser { id, actorId, actorType, email, role, isActive, mustChangePassword, profile }` with `UserProfile { id, firstName, lastName, phone, uiMode }`. `profile.uiMode` is what drives the Home track badge — nothing on a cohort or course reports it.

## 6. Bilingual and unconfirmed-shape handling

- **`LocalizedText {en?, mn?}`** (`core/models`) — the `{"en": …, "mn": …}` wire shape, first seen on `Course.title`/`tagline`. Note the cohort list endpoint sends **flat `title_en`/`title_mn` instead**; `CohortCourse` builds a `LocalizedText` from those. The two endpoints genuinely differ.
- **`describeJsonLines`** (`core/utils/describe_json.dart`) — for fields whose *name* is confirmed but whose *shape* is not (`curriculum`, `instructors`, `prerequisites`, `whats_included` on course detail). Those stay `Object?` on the model and are rendered generically rather than asserted into a guessed structure. **This is the house pattern for "confirmed name, unconfirmed shape" — reuse it instead of inventing a type.**
- **Nullable fields confirmed by production responses.** The models make a field nullable only once a real response shows it `null`, and the parsers fail loudly on anything else — so such a failure means *loosen the model*, not *the backend is broken*. Confirmed so far, beyond each model's original nullable set:
  - `GET /cohorts` → **`classroom` may be `null`** (the online `ai-applied-online` cohort). `Cohort.classroom` is `CohortClassroom?`; a present classroom must still be an object with `id`, `name`, `center_name`. Nothing in the app draws it.
  - `GET /courses` → **`age_max` may be `null`** (the adult courses: `age_min: 18`, no upper bound). `Course.ageMax` is `int?`; the age range then reads **"18+ нас"** (`CourseCatalogStrings.ageRange`) — the open end is shown, never filled in with a guessed upper age.

  Because both lists parse all-or-nothing, one such field used to reject the whole response as a `server` failure ("Серверт алдаа гарлаа") — breaking every `/cohorts`-backed screen, including both Home dashboards (Issue #136).

## 7. Course Learning integration and the sample boundary

**`lib/features/course_learning/` runs on the real API.** `CourseLearningRepository` declares eleven methods — the learning path, a module's lessons, a lesson's detail, the note save, a material's download link, the assignment submission, the student file upload, and the four quiz-attempt calls — and `HttpCourseLearningRepository` implements every one against `course_learning_api_contract_v1.md` §2.1–§2.8. Each method documents its endpoint and the shape it reads; the screens default to it. See [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) §2 for the endpoint list and what is deliberately not integrated.

`SampleCourseLearningRepository` still implements the same interface with fixed, hand-authored content that ignores `courseSlug`/`moduleId`/`lessonId` — the note save and the quiz attempt are simulated locally, while its submission, upload and material download throw — but **only tests construct it** (the quiz goldens among them). Consequences to keep in mind:

- Models carry **pre-formatted display strings** — `scheduleLabel` `"08/04 • Да • 09:00"`, `durationLabel` `"24:15"`, `sizeLabel` `"10 MB"`, `timestampLabel` `"Today, 14:20"`. `HttpCourseLearningRepository` builds them on the client from the contract's raw fields (dates, `duration_seconds`, `size_bytes`, timestamps); they are frontend requirements, **not** proposed backend fields.
- **The quiz carries no answer key** (Issue #150). Correctness arrives one answered question at a time from `POST /me/quiz-attempts/{id}/answers`, and the score from `finish`. The sample quiz grades inside `SampleCourseLearningRepository` only; no model holds a key, and none should be proposed as a response field.
- Sample-only fields (`CourseExercise.assignmentFeedback`, `assignmentAttachment`, `simulatesWrites: true`) are empty or false on every backend lesson — the real flow reads `assignment.submission.feedback`, and `assignment.attachment` is not integrated (Issue #154).

The contract is the source of truth for the API. `docs/course_learning_frontend_backend_requirements_v1.md` holds the field-by-field analysis that preceded it — historical context where the two differ.

## 8. Rules for touching this layer

1. **Never invent an endpoint, field, status code or business rule.** If a task needs one that is not in §1 or §2, stop and report it as a `BACKEND GAP`.
2. **Never widen a model on speculation.** A field is modelled non-nullable only where a confirmed response showed a value; `HttpCourseRepository` fails loudly on a missing required field precisely so the gap surfaces as a parse error rather than a silent wrong value.
3. **Do not convert sample data into an API contract.** Sample fields describe what the UI needs, not what the backend sends.
4. **Keep failure families separate.** Do not merge the failure enums to "simplify"; the split is what keeps `switch` statements honest.
5. **A new authenticated endpoint** reads its token from an injected `AuthSessionStore`, uses `getRaw`/`postWithoutBody` (which return all statuses), and maps 401 to that feature's "session expired" case.
