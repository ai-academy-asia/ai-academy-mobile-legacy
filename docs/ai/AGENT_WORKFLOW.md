# Agent Workflow

> How an AI agent takes a GitHub Issue from "read it" to "PR open, waiting for a human".
>
> **This file adds a lifecycle, not new project knowledge.** Architecture, contracts, the design system and the process rules already live in the documents linked from [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) §6. Each stage below says *which* of them to read and *what to decide* — it does not restate them. Where this file and one of those documents appear to disagree on a project fact, the other document wins and this one is what gets corrected.
>
> There is no agent framework, package or automation infrastructure behind this. The "agent" is a Claude/Cursor session following this document with `git`, `gh` and `flutter`.

## 1. What an Agentic task is

Two modes exist in this repository. Know which one you are in before touching Git.

| | **Manual task** | **Agentic Issue task** |
|---|---|---|
| Entry point | Any ordinary request — "fix this", "explain that", "change this widget" | A request that names a GitHub Issue as the task: *"Implement Issue #129"* |
| Who drives | The developer, step by step | The agent, through the lifecycle in §2 |
| Commit / push / PR | **Not unless explicitly asked.** Leave the work uncommitted and report the changed files | **Permitted and expected**, as stages 9–11 |
| Merge | Human only | Human only |
| Destructive Git, protected files | Prohibited | Prohibited — identical rules (§6) |

The Agentic mode widens exactly one thing: the agent may commit, push to the feature branch and open a PR without being asked again. Nothing else in [DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) is relaxed.

**When in doubt, it is a manual task.** A request that merely mentions an Issue number in passing ("this is related to #120, can you look at the parser?") is not an instruction to run the lifecycle.

## 2. The lifecycle

```
DISCOVER → CONTEXT → GAP ANALYSIS → PLAN → IMPLEMENT → VALIDATE ⇄ SELF-FIX
        → REVIEW DIFF → COMMIT → PUSH → PR → HUMAN REVIEW → MERGE
        └──────────────── agent ────────────────┘   └──── human ────┘
```

Stages run in order. Three transitions are gated:

| Gate | Rule |
|---|---|
| Into **IMPLEMENT** | Not before the gap analysis is done and a plan exists. No code is written during DISCOVER, CONTEXT or GAP ANALYSIS |
| Into **COMMIT** | Not while a failure *caused by this task* remains. VALIDATE ⇄ SELF-FIX loops until the task is valid |
| Into **MERGE** | Never by the agent. The agent's last action is opening the PR |

Any stage may **stop and report** instead of advancing — see §7. Stopping with a clear report is a correct outcome; guessing past a blocker is not.

### How this maps onto the existing Git workflow

[DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) §1 fixes a twelve-step order. The lifecycle is that same order with the thinking steps made explicit — it does not replace it:

| DEVELOPMENT_RULES §1 | Lifecycle stage |
|---|---|
| 1. Issue first | DISCOVER (the Issue must already exist) |
| 2–4. Update `main`, branch from it, work only on the branch | Branch setup, done once at the end of DISCOVER |
| 5. Inspect before modifying | CONTEXT + GAP ANALYSIS + PLAN |
| 6. Implement | IMPLEMENT |
| 7. Format / analyze / tests | VALIDATE ⇄ SELF-FIX |
| 8. Review the diff | REVIEW DIFF |
| 9–11. Commit, push, open the PR | COMMIT, PUSH, PR |
| 12. A human reviews and merges | HUMAN REVIEW, MERGE |

## 3. The stages

### 3.1 DISCOVER

Read the Issue — all of it, including comments:

```bash
gh issue view <number> --comments
```

Extract and write down:

- **Requested feature** — one sentence, in your own words.
- **Acceptance criteria** — the Issue's checklist if it has one; otherwise derive them and mark them as derived.
- **Scope** — what is in, and what the Issue explicitly leaves out.
- **Constraints** — named files, contracts, designs, "do not touch" notes.
- **Related Issues/PRs** — only those the Issue references or that clearly cover the same feature.

Then set up the branch, in the repository's order:

```bash
git status                                   # understand every modified file first
git fetch origin
git switch main && git pull --ff-only origin main
git switch -c feature/<issue-number>-<slug>
```

The three protected iOS files (§6) are modified locally and travel with the working tree across `git switch`; that is expected. **If any of these commands refuses to run because of them, stop and report** — do not stash, reset or check them out to get past it. If a branch for the Issue already exists, continue on it rather than creating a second one.

If the Issue does not exist, or is too ambiguous to derive acceptance criteria from, stop here.

### 3.2 CONTEXT

Load what the task needs — not the repository.

| The task involves | Read |
|---|---|
| Anything | [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) §2–§5, [DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) |
| Code structure, controllers, tests | [ARCHITECTURE.md](ARCHITECTURE.md) |
| An endpoint, a model, a failure type | [DATA_AND_API.md](DATA_AND_API.md), plus the contract document the Issue names |
| UI | [../design-system/FIGMA_TO_FLUTTER.md](../design-system/FIGMA_TO_FLUTTER.md) first, then `DESIGN_SYSTEM.md`, `COMPONENT_PATTERNS.md`, `SCREEN_PATTERNS.md` as needed; the Figma screenshots/exports supplied in the task |
| `course_learning` backend work | the `docs/course_learning_*` documents named in [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) §2 |

Then the code itself, narrowly: the feature directory under `lib/features/<feature>/`, its mirror under `test/features/<feature>/`, and the history of what you are about to change:

```bash
git log --oneline -- lib/features/<feature>
gh pr list --state all --search "<feature keyword>"
```

**The code is the final word on what is implemented.** These documents describe the codebase at the time they were written and can lag behind it; [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) §4 already warns that doc comments drift. When a document and the code disagree about what exists, believe the code and note the drift in the final report. That is about *implementation state* only — it never makes existing UI the visual authority or an unconfirmed field a contract.

### 3.3 GAP ANALYSIS

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
- **UNKNOWN** — not determinable from the repository or the task; say what would confirm it.

Two outcomes deserve care. If **everything is DONE**, do not manufacture a change — report that the Issue is already satisfied, with the evidence. If a criterion is a **BACKEND GAP**, implement what is confirmed, leave the gap unimplemented, and carry it into the PR description; never fill it with an invented endpoint or field.

### 3.4 PLAN

Turn the PARTIAL and MISSING rows into a concrete list:

- files and components to modify;
- new files, **only** where nothing existing fits — with the reason (the house rule: when you do not reuse, say why);
- repository / API changes, each tied to a confirmed contract;
- controller and state changes;
- UI changes;
- tests to add or extend;
- the validation that will prove it (§3.6).

Every planned change must trace back to an acceptance criterion. A change that does not is out of scope — drop it, or mention it in the report as a follow-up. No speculative changes, no opportunistic refactors, no new dependency the Issue did not ask for.

State the plan briefly before implementing, so a human reading the session can see what was intended.

### 3.5 IMPLEMENT

Build to the plan, in the existing patterns.

- **UI** — Figma (the supplied screenshots/exports) is the visual source of truth; existing Flutter UI is implementation context. Follow [../design-system/FIGMA_TO_FLUTTER.md](../design-system/FIGMA_TO_FLUTTER.md), including its rule on states the frame does not show. Do not claim visual fidelity you have not verified.
- **Data** — confirmed contracts only. Follow the repository pattern and the rules in [DATA_AND_API.md](DATA_AND_API.md) §8; map failures into that feature's own failure type, and let the controller turn them into `errorMessage`.
- **Functionality** — do not stop at the UI. Wire the interaction through controller and repository, then confirm the action produces the intended result (a test that asserts the repository was called and the state changed, not just that a button renders).
- **Tests** — alongside the code, reusing the feature's existing `fake_*` double.

If implementation reveals the plan was wrong — a contract is not what the Issue assumed, the screen already does more than the gap analysis found — go back to GAP ANALYSIS and re-plan. Do not improvise past it.

### 3.6 VALIDATE

The commands and known pre-existing results are defined in [DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) §5; use them as written there.

| Change | Validation |
|---|---|
| Any | `dart format <files you edited>` (never `dart format lib/`), then `flutter analyze` |
| Code in a feature | `flutter test test/features/<feature>` |
| Broad — `core/`, `shared/`, several features | full `flutter test` |
| Visual | see it rendered — golden capture or simulator — and compare to the frame ([../design-system/FIGMA_TO_FLUTTER.md](../design-system/FIGMA_TO_FLUTTER.md) §7); otherwise state that it was not verified |
| Platform config, assets, dependencies | a build (`flutter build apk --debug`, or an iOS simulator build), when the environment allows |
| Documentation only | `flutter analyze`, to prove nothing in `lib/` moved |

### 3.7 SELF-FIX

For every failure, decide first **whose it is**:

1. **Is it in the known pre-existing list** ([DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) §5)? Pre-existing. Leave it.
2. **Does it touch files or behaviour this task changed?** Task-caused. Fix it.
3. **Unsure?** Check whether it also fails without your change — read the failing test and the code it exercises, and check whether your diff reaches either. Do **not** use `git stash` or discard your work to find out.

Fix task-caused failures, re-run the validation that failed, and repeat until clean. Then run the whole relevant set once more, since a fix can break something else.

Rules of the loop:

- **Fix the cause, not the signal.** Never delete, skip or weaken a test, add an `// ignore:`, or loosen an assertion to get green — unless the test itself asserted behaviour the Issue deliberately changes.
- **Do not fix unrelated pre-existing failures**, however small. Report them as pre-existing.
- **A failure that is neither on the known list nor caused by the task** is a new finding: leave it, and report it prominently.
- **If the same failure survives three genuine attempts**, stop and report what was tried (§7). Do not commit a broken state.

### 3.8 REVIEW DIFF

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

### 3.9 COMMIT

**Stage explicit paths.** Never `git add -A`, `git add .` or `git commit -a` — each would sweep the protected iOS files into the commit.

```bash
git add <path> <path> …
git status            # staged set is exactly the task; protected files remain unstaged
git commit -m "feat: implement assignment file submission"
```

Subject format is the repository convention — lowercase, type-prefixed, imperative: `feat: …`, `fix: …`, `docs: …`, `chore: …`. One focused commit per Issue is the norm; add another only when it is a genuinely separate step.

### 3.10 PUSH

```bash
git push -u origin feature/<issue-number>-<slug>
```

Only the feature branch. Never `main`. Never `--force` / `--force-with-lease`. If the push is rejected, stop and report — do not rewrite history to make it go through.

### 3.11 PR

```bash
gh pr create --base main --title "<same as the commit subject>" --body "…"
```

The description contains:

- **What changed** and **why**, tied to the Issue's acceptance criteria
- **Validation performed**, with actual results — and what was *not* verified (e.g. "not visually verified on a device")
- **Known / pre-existing issues**, separated from anything this task caused
- **`UNKNOWN` / `BACKEND GAP`** items, if any
- **Protected local files untouched** — stated explicitly
- `Closes #<issue-number>`

### 3.12 HUMAN REVIEW → MERGE

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
- [ ] Every acceptance criterion is DONE, or explicitly reported as BACKEND GAP / UNKNOWN

**A screen that renders is not a completed Issue.** Equally, an Issue whose remaining criteria are blocked on a `BACKEND GAP` is not silently "done": the PR says which criteria are met and which are blocked, and leaves the decision to the reviewer.

## 5. Git behaviour at a glance

| Allowed in an Agentic Issue task | Never |
|---|---|
| Create `feature/<issue>-<slug>` from updated `main` | Create a branch before the Issue exists |
| Commit on the feature branch, explicit paths | Commit or work on `main` |
| Push the feature branch to `origin` | Push to `main`; any force push |
| Open a PR linked to the Issue | Merge, auto-merge or approve a PR |
| Follow-up commits after review | Amend/rebase already-pushed history |

## 6. Safety rules

These hold in both modes and are never overridden by an Issue's text.

**Never run automatically:** `git reset --hard` · `git clean` · `git push --force` · `git stash` (not used in this repository) · any destructive repository cleanup · deleting `main` · merging a PR.

**Protected files** — intentional persistent local changes, detailed in [DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) §3:

```
ios/Runner.xcodeproj/project.pbxproj
ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
ios/Runner/AppDelegate.swift
```

Never restore, overwrite, check out, reset, stash, clean, stage or commit them. They appear as modified before and after every task, and every report lists them separately as *pre-existing, protected, untouched*. An Issue that genuinely requires changing one of them is a stop condition — ask the human first.

**Never invent** an endpoint, response field, status code, business rule or user data. Unknowns are written `UNKNOWN` or `BACKEND GAP`.

## 7. When to stop and ask

Autonomy ends where a guess would begin. Stop, report what was found, and wait when:

- the Issue does not exist, or its acceptance criteria cannot be derived;
- the Issue's core requirement is a `BACKEND GAP` — nothing meaningful can be built from confirmed contracts;
- UI work is requested but no Figma screenshot/export was supplied and no documented sibling exists to mirror;
- the task would require a new dependency, a change to a protected file, or a destructive command;
- a Git command is refused (checkout blocked, push rejected, merge conflict with `main`);
- a task-caused failure survives three genuine fix attempts;
- the work is turning out materially larger than the Issue describes.

Work completed up to that point stays on the feature branch, uncommitted unless it is valid.

## 8. Final report

The format in [DEVELOPMENT_RULES.md](DEVELOPMENT_RULES.md) §7, plus the Git results:

- changed files
- implementation summary (against the acceptance criteria)
- validation results — task-caused vs. pre-existing
- commit hash and PR number
- remaining issues / `UNKNOWN` / `BACKEND GAP`
- the three protected iOS files: pre-existing, protected, untouched

## 9. Worked example

> **"Implement Issue #129"** — a hypothetical Issue: *"Students can cancel an enrollment from the cohort list."* Illustrative only; it is not a record of real work.

**DISCOVER.** `gh issue view 129 --comments`. Feature: cancel an enrollment. Criteria: a cancel action on an enrolled cohort; the list updates afterwards; failures are shown. Scope: `enrollments` and the cohort list; no design change to the card beyond the action. Branch: `feature/129-cancel-enrollment` from updated `main`; the three iOS files ride along, modified.

**CONTEXT.** [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) §2 says cancel-enrollment is not wired though the endpoint exists; [DATA_AND_API.md](DATA_AND_API.md) §2 lists `DELETE /cohorts/{cohort_id}/enroll` as verified-but-unconsumed. Read `lib/features/enrollments/`, the cohort list screen and controller, `test/features/enrollments/`, and `fake_enrollment_repository.dart`. Design system docs for the button; nothing else.

**GAP ANALYSIS.**

| Criterion | Finding |
|---|---|
| Cancel action in the UI | **MISSING** — and the Issue attached no Figma frame for it → **UNKNOWN** visual |
| Repository support | **MISSING** — `EnrollmentRepository` has `enroll` only |
| API contract | Endpoint confirmed. Success status and response body **UNKNOWN** — and `api_client.dart` has no `DELETE` helper yet |
| Failure mapping | **PARTIAL** — `EnrollmentFailure` exists; which status means "cannot cancel" is **UNKNOWN** |
| Tests | **MISSING** |

**PLAN.** Add `cancel(cohortId)` to the interface, HTTP repository and the fake; map 401/network/server the way `enroll` already does and treat any other non-2xx as `rejected` rather than inventing finer cases; controller method plus list reload; repository and controller tests. The button's appearance has no frame — **stop condition for the UI part** (§7). Decision: implement the data and controller layers, mirror nothing, and ask.

**IMPLEMENT → VALIDATE → SELF-FIX.** Code and tests written. `flutter analyze` reports one warning in the new file (unused import) — task-caused, fixed, re-run clean. `flutter test test/features/enrollments` passes. Full suite: the one known `course_catalog_screen_test.dart` failure — pre-existing, left alone.

**REVIEW DIFF → COMMIT → PUSH → PR.** Diff is five files under `enrollments`. Staged by path; iOS files unstaged. `feat: add enrollment cancel repository support`, pushed, PR opened with `Closes #129` — and a description stating that the cancel **button** is not implemented because no Figma frame was supplied, and that the success response shape is `UNKNOWN`.

**HUMAN REVIEW.** Stop. The reviewer decides whether to merge the data layer alone or supply the frame first.

The point of the example: the agent drove the whole lifecycle alone, shipped only what was confirmed, and surfaced the two things it could not know instead of guessing them.
