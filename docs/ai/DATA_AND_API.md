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

`HttpCourseLearningRepository` also calls `GET /me/modules/{id}/lessons`, `GET /me/lessons/{id}`, the lesson note, the material download, `POST /me/assignments/{id}/submissions` and `POST /me/files`; each is documented, with its verified shape, on that repository's own method.

### 1.1 Fields read by the Home dashboards

Adult Home (`EnrolledHomeDashboardRepository`) and Junior "Сурлагын явц" (`ApiJuniorProgressRepository`, which maps that same dashboard) read only these fields. Each shape is the verified production response recorded on the repository; `mobile_api_v1_1.md` is the contract they were checked against.

| Endpoint | Fields read | Used for |
|---|---|---|
| `GET /me/cohorts` | entry `cohort_id`, `progress_pct` | which cohorts the student is in; progress fallback |
| `GET /cohorts` | `id`, `name`, `status`, `course.slug`/`title_*`, `start_date`, `end_date`, `start_time`, `end_time`, `meeting_days` | the cohort in view; `LessonSchedule` → next lesson and the Junior calendar's lesson days |
| `GET /me/courses/{slug}/learning` | `progress.percent`, per-module `completed` | course progress (adult cohort card, Junior Home map) |
| `GET /me/attendance?course=` | `summary.attended`, `summary.total_past`, `summary.percent` | the attendance card / badge — the server's figures, never re-derived |
| `GET /me/ledger` | per enrollment `cohort.id`, `balance`, `next_due_date` | the payment card: due in N days, overdue, or absent when nothing is owed |

**Not read, because not confirmed:** `/me/attendance` `sessions` (the verified response had it empty — no session field is known), and `/me/ledger` `installments` (likewise empty). No endpoint reports an e-contract's signed state or an exam/quiz result. These are `BACKEND GAP`s, and neither dashboard fills them in: no "missed" day is inferred from a past lesson date, and no exam figure is worked out from assignment or quiz scores.

## 2. Verified to exist, but NOT consumed by the app

Present in the Postman collection (see `docs/course_learning_backend_api_audit_v2.md` §3), deliberately unused here. Wiring any of them is a task of its own, not a refactor.

`POST /auth/refresh` · `POST /auth/logout` · `POST /auth/logout-all` · `GET /cohorts/{cohort_id}` · `DELETE /cohorts/{cohort_id}/enroll`

The absence of `/auth/refresh` in the app is why an expired token means "sign in again" and nothing else.

## 3. Transport layer

Two entry points, split by failure family — not by accident:

- **`lib/core/api/api_client.dart`** — `getJson` (throws `ApiFailure` on any non-2xx), `getRaw` and `postWithoutBody` (return **every** status so an authenticated caller can read 401 as "sign in again"). All three turn a request that never completed into `ApiFailureKind.network`.
- **`lib/features/auth/data/auth_http.dart`** — `postJson`, which encodes a JSON body and reports `AuthFailure`.

`getJson`'s shared status mapping has no 401 case on purpose: it serves endpoints confirmed to need no auth, so a 401 there would be the API misbehaving, and giving it a "session expired" reading would force that case onto every public caller's `switch`.

## 4. Failure taxonomy

Six failure types, each scoped to a domain so no caller has to `switch` over cases that cannot occur in its context.

| Type | Kinds |
|---|---|
| `ApiFailure` (`core/api`) | `network`, `server`, `notFound`, `unexpected` |
| `AuthFailure` (`auth`) | `invalidCredentials`, `sessionExpired`, `network`, `server`, `unexpected` |
| `CurrentUserFailure` (`auth`) | `rejected`, `network`, `server`, `unexpected` |
| `EnrollmentFailure` (`enrollments`) | `rejected`, `network`, `server`, `unexpected` |
| `HomeFailure` (`home`) | `network`, `server`, `unexpected` |
| `CourseLearningFailure` (`course_learning`) | `sessionExpired`, `notEnrolled`, `notFound`, `network`, `server`, `unexpected` |

`notFound` exists only on `ApiFailure` and only because a 404 on `GET /courses/{slug}` is a real, distinguishable outcome (stale link, removed course) a screen may want to word differently.

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
- **No refresh.** Nothing renews a token. `isExpired()` only reports expiry when the backend supplied `expires_in`; when it did not, the session is never locally considered expired and the backend's 401 is the authority.
- **`GET /auth/me`** returns `CurrentUser { id, actorId, actorType, email, role, isActive, mustChangePassword, profile }` with `UserProfile { id, firstName, lastName, phone, uiMode }`. `profile.uiMode` is what drives the Home track badge — nothing on a cohort or course reports it.

## 6. Bilingual and unconfirmed-shape handling

- **`LocalizedText {en?, mn?}`** (`core/models`) — the `{"en": …, "mn": …}` wire shape, first seen on `Course.title`/`tagline`. Note the cohort list endpoint sends **flat `title_en`/`title_mn` instead**; `CohortCourse` builds a `LocalizedText` from those. The two endpoints genuinely differ.
- **`describeJsonLines`** (`core/utils/describe_json.dart`) — for fields whose *name* is confirmed but whose *shape* is not (`curriculum`, `instructors`, `prerequisites`, `whats_included` on course detail). Those stay `Object?` on the model and are rendered generically rather than asserted into a guessed structure. **This is the house pattern for "confirmed name, unconfirmed shape" — reuse it instead of inventing a type.**

## 7. Sample-data boundary

**`lib/features/course_learning/` is now half-wired.** Its repository interface still has three read methods and no write methods, and only the first is integrated:

```dart
Future<CourseLearningPath> getCourseLearning(String courseSlug);
Future<List<Lesson>> getLessons(int moduleId);
Future<CourseExercise> getExercise(int moduleId);
```

`getCourseLearning` is served by `HttpCourseLearningRepository` against §1's endpoint, which is what `CourseModuleListScreen` uses by default. `getLessons` and `getExercise` have documented endpoints in `course_learning_api_contract_v1.md` §2.2/§2.3 but **no verified one**, so that repository delegates both to `SampleCourseLearningRepository` — `LessonListScreen` and `CourseExerciseDetailScreen` are still sample-driven, and `CourseExerciseDetailScreen` still defaults to the sample directly.

`SampleCourseLearningRepository` ignores both `courseSlug` and `moduleId` — all content is fixed. Consequences to keep in mind:

- Every write interaction (assignment submit/resubmit, note save, quiz answer/submit/retry, file download) is **local widget state**. Integrating any of them requires new repository methods **and** a failure model, neither of which exists.
- Sample models carry **pre-formatted display strings where a real API would send structured data** — `scheduleLabel` `"08/04 • Да • 09:00"`, `durationLabel` `"24:15"`, `sizeLabel` `"10 MB"`, `timestampLabel` `"Today, 14:20"`. These are frontend requirements, **not** proposed backend fields.
- `QuizQuestion.correctOptionIndex` lives client-side purely so the offline demo can grade itself. **It must never be proposed as a production response field** — shipping the answer key to the client before grading defeats the quiz.
- Most sample entities have **no id at all** (assignment, submission, note, feedback, quiz, question, option, attempt). Only `CourseModule.id`, `Lesson.id` and `CourseExerciseMaterial.id` exist, and all are hand-authored integers.

Field-by-field analysis lives in `docs/course_learning_frontend_backend_requirements_v1.md`. Do not re-derive it; read it.

## 8. Rules for touching this layer

1. **Never invent an endpoint, field, status code or business rule.** If a task needs one that is not in §1 or §2, stop and report it as a `BACKEND GAP`.
2. **Never widen a model on speculation.** A field is modelled non-nullable only where a confirmed response showed a value; `HttpCourseRepository` fails loudly on a missing required field precisely so the gap surfaces as a parse error rather than a silent wrong value.
3. **Do not convert sample data into an API contract.** Sample fields describe what the UI needs, not what the backend sends.
4. **Keep failure families separate.** Do not merge the five failure enums to "simplify"; the split is what keeps `switch` statements honest.
5. **A new authenticated endpoint** reads its token from an injected `AuthSessionStore`, uses `getRaw`/`postWithoutBody` (which return all statuses), and maps 401 to that feature's "session expired" case.
