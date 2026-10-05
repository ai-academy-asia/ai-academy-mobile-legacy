# Agent Workflow

> How an AI agent takes a natural-language task from "the user asked for it" to "PR open, waiting for a human" — creating the GitHub Issue and the feature branch itself along the way.
>
> **This file is canonical for the process; it adds no project knowledge.** Modes, the authority order and the safety rules are fixed in [AGENTS.md](../../AGENTS.md); architecture, contracts and the design system live in the documents linked from [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) §6. Each stage below says *which* of them to read and *what to decide*. Where this file and one of those documents disagree on a project fact, the other document wins and this one is what gets corrected.
>
> There is no agent framework, package or automation infrastructure behind this. The "agent" is a Claude/Cursor/Codex session following this document with `git`, `gh` and `flutter`.

## 1. Modes

Three kinds of request exist. Decide which one you have before touching Git or GitHub. The definitions are in [AGENTS.md](../../AGENTS.md) §2; in short:

| | **Agentic mode** (default for change requests) | **Manual mode** | **Read-only request** |
|---|---|---|---|
| Entry point | A natural-language request to change the app — *"add a cancel button to the cohort card"*, *"fix the attendance badge"* — or *"Implement Issue #N"* | The user **explicitly** asks for a manual or isolated operation — *"manual mode"*, *"don't create an Issue"*, *"don't commit"*, *"just edit this file"* — or dictates the Git steps themselves | A question, explanation, audit, review or investigation that changes nothing |
| Who drives | The agent, through the lifecycle in §2 | The developer, step by step | — |
| GitHub Issue | **Created by the agent** (§3.3), or the one the user named | Only if asked | None |
| Feature branch | **Created by the agent** from updated `main` (§3.4) | Only if asked | None |
| Commit / push / PR | **Performed by the agent**, then it stops | Only if explicitly asked; otherwise leave the work uncommitted and report the changed files | None |
| Merge | Human only | Human only | — |
| Safety rules, protected files | Identical in every mode ([AGENTS.md](../../AGENTS.md) §4) | | |

**The human does not create Issues or branches for normal agentic work.** Agentic mode is what makes the agent create the Issue, create the branch, commit, push and open the PR without being asked again. It relaxes nothing in [AGENTS.md](../../AGENTS.md) §4 or [DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md).

Mode boundaries:

- A request that **mentions** an Issue number in passing (*"this is related to #120 — why does the parser fail?"*) is a read-only request, not an instruction to run the lifecycle.
- If it is unclear whether the user wants a change at all, treat the request as read-only and ask before creating anything on GitHub.
- An explicit manual instruction always wins over the default — it is the user's task scope (authority level 2).

## 2. The lifecycle

```
INTAKE → SUFFICIENCY CHECK → ISSUE → BRANCH → INVESTIGATE → GAP ANALYSIS → PLAN
       → IMPLEMENT → VALIDATE ⇄ SELF-FIX → REVIEW DIFF → COMMIT → PUSH → PR → STOP
       └─────────────────────────────── agent ─────────────────────────────────┘
                                                        HUMAN REVIEW → MERGE (human)
```

Stages run in order. Five transitions are gated:

| Gate | Rule |
|---|---|
| Into **ISSUE** | Only once the task is sufficiently specified (§3.2). No Issue is created for a task that is blocked on a question |
| Into **BRANCH** | Only once the Issue exists and its number is known. A branch is never created before its Issue |
| Into **IMPLEMENT** | Not before the gap analysis is done and a plan exists. No code is written during INTAKE … PLAN |
| Into **COMMIT** | Not while a failure *caused by this task* remains. VALIDATE ⇄ SELF-FIX loops until the task is valid |
| Into **MERGE** | Never by the agent. The agent's last action is opening the PR |

Any stage may **stop and report** instead of advancing — see §7. Stopping with a clear report is a correct outcome; guessing past a blocker is not.

### How this maps onto the Git conventions

[DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) §1 fixes the order of Git operations. The lifecycle is that same order with the thinking steps made explicit:

| DEVELOPMENT_RULES §1 | Lifecycle stage |
|---|---|
| 1. The Issue exists before the branch | ISSUE (the agent creates it) |
| 2–4. Update `main`, branch from it, work only on the branch | BRANCH |
| 5. Inspect before modifying | INVESTIGATE + GAP ANALYSIS + PLAN |
| 6. Implement | IMPLEMENT |
| 7. Format / analyze / tests | VALIDATE ⇄ SELF-FIX |
| 8. Review the diff | REVIEW DIFF |
| 9–11. Commit, push, open the PR | COMMIT, PUSH, PR |
| 12. A human reviews and merges | STOP → HUMAN REVIEW → MERGE |

## 3. The stages

### 3.1 INTAKE

Understand the request before touching GitHub. Write down, in your own words:

- **Goal** — one sentence: what the user wants to be true afterwards.
- **Type** — `feat`, `fix`, `chore` or `docs` (it becomes the branch slug's context and the commit prefix).
- **Acceptance criteria** — derived from the request; observable outcomes, not implementation steps.
- **Scope** — what is in, and what the user excluded or clearly did not ask for.
- **Sources the task depends on** — the feature(s), the endpoint(s), the Figma frame(s) supplied.

If the user named an existing Issue (*"Implement Issue #N"*), read it instead — `gh issue view <n> --comments` — and take the goal, criteria, scope and constraints from it. Then skip §3.3 and go to §3.4.

Read only enough of the repository at this stage to understand the request (the feature's directory, [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) §2–§3). Deep investigation comes after the branch exists.

### 3.2 SUFFICIENCY CHECK

Decide whether the task is specified well enough to build safely. It is **sufficient** when:

- the goal and at least one verifiable acceptance criterion can be stated without guessing;
- the affected feature/screen can be identified;
- any data the task needs is confirmed ([DATA_AND_API.md](DATA_AND_API.md)), or can be cleanly left out as a `BACKEND GAP` without defeating the goal;
- any UI the task needs has a supplied Figma frame/export or a documented sibling to mirror ([../design-system/FIGMA_TO_FLUTTER.md](../design-system/FIGMA_TO_FLUTTER.md) §5), or can be left out as `UNKNOWN` without defeating the goal.

Unknowns that **do not block** safe implementation are not a reason to stop: label them `UNKNOWN` / `BACKEND GAP` / `PRODUCT DECISION` ([AGENTS.md](../../AGENTS.md) §3) and carry them into the Issue.

Unknowns that **do block** — the goal itself is ambiguous, two readings would produce different products, the core requirement is a `BACKEND GAP`, or UI is the point of the task and there is no frame and no sibling — mean **ask the user before creating the Issue**. Ask one focused question with concrete options. Do not open an Issue that would only say "unclear".

### 3.3 ISSUE — the agent creates it

First check that the work is not already tracked:

```bash
gh issue list --state open --search "<key words>"
```

- If an open Issue **clearly** covers the same task, use it (read it with `--comments`), say so in the report, and go to §3.4.
- If one only overlaps, create a new Issue and reference the related one.

Otherwise create the Issue. Follow the house style of recent Issues: a plain, sentence-case title that states the outcome (no type prefix, no labels — the repository uses none), and a structured body:

```bash
gh issue create --title "<Outcome, sentence case>" --body "$(cat <<'EOF'
## Problem / goal
<what is wrong or missing, and what should be true afterwards>

## Acceptance criteria
- [ ] <observable outcome>
- [ ] <observable outcome>

## Scope
In: <…>
Out: <…, including anything the user excluded>

## Sources
- Contract: <DATA_AND_API.md § / contract doc § / Postman request> — or "none needed"
- Design: <supplied Figma frame/export, "App UI" page> — or "no UI change" / "mirrors <sibling>"

## Unknowns
- UNKNOWN / BACKEND GAP / PRODUCT DECISION: <item> — <what would settle it>

_Created by an AI agent from the request: "<the user's request, quoted briefly>"._
EOF
)"
```

Rules for the Issue body:

- **Only confirmed facts are stated as facts.** Every unconfirmed endpoint, field, rule or visual is in *Unknowns* with its label — an Issue is not a place to launder an assumption into a requirement.
- Criteria the agent derived (rather than the user stating them) are fine — the Issue is the record of how the request was understood, and the human sees it at review.
- No secrets, tokens, test-account passwords or personal data in the Issue.

Record the Issue number; every later stage uses it. The agent does not close, label, assign or edit other Issues.

### 3.4 BRANCH

```bash
git status                                   # understand every modified file first
git fetch origin
git switch main && git pull --ff-only origin main
git switch -c feature/<issue-number>-<slug>  # e.g. feature/<n>-cancel-enrollment
```

- `<slug>` is short, lowercase, hyphenated, derived from the Issue title.
- The three protected iOS files ([AGENTS.md](../../AGENTS.md) §4) are modified locally and travel with the working tree across `git switch`; that is expected.
- **Any other uncommitted change** in the working tree at this point is not yours: stop and report it. Do not stash, discard or commit it.
- **If any of these commands refuses to run** — the protected files block a switch, `pull --ff-only` cannot fast-forward — stop and report. Do not stash, reset or check out files to get past it.
- If a branch for the Issue already exists, continue on it rather than creating a second one.
- If your **own** uncommitted work must come along (e.g. a manual-mode change being promoted to agentic) and `git switch main` refuses because local `main` is behind, fast-forward the ref without switching — `git fetch origin main:main` (it refuses anything but a fast-forward) — then switch, `git pull --ff-only` as a no-op check, and branch.

### 3.5 INVESTIGATE

Load what the task needs — not the repository.

| The task involves | Read |
|---|---|
| Anything | [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) §2–§5, [DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) |
| Code structure, controllers, tests | [ARCHITECTURE.md](ARCHITECTURE.md) |
| An endpoint, a model, a failure type | [DATA_AND_API.md](DATA_AND_API.md), plus the contract document or Postman request the task relies on |
| UI | [../design-system/FIGMA_TO_FLUTTER.md](../design-system/FIGMA_TO_FLUTTER.md) first, then `DESIGN_SYSTEM.md`, `COMPONENT_PATTERNS.md`, `SCREEN_PATTERNS.md` as needed; the Figma frames/exports supplied in the task ("App UI" page only) |
| `course_learning` backend work | the `docs/course_learning_*` documents named in [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) §2 |

Then the code itself, narrowly: the feature directory under `lib/features/<feature>/`, its mirror under `test/features/<feature>/`, and the history of what you are about to change:

```bash
git log --oneline -- lib/features/<feature>
gh pr list --state all --search "<feature keyword>"
```

**The code is the final word on what is implemented** (authority level 5). Documents describe the codebase at the time they were written and can lag behind it; [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) §4 already warns that doc comments drift. When a document and the code disagree about what exists, believe the code and note the drift in the final report. That is about *implementation state* only — it never makes existing UI the visual authority or an unconfirmed field a contract.

### 3.6 GAP ANALYSIS

Answer each question by inspection, per acceptance criterion. "Probably" is not an answer.

| Question | How to establish it |
|---|---|
| What already exists / is partial / is missing? | Read the feature's `data/`, `domain/`, `presentation/` |
| Is the UI present? | The screen or widget exists and is reachable by navigation |
| **Does the UI actually do the thing?** | Follow the tap: widget callback → controller method → repository call. A callback that only flips local widget state is *UI only* |
| Is API integration present? | An `Http*Repository` method calls the endpoint — not the sample repository, not a delegate to it |
| Is repository support present? | The method is on the `domain/` interface, the HTTP implementation, **and** the `fake_*` test double |
| Is controller/state handling complete? | The controller shape in [ARCHITECTURE.md](ARCHITECTURE.md) §2; typed failure mapped to `errorMessage` |
| Loading / empty / error / success handled? | The trio in [../design-system/COMPONENT_PATTERNS.md](../design-system/COMPONENT_PATTERNS.md) §6, plus the success outcome of a write |
| Are tests present? | Controller, repository and widget suites for the changed behaviour ([ARCHITECTURE.md](ARCHITECTURE.md) §7) |
| Is visual verification required? | Yes whenever pixels change |
| Is there a backend/API gap? | The endpoint and every field used are confirmed per [DATA_AND_API.md](DATA_AND_API.md) §8 |

Classify each acceptance criterion as exactly one of:

- **DONE** — already satisfied. Do not rebuild it.
- **PARTIAL** — say precisely what is missing (typically: UI exists, no wiring).
- **MISSING** — nothing exists.
- **BACKEND GAP** — cannot be completed from confirmed contracts.
- **PRODUCT DECISION** — needs a product/design owner's choice (behaviour, copy, scope).
- **UNKNOWN** — not determinable from the repository, a contract, Figma or the task; say what would confirm it.

Two outcomes deserve care. If **everything is DONE**, do not manufacture a change — comment the evidence on the Issue, report that it is already satisfied, and stop without a commit or PR (the empty feature branch stays local; closing the Issue is the human's call). If a criterion is a **BACKEND GAP** or **PRODUCT DECISION**, implement what is confirmed, leave the gap unimplemented, and carry it into the PR description; never fill it with an invented endpoint, field or behaviour.

### 3.7 PLAN

Turn the PARTIAL and MISSING rows into a concrete list:

- files and components to modify;
- new files, **only** where nothing existing fits — with the reason (the house rule: when you do not reuse, say why);
- repository / API changes, each tied to a confirmed contract;
- controller and state changes;
- UI changes;
- tests to add or extend;
- documents to update because they describe behaviour that changes;
- the validation that will prove it (§3.9).

Every planned change must trace back to an acceptance criterion. A change that does not is out of scope — drop it, or mention it in the report as a follow-up. No speculative changes, no opportunistic refactors, no new dependency the task did not ask for.

State the plan briefly before implementing, so a human reading the session can see what was intended.

### 3.8 IMPLEMENT

Build to the plan, in the existing patterns.

- **UI** — Figma (the supplied frames/exports) is the visual source of truth; existing Flutter UI is implementation context. Follow [../design-system/FIGMA_TO_FLUTTER.md](../design-system/FIGMA_TO_FLUTTER.md), including its rule on states the frame does not show. Do not claim visual fidelity you have not verified.
- **Data** — confirmed contracts only. Follow the repository pattern and the rules in [DATA_AND_API.md](DATA_AND_API.md) §8; map failures into that feature's own failure type, and let the controller turn them into `errorMessage`.
- **Functionality** — do not stop at the UI. Wire the interaction through controller and repository, then confirm the action produces the intended result (a test that asserts the repository was called and the state changed, not just that a button renders).
- **Tests** — alongside the code, reusing the feature's existing `fake_*` double.
- **Docs** — update the canonical document that describes the behaviour you changed, in the same change.

If implementation reveals the plan was wrong — a contract is not what the task assumed, the screen already does more than the gap analysis found — go back to GAP ANALYSIS and re-plan. If that changes the acceptance criteria, add a comment to the Issue saying so. Do not improvise past it.

### 3.9 VALIDATE

The commands and known pre-existing results are defined in [DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) §5; use them as written there.

| Change | Validation |
|---|---|
| Any | `dart format <files you edited>` (never `dart format lib/`), then `flutter analyze` |
| Code in a feature | `flutter test test/features/<feature>` |
| Broad — `core/`, `shared/`, several features | full `flutter test` |
| Visual | see it rendered — golden capture or simulator — and compare to the frame ([../design-system/FIGMA_TO_FLUTTER.md](../design-system/FIGMA_TO_FLUTTER.md) §7); otherwise state that it was not verified |
| Platform config, assets, dependencies | a build (`flutter build apk --debug`, or an iOS simulator build), when the environment allows |
| Documentation / AI-configuration only | `flutter analyze` (proves nothing in `lib/` moved) and a check that every relative link resolves |

### 3.10 SELF-FIX

For every failure, decide first **whose it is**:

1. **Is it in the known pre-existing list** ([DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) §5)? Pre-existing. Leave it.
2. **Does it touch files or behaviour this task changed?** Task-caused. Fix it.
3. **Unsure?** Check whether it also fails without your change — read the failing test and the code it exercises, and check whether your diff reaches either. Do **not** use `git stash` or discard your work to find out.

Fix task-caused failures, re-run the validation that failed, and repeat until clean. Then run the whole relevant set once more, since a fix can break something else.

Rules of the loop:

- **Fix the cause, not the signal.** Never delete, skip or weaken a test, add an `// ignore:`, or loosen an assertion to get green — unless the test itself asserted behaviour the task deliberately changes.
- **Do not fix unrelated pre-existing failures**, however small. Report them as pre-existing.
- **A failure that is neither on the known list nor caused by the task** is a new finding: leave it, and report it prominently.
- **Three failures of the same type** — the same failure surviving three genuine attempts, or the same Git/`gh` command refused three times — **stop and report** what was tried (§7). Do not commit a broken state.

### 3.11 REVIEW DIFF

```bash
git status
git diff
```

Check, before anything is staged:

- [ ] Only files the plan named are changed
- [ ] The three protected iOS files still show as modified and are **not** part of what will be committed
- [ ] No unrelated refactor, reformatting or drive-by fix
- [ ] No accidental generated or scratch files (golden scratch harnesses, build output, a newly generated `Podfile`, IDE files)
- [ ] No `TODO`/`FIXME` introduced in `lib/` or `test/`; no secrets or tokens
- [ ] Tests match the behaviour implemented; any document that described the old state is updated

### 3.12 COMMIT

**Stage explicit paths.** Never `git add -A`, `git add .` or `git commit -a` — each would sweep the protected iOS files into the commit.

```bash
git add <path> <path> …
git status            # staged set is exactly the task; protected files remain unstaged
git commit -m "feat: add enrollment cancel action (#<n>)"
```

Subject format is the repository convention — lowercase, type-prefixed, imperative, ending with the Issue number: `feat: … (#N)`, `fix: … (#N)`, `docs: … (#N)`, `chore: … (#N)`. One focused commit per Issue is the norm; add another only when it is a genuinely separate step.

### 3.13 PUSH

```bash
git push -u origin feature/<issue-number>-<slug>
```

Only the feature branch. Never `main`. Never `--force` / `--force-with-lease`. If the push is rejected, stop and report — do not rewrite history to make it go through.

### 3.14 PR

```bash
gh pr create --base main --title "<same as the commit subject>" --body "$(cat <<'EOF'
…
EOF
)"
```

The description contains:

- **What changed** and **why**, tied to the Issue's acceptance criteria
- **Validation performed**, with actual results — and what was *not* verified (e.g. "not visually verified on a device")
- **Known / pre-existing issues**, separated from anything this task caused
- **`UNKNOWN` / `BACKEND GAP` / `PRODUCT DECISION`** items, if any
- **Protected local files untouched** — stated explicitly
- `Closes #<issue-number>`

### 3.15 STOP → HUMAN REVIEW → MERGE

**After the PR is open, stop.** Report (§8) and wait.

The agent does not merge, approve, enable auto-merge, or close the Issue. A human developer reviews and merges. If review asks for changes, that is a new instruction: make them on the same branch, re-run VALIDATE, push a follow-up commit (not an amended, force-pushed one), and stop again.

## 4. When is an Issue complete

An Issue is complete when, **for the Issue's scope**, all of these hold:

- [ ] Required UI is implemented and matches the supplied Figma frame — verified, or the gap stated
- [ ] Interactions perform the real action, not just a local visual change
- [ ] Required API integration is wired against confirmed contracts
- [ ] Controller state covers loading / empty / error / success as applicable
- [ ] Tests cover the new behaviour and pass
- [ ] `flutter analyze` shows nothing new; validation is clean apart from documented pre-existing results
- [ ] Every acceptance criterion is DONE, or explicitly reported as BACKEND GAP / PRODUCT DECISION / UNKNOWN

**A screen that renders is not a completed Issue.** Equally, an Issue whose remaining criteria are blocked on a `BACKEND GAP` or `PRODUCT DECISION` is not silently "done": the PR says which criteria are met and which are blocked, and leaves the decision to the reviewer.

## 5. Git and GitHub behaviour at a glance

| The agent does, in agentic mode | Never, in any mode |
|---|---|
| Create the Issue from the user's request (after a duplicate check) | Create a branch before its Issue exists |
| Create `feature/<issue>-<slug>` from updated `main` | Commit or work on `main`; delete `main` |
| Commit on the feature branch, explicit paths | `git add -A` / `git add .` / `git commit -a` |
| Push the feature branch to `origin` | Push to `main`; any force push |
| Open a PR with `Closes #<issue>` | Merge, auto-merge or approve a PR |
| Comment on its own Issue when scope changes | Close, label or edit other people's Issues |
| Follow-up commits after review | Amend/rebase already-pushed history |

In manual mode the left column happens only when the user asks for it; the right column never changes.

## 6. Safety rules

The canonical list is [AGENTS.md](../../AGENTS.md) §4; it holds in every mode and is never overridden by a task or an Issue's text. Lifecycle-specific reminders:

- The three protected iOS files are modified before and after every task. They ride along across `git switch`, are never staged, and every report lists them as *pre-existing, protected, untouched*. Background on what they contain: [DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) §3.
- A Git command that is refused is a stop condition, not a puzzle to route around.
- **Never invent** an endpoint, response field, status code, business rule, user data or design value — not in code, not in the Issue, not in the PR.

## 7. When to stop and ask

Autonomy ends where a guess would begin. Stop, report what was found, and wait when:

- **before ISSUE:** the goal is ambiguous enough that two readings would build different things, or no acceptance criterion can be stated without guessing (§3.2);
- the task's core requirement is a `BACKEND GAP` or `PRODUCT DECISION` — nothing meaningful can be built from what is confirmed;
- UI is the point of the task but no Figma frame/export was supplied and no documented sibling exists to mirror;
- the task would require a new dependency, a change to a protected file, or a destructive command;
- the working tree holds uncommitted changes that are not the protected files and not yours;
- a Git or `gh` command is refused (switch blocked, pull cannot fast-forward, push rejected, merge conflict with `main`);
- three failures of the same type (§3.10);
- the work is turning out materially larger than the Issue describes.

Where the stop happens after the Issue exists, add a short comment to the Issue saying what blocked. Work completed up to that point stays on the feature branch, uncommitted unless it is valid.

## 8. Final report

The format in [DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) §7, plus the GitHub results:

- Issue number (created or reused) and branch name
- changed files
- implementation summary (against the acceptance criteria)
- validation results — task-caused vs. pre-existing
- commit hash and PR number
- remaining issues / `UNKNOWN` / `BACKEND GAP` / `PRODUCT DECISION`
- the three protected iOS files: pre-existing, protected, untouched

## 9. Worked example

> The user writes: **"Students should be able to cancel an enrollment from the cohort list."** Illustrative only; it is not a record of real work, and the numbers are hypothetical.

**INTAKE.** Goal: an enrolled student can cancel from the cohort list. Type `feat`. Derived criteria: a cancel action on an enrolled cohort; the list updates afterwards; failures are shown. Scope: `enrollments` and the cohort list; no card redesign. Sources: `DELETE /cohorts/{cohort_id}/enroll`; no Figma frame supplied.

**SUFFICIENCY CHECK.** [DATA_AND_API.md](DATA_AND_API.md) §2 lists the endpoint as verified-but-unconsumed — the data side is buildable. The button has no frame and no sibling: that blocks *the button's visual*, not the goal, so it becomes an `UNKNOWN` carried into the Issue. Whether a cancelled student should see a confirmation dialog is a `PRODUCT DECISION`. Sufficient to proceed.

**ISSUE.** `gh issue list --search "cancel enrollment"` finds nothing. `gh issue create --title "Cancel an enrollment from the cohort list"` with the criteria above, the endpoint as the contract source, and two Unknowns: the button's visual (no frame) and the confirmation step. → Issue #<n> (its number is whatever GitHub assigns).

**BRANCH.** `git fetch`, `git switch main && git pull --ff-only`, `git switch -c feature/<n>-cancel-enrollment`; the three iOS files ride along, modified.

**INVESTIGATE / GAP ANALYSIS.**

| Criterion | Finding |
|---|---|
| Cancel action in the UI | **MISSING** — visual **UNKNOWN** (no frame); confirmation step **PRODUCT DECISION** |
| Repository support | **MISSING** — `EnrollmentRepository` has `enroll` only |
| API contract | Endpoint confirmed. Success status and response body **UNKNOWN** — and `api_client.dart` has no `DELETE` helper yet |
| Failure mapping | **PARTIAL** — `EnrollmentFailure` exists; which status means "cannot cancel" is **UNKNOWN** |
| Tests | **MISSING** |

**PLAN.** Add `cancel(cohortId)` to the interface, HTTP repository and the fake; map 401/network/server the way `enroll` already does and treat any other non-2xx as `rejected` rather than inventing finer cases; controller method plus list reload; repository and controller tests. The button's appearance has no frame — a stop condition **for the UI part only** (§7). Decision: implement the data and controller layers, and leave the button for the reviewer to decide.

**IMPLEMENT → VALIDATE → SELF-FIX.** `flutter analyze` reports an unused import in the new file — task-caused, fixed, re-run clean. `flutter test test/features/enrollments` passes. Full suite: the one known `course_catalog_screen_test.dart` failure — pre-existing, left alone.

**REVIEW DIFF → COMMIT → PUSH → PR.** Five files under `enrollments`. Staged by path; iOS files unstaged. `feat: add enrollment cancel repository support (#<n>)`, pushed, PR opened with `Closes #<n>` — stating that the cancel **button** is not implemented (no frame), the confirmation step is a `PRODUCT DECISION`, and the success response shape is `UNKNOWN`.

**STOP.** The reviewer decides whether to merge the data layer alone or supply the frame first.

The point of the example: from one sentence, the agent created the Issue and branch, drove the whole lifecycle, shipped only what was confirmed, and surfaced what it could not know instead of guessing it.
