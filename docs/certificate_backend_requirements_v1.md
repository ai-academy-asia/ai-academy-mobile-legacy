# Certificate — Backend Requirements Specification v1

**Date:** 2026-10-09
**Issue:** #155 (closed; implemented by PR #245) · **Type:** documentation only. No app or backend code changes.
**Audience:** engineering manager and backend owner.

---

## 1. Summary

The student Certificate feature is **built and shipped in the mobile app** (PR #245). It runs against two student endpoints that the backend documents and that the current Postman collection contains. It is not blocked on a missing endpoint.

What is still open:

1. **Neither response has been confirmed against the live API.** Every certificate payload the app has seen so far is a test fixture written from the contract.
2. **Edge cases are undocumented:**
   - an issued certificate whose PDF hasn't been uploaded;
   - an archived certificate;
   - another student's certificate number;
   - the exact error codes for each.
3. **Four product decisions are open:** the eligibility rules, what `eligible` means to a student, whether the certificate is per course or per cohort, and the preview artwork.

Two backend changes would make the screen simpler and more robust. They are optional, and each is marked **Proposed** below.

---

## 2. Sources and how much weight each carries

| Source | What it is | Weight |
|---|---|---|
| **Postman workspace, local sync** (`postman/collections/AIAA Backend (prod)/`) | The team's live Postman collection, synced locally. **Gitignored, so not visible in this repo or PR.** Certificate files are dated 2026-09-29; the collection definition 2026-10-08. | **Highest available evidence** that an endpoint exists, with its method and path. It holds **no example responses**. |
| Backend contract `course_learning_api_contract_v1.md` §2.1, §2.9, §4.2, and `mobile_api_v1_1.md` | The backend's canonical JSON shapes, named by the Postman collection itself. **Not in this repo.** Known here through `docs/ai/DATA_AND_API.md`, code comments, and the Issue #155 gap analysis that quoted it. | Authoritative for field names. Every field listed below is cited from these second-hand records. |
| `docs/ai/DATA_AND_API.md` | The app's record of what it consumes. | Records both certificate endpoints as **"documented … not yet verified live"**. |
| PR #245 and its tests | The implementation. | Proves what the app sends and parses, **not** what the server returns. |
| Older in-repo investigations: `course_learning_backend_contract_v1.md` (Issue #56), `course_learning_backend_api_audit_v2.md`, `course_learning_frontend_backend_requirements_v1.md` | Earlier audits. | **Superseded on this topic** (see the conflict below). |
| Postman export `AIAA Backend (prod).postman_collection.json` (workspace root, 2026-09-24) | An older one-file export. | Superseded. |

**Conflict, recorded rather than resolved silently:**
- **Older sources say the student endpoints are missing.** The three older docs and the older one-file export record no student-facing certificate endpoint; they list only the admin **template** endpoints, `GET/PUT/DELETE /courses/{course_id}/templates/cert`.
- **The current evidence says they exist.** The current Postman collection and the backend contract both have `GET /me/courses/{course_slug}/certificate` and `GET /me/certificates/{cert_number}/download`.
- **This document follows the newer evidence.** The older docs predate the backend adding the student certificate endpoints. They should not be read as saying those endpoints don't exist.

---

## 3. Current mobile implementation (traced end to end)

**Entry point:** the "Certificate" row on **Adult Profile** and **Junior Profile** opens `CertificateScreen` (`lib/features/certificates/`). Teacher Profile has no certificate row.

**How the list is built** (`EnrolledCertificateListRepository`). The app reuses existing endpoints because no "my certificates" list exists:

| Step | Call | Used for |
|---|---|---|
| 1 | `GET /me/cohorts` | Which cohorts the student is enrolled in, and the fallback `progress_pct` |
| 2 | `GET /cohorts` (public) | Each cohort's name and course. **Relies on ended cohorts still being listed.** Verified live 2026-10-08: 8 listed, 3 past `end_date`. Whether an *archived* cohort drops out is unknown. |
| 3 | `GET /courses` (public) | The course's current slug (best-effort) |
| 4 | `GET /me/courses/{course_slug}/certificate`, **per enrolled cohort** | Certificate `status`; `cert_number` and `issued_at` when issued |
| 5 | `GET /me/courses/{course_slug}/learning`, **per course not yet issued** | `progress.percent` for the progress bar (best-effort) |

One card is drawn per enrolled cohort. A student with N cohorts costs 3 + up to 2N requests.

**What the screen shows:**

| Server `status` | Card |
|---|---|
| `issued` | Artwork, cohort and course name, "Completed date:" from `issued_at`, and **Download** |
| `not_eligible`, `eligible`, or any unrecognised value | Artwork, progress bar, and **Continue learning** (opens the course's Module List) |

- **`eligible` has no state of its own** in the Figma frame, so it looks the same as `not_eligible`. This is a recorded product decision.
- **Eligibility is never calculated in the app.** The card always follows the server's `status`.

**Download:**
- Each tap calls `GET /me/certificates/{cert_number}/download`, reads `url` and `expires_at`, and opens `url` outside the app (the system browser or viewer).
- The link is never cached.
- A failure shows a generic error message.

**Errors:**
- A course whose certificate answers **403** or **404** is left out, and the other cards still draw.
- Any other failure (401, network, 5xx, malformed body) fails the whole list with a Retry button, so an issued certificate is never hidden behind a "Continue learning" card.

**Not read or drawn:**
- `requirements`, `verify_url` and `has_file`. There is no design for them.

**Shown as fixed artwork, not driven by status:**
- the certificate preview image. It is the same bundled picture for everyone and carries a sample name.
- the Module List certification panel and the Junior Home certificate card.

---

## 4. Backend surface: what is confirmed

| Endpoint | Auth | In Postman | Documented shape | Verified against live API |
|---|---|---|---|---|
| `GET /me/courses/{course_slug}/certificate` | Bearer (student) | **Yes** (Student → Certificates → "My certificate status") | `status`: `not_eligible`, `eligible` or `issued`; `requirements`; `certificate {cert_number, issued_at, verify_url}` when issued; `has_file` (a `mobile_api_v1_1.md` addition) | **No** |
| `GET /me/certificates/{cert_number}/download` | Bearer (student) | **Yes** ("Download my certificate") | `{url, expires_at}`, a pre-signed link | **No** |
| `GET /certificates/verify/{cert_number}` | None | **Yes** (Public → Certificate check; "Public page that confirms a certificate is genuine") | Not recorded | **No** |
| `GET /admin/certificates?course_id=` | Admin (`cohort:manage`) | Yes | Not recorded | No |
| `POST /admin/certificates` `{student_id, course_id, force}` | Admin | Yes. Its Postman description says: "409 not_eligible (with requirements) unless force; 409 already_issued." | Response carries `id` and `cert_number` (the Postman script reads both) | No |
| `PUT /admin/certificates/{cert_id}/file` (form-data `file`) | Admin | Yes. Its description: "PDF, max 20 MB" | Not recorded | No |
| `DELETE /admin/certificates/{cert_id}` ("Archive certificate") | Admin | Yes | Not recorded | No |
| `certificate.status` inside `GET /me/courses/{course_slug}/learning` (§2.1) | Bearer | Yes, as part of `/learning` | Status only, without number or date | Status parsed; certificate part not verified |

**What the admin endpoints tell us about the lifecycle:**
- **Issuing is a separate admin action**, which can be forced past eligibility.
- **The PDF is uploaded in a second step.** So a certificate can exist in the "issued" state before its file does.
- **A certificate can be archived.** None of these behaviours is described from the student's side.

---

## 5. Backend gaps, each with its evidence

Severity:
- **Blocking** — a correct student experience can't be guaranteed without it.
- **Needed** — needed for confident release.
- **Improvement** — optional.

| # | Gap | Evidence | Severity |
|---|---|---|---|
| G1 | **No verified response for either student endpoint.** Postman holds no example responses, and `DATA_AND_API.md` marks both "not yet verified live". The app's parsing rests on the contract text and test fixtures only. | Postman request files have no `response` examples; DATA_AND_API rows 87–88 | **Needed** |
| G2 | **An issued certificate without a file.** Issuing and uploading the PDF are separate admin calls, so `issued` can come before the file. `has_file` is documented, but what `/download` returns when there's no file (status code, `error` code) isn't documented anywhere this repo can see. Today the app shows Download and, on tap, a generic error. | Admin `POST /admin/certificates`, then `PUT …/file`; #155 gap analysis; PR #245 "file missing surfaces as a download error" | **Blocking**, for a correct message to the student |
| G3 | **Archived certificates.** `DELETE /admin/certificates/{cert_id}` archives one. Its effect on the student's `status`, on `/download` and on `/certificates/verify/{cert_number}` isn't documented. | Postman "Archive certificate"; no matching student-side description | **Needed** |
| G4 | **Error and access-control contract for the student endpoints.** Not recorded: the response when a student asks for **another student's** `cert_number`, an unknown one, or an archived one, and whether that is 403 or 404 and with which `error` code. The app assumes the contract's general §2 codes (`403 not_enrolled`, `404 course_not_found`) also apply to `/certificate`; that is unconfirmed. | DATA_AND_API; `EnrolledCertificateListRepository` doc | **Needed** (security review and correct messaging) |
| G5 | **`requirements` item shape.** The contract says the response carries a `requirements` list for the client to render, but the item shape (fields, types, order, localisation) isn't recorded in this repo. No UI can be built without it. | #155 gap analysis; `CourseCertificate` doc ("`requirements` … left unread") | **Needed** before any requirements UI |
| G6 | **Download file details.** Upload is PDF ≤ 20 MB. The download link's `Content-Type`, `Content-Disposition` filename and expiry length aren't documented. | Postman upload description; contract `{url, expires_at}` only | Improvement |
| G7 | **No "my certificates" list.** The app composes 3 + up to 2N calls. It also depends on the **public** `GET /cohorts` still listing ended cohorts; archived cohorts are unknown. A cohort that drops out of `/cohorts` would make an issued certificate vanish from the screen. | §3 above; DATA_AND_API row 56 | Improvement, with a reliability risk |
| G8 | **`/learning` vs `/certificate` consistency.** Both carry a certificate `status`. Whether they come from the same source, and can never disagree, isn't stated. | §2.1 / §2.9 as recorded | Needed (confirmation only) |
| G9 | **No preview of the student's own certificate.** Only the file download exists. The on-screen preview is fixed artwork with a sample name. A real preview would need an image or thumbnail from the backend. | `CertificatePreview`; PR #245 "Artwork" note | Improvement, **only if** product wants it (Q7) |

---

## 6. Proposed requirements

Only what the gaps above justify. Each is labelled with how settled it is.

**R1 — Verified sample responses (G1). Required.**
Provide a real response for each case, from a test student on production or staging:

| Endpoint | Cases |
|---|---|
| `/me/courses/{slug}/certificate` | `not_eligible`, `eligible`, `issued` with a file, `issued` without a file, archived |
| `/me/certificates/{cert_number}/download` | success, no file, another student's number, unknown number, archived |

**R2 — Defined "issued but no file" behaviour (G2). Required; the backend owner chooses the option.** Either:
- **(a)** `/certificate` returns `has_file`, and `/download` returns a **documented** status and `error` code when there's no file; or
- **(b)** the student never sees `issued` until the file exists.

The app will follow whichever is chosen.

**R3 — Documented archived semantics (G3). Required.** What the student sees after an admin archives a certificate: `status`, download result and verify result.

**R4 — Documented error and authorization codes (G4). Required.** For both student endpoints: the status and `error` code for each failure, and confirmation that a student can **never** fetch another student's certificate file.

**R5 — `requirements` item schema (G5).** Required **before** a requirements UI is designed; not needed for the current screen.

**R6 — Optional: a student "my certificates" list (G7). Proposed, not agreed.** One call returning each of the student's certificates (or one entry per enrolled course) with its status and issued details. It would remove the dependency on the public cohort list. The path and shape are for the backend owner to define; nothing here is a proposed contract.

---

## 7. Request and response examples

**Grounded (from Postman):** the paths and methods only.

```
GET  {base_url}/me/courses/{course_slug}/certificate          Authorization: Bearer <student token>
GET  {base_url}/me/certificates/{cert_number}/download        Authorization: Bearer <student token>
GET  {base_url}/certificates/verify/{cert_number}             (no auth)
```

**Illustrative — not verified.** Field names come from the contract as recorded in this repo. **All values are invented placeholders**, and the shape of `requirements` items is unknown, so it is left empty.

```json
// ILLUSTRATIVE ONLY — GET /me/courses/{course_slug}/certificate, status "issued"
{
  "status": "issued",
  "requirements": [],
  "has_file": true,
  "certificate": {
    "cert_number": "<cert_number>",
    "issued_at": "<ISO-8601 timestamp>",
    "verify_url": "<url>"
  }
}
```

```json
// ILLUSTRATIVE ONLY — GET /me/certificates/{cert_number}/download
{ "url": "<pre-signed https URL>", "expires_at": "<ISO-8601 timestamp>" }
```

Where `has_file` sits in the response (top level or inside `certificate`) is **not confirmed** (Q2).

---

## 8. Error handling, authorization and access control: open questions

**What the app does today:**

| Situation | Behaviour |
|---|---|
| 401 | The app tries to renew the session; if that fails, the session ends and the user returns to Login |
| 403 or 404 on `/certificate` | That course is hidden |
| 5xx or network failure | The whole list fails, with Retry |
| Any download failure | Generic message |

**To confirm:** see Q3–Q5 in §10.
- Is `cert_number` guessable? If the public verify page shows personal data, that matters.
- What does `/certificates/verify/{cert_number}` reveal: name, course, date?
- Is it rate-limited?

---

## 9. Acceptance criteria

**Backend (for R1–R4):**
1. Real sample responses for every case in R1 are attached to Issue #155 or a linked backend issue.
2. An issued certificate without a file behaves as documented under R2, and the app can tell this case apart from a network or server error.
3. A request for another student's `cert_number` is refused with a documented status, and no file URL is returned.
4. An archived certificate's student-side behaviour (R3) is documented and matches the samples.
5. `status` from `/learning` and from `/certificate` agree for the same student and course (G8).

**Mobile (after the above):**
1. The app's parsing passes against the real samples, with no change to the documented field names.
2. An issued certificate without a file shows a specific, designed message (or no Download button), not the generic error.
3. No eligibility logic is added to the app; the card always follows the server's `status`.

---

## 10. Questions for the backend owner and product

| # | Question | Owner |
|---|---|---|
| Q1 | Can you provide the R1 sample responses, and a test student with an issued certificate (with and without a file)? | Backend |
| Q2 | Is `has_file` returned by `/certificate`, and where? What does `/download` return when there's no file? | Backend |
| Q3 | What are the exact status and `error` codes for both student endpoints: someone else's certificate, unknown number, archived, no file? | Backend |
| Q4 | What does a student see after a certificate is archived? Is it reissued with a new `cert_number`? | Backend and product |
| Q5 | What does the public verify page return, and is `cert_number` safe to expose (not guessable)? | Backend and security |
| Q6 | Eligibility rules (contract §4.2, marked as needing product sign-off): what makes a student `eligible`? Is issuing automatic, or always an admin action? How long can a student stay `eligible` without a certificate? | Product |
| Q7 | Is the certificate **per course** or **per cohort**? The admin issue call takes `student_id` and `course_id`, but the app shows one card per cohort. A student in two cohorts of the same course would see two cards with one certificate. A retake: same or new certificate? | Product and backend |
| Q8 | What is the `requirements` item schema, and should students see their requirements? | Backend (schema), product and design (UI) |
| Q9 | Should the screen preview the student's own certificate rather than the sample artwork? If so, can the backend provide an image or thumbnail? | Product, then backend |
| Q10 | Is a "my certificates" list endpoint (R6) worth adding? | Backend |

**Dependencies:**
- **R1:** a test account with an issued certificate, which an admin can create with `POST /admin/certificates` plus `PUT …/file`.
- **New UI states:** design frames for any new states (eligible, requirements, no file, verify link).

---

## 11. Frontend follow-up tasks

Each task starts only once its dependency is met.

| # | Task | Depends on |
|---|---|---|
| F1 | Check the app's parsing against the real §2.9 samples and record the result in `DATA_AND_API.md` | R1 |
| F2 | Read `has_file` and handle a certificate with no file (hide or disable Download, show a specific message) | R2, and design for the message |
| F3 | Map the documented certificate error codes to specific messages (archived, not yours, no file) | R3, R4 |
| F4 | Give `eligible` its own state ("awaiting issuance") if product wants one | Q6, design |
| F5 | Requirements UI | R5, Q8, design |
| F6 | Show or share `verify_url` | Q5, design |
| F7 | Avoid duplicate cards when two cohorts share a course, once scope is decided | Q7 |
| F8 | Replace the per-cohort composition with the list endpoint, if R6 is built | R6 |
| F9 | Drive the Module List certification panel and the Junior Home certificate card from `status`; today they are fixed artwork | Design (the #155 gap analysis found no per-status state for either) |
| F10 | Test on a real device with an issued certificate: the download opens the PDF | R1 test account |
