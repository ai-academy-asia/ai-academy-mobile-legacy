# Development Rules

> Non-negotiable process rules. The modes, the authority order and the canonical safety list are in the repository root [AGENTS.md](../../AGENTS.md); this document holds the detail behind them and never contradicts it.

## 1. Git workflow (non-negotiable)

Every change that reaches `main` goes through this order:

1. **A GitHub Issue exists for the work.** In agentic mode **the agent creates it** from the user's request ([AGENT_WORKFLOW.md](AGENT_WORKFLOW.md) §3.3); the human does not.
2. **Update local `main` from `origin/main`** — a fast-forward only (§1.2), after the pre-flight (§1.1).
3. **Create the feature branch from the updated `main`** — `feature/<issue-number>-<slug>`.
4. **Work only inside the feature branch.**
5. **Inspect before modifying.**
6. Implement the task.
7. Run formatting / `flutter analyze` / tests / any relevant validation.
8. Review the diff.
9. Commit.
10. Push.
11. Open the PR — after the pre-PR check (§1.3).
12. **A human developer reviews and merges.** The agent then syncs `main` (§1.4) before any next task.

How the modes use it ([AGENTS.md](../../AGENTS.md) §2):

- **Agentic mode** (the default for a change request): the agent performs steps 1–11 itself — including creating the Issue and the branch — then stops. Step 12 stays human. The stage-by-stage lifecycle is in [AGENT_WORKFLOW.md](AGENT_WORKFLOW.md).
- **Manual mode** (only when the user explicitly asks for a manual or isolated operation): the agent performs only the steps the user asks for. Never commit or push unless explicitly asked; otherwise leave the work uncommitted and report the changed files.

Hard prohibitions, in every mode (canonical list: [AGENTS.md](../../AGENTS.md) §4):

- **NEVER create a branch before its Issue exists.**
- **NEVER work directly on `main`, push to `main`, or delete `main`.**
- **NEVER merge, approve or auto-merge a PR.** Merging is the human developer's decision.
- **NEVER force push** or rewrite pushed history.
- **NEVER `git add -A`, `git add .` or `git commit -a`** — stage edited files by explicit path.
- **NEVER `git pull origin main` while on a feature branch** as a substitute for updating local `main`. `main` is updated on `main`, or by fast-forwarding its ref (§1.2); a feature branch takes `main` in only by an explicit `git merge origin/main` (§1.5).

### 1.1 Pre-flight — before every branch change or integration

Before `git switch`, `git checkout <branch>`, `git pull`, `git merge`, `git rebase` or `git fetch <src>:<dst>`, inspect and state:

```bash
git status --short --branch     # current branch, ahead/behind, every change
git branch --show-current
git diff --cached --name-only   # staged
git diff --name-only            # unstaged
git ls-files --others --exclude-standard   # untracked
git fetch origin && git rev-parse --short HEAD origin/main   # the target and the remote commit
```

Then **classify every local change** as exactly one of:

| Class | What it is | What happens to it |
|---|---|---|
| **Protected** | the five paths in §3 | Rides along untouched. Never staged, stashed, restored or overwritten |
| **This task's** | files the current task changed | Committed on its own feature branch (explicit paths) **before** any switch or integration that touches the same files — or backed up outside the repository first (§1.5) |
| **Pre-existing, not this task's** | anything else | Not touched. Stop and report it |

**Proceed only when every change is classified and the command cannot overwrite any of them.** A refused switch, pull or merge is a stop condition — never a reason to stash, reset or check files out.

### 1.2 Updating local `main` safely

- On `main` with only protected changes: `git pull --ff-only origin main`.
- Not on `main` (or own work in the tree): fast-forward the ref without switching — `git fetch origin main:main` (it refuses anything but a fast-forward).
- Either way, then confirm `git rev-parse main` equals `git rev-parse origin/main`. If it cannot fast-forward — local `main` has commits of its own — stop and report; never reset it.

### 1.3 Before opening a PR

- The staged and committed diff contains **exactly** the intended file list — no protected path, no `swiftpm/` content, no golden unless its update was approved, no scratch file.
- `dart format` (edited files), `flutter analyze`, the relevant tests and the full suite when broad, and `git diff --check` have all run, with results reported.
- The PR is never merged by the agent. Merging needs the user's explicit approval.

### 1.4 After a PR is merged — sync before the next task

1. Verify the merge: `gh pr view <n> --json state,mergeCommit` shows `MERGED`.
2. Run the pre-flight (§1.1). The tree should hold only protected changes.
3. Fast-forward local `main` (§1.2) and confirm `HEAD` and `origin/main` are the same commit.
4. Only then start the next task — with its own Issue, and a branch from this `main`.

**Never leave a task's work uncommitted while another PR merges.** That is what makes `git pull` on `main` refuse ("local changes would be overwritten"): commit it on its feature branch first, even as a work-in-progress commit, which is squashed away at merge.

### 1.5 Bringing a newer `main` into an in-progress branch

When `main` moved (another PR merged) and the feature branch still has uncommitted work:

1. Pre-flight (§1.1). **Back up** this task's changes outside the repository — `git diff -- . ':!ios' > <scratch>/task.patch` plus copies of its changed and untracked files — and verify the backup.
2. If the tree is on the wrong branch, switch back only when `git rev-parse` shows both branches on the same commit (the switch then changes no file).
3. Commit the task's files on the feature branch by explicit path.
4. Fast-forward local `main` (§1.2).
5. `git merge origin/main` on the feature branch. Resolve any conflict by reading both sides — keep the merged PR's fix **and** this task's work; never take one side wholesale.
6. Confirm the merged PR's change is still present (diff the shared files against `origin/main`), then re-run validation.

A parallel task's fix that must merge first goes in **its own worktree** from `origin/main` (`git worktree add --no-track -b feature/<n>-<slug> ../<repo>-<n> origin/main`), so the in-progress branch's working tree is never switched at all.

Branch naming: `feature/<issue-number>-<slug>` for all new work (older history also has `feat/…`, `fix/…`, `chore/…`, `docs/…`). Commit subjects are lowercase, type-prefixed, imperative and end with the Issue number — e.g. `feat: recover expired sessions with token refresh and retry (#176)`. The PR title matches the commit subject.

## 2. Destructive-command policy

Before anything that can discard work (`git checkout --`, `restore`, `reset`, `clean`, `stash`, `rm -rf` inside the repo), run `git status` and understand every modified file first.

**`git stash` is not used in this repository.** The one existing entry, `stash@{0}` (`e0b746b`, "wip: course detail changes"), is the user's: never drop, pop, apply, clear or overwrite it. `git checkout --` is acceptable only on a file proven disposable. Prefer a reversible step (move aside, rename) over deletion.

**Worktrees are the user's too.** Never `git worktree remove` or `prune` one — merged or not — unless the user explicitly asks; list them in reports instead.

## 3. Protected files — persistent local Xcode changes

These three files carry **intentional, persistent local modifications** and appear as modified in `git status` more or less permanently:

```
ios/Runner.xcodeproj/project.pbxproj
ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
ios/Runner/AppDelegate.swift
```

and these two folders are **untracked local Swift Package Manager state**, also permanently in `git status`:

```
ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/
ios/Runner.xcworkspace/xcshareddata/swiftpm/
```

**NEVER edit, restore, reset, stash, stage, overwrite, check out or clean any of the five as part of an unrelated task. Never recommend a command that would** — `git clean` and `git add -A` / `.` are both forbidden partly because of the two folders.

What they actually contain (inspected, for context on why reverting them breaks local builds): a local Apple `DEVELOPMENT_TEAM` signing identifier, Xcode project-format upgrades (`objectVersion` 54 → 60, `LastUpgradeCheck`/`LastUpgradeVersion` bumps) and newer build-setting defaults. They are the local toolchain's and the local signing setup's, not a feature's.

**Always distinguish them from task-specific changes.** In every report, list them separately as *pre-existing, protected, untouched*. A clean run of any task should show the three files still modified, the two folders still untracked, and nothing about any of them changed.

## 4. Scope discipline

From [AGENTS.md](../../AGENTS.md) §5, restated because it is violated easily:

- **Inspect only files relevant to the current task.**
- **Reuse** existing components, theme tokens and utilities before creating new ones.
- **Keep changes scoped.** No unrelated refactors. No new dependencies without a task that asks for one.
- **Do not invent API contracts** (see [DATA_AND_API.md](DATA_AND_API.md) §8).
- Do not fix pre-existing unrelated issues inside a feature task — report them instead.

## 5. Validation

Run before reporting, in this order:

```bash
flutter analyze
flutter test <the directory your work touched>
flutter test                     # full suite, when the change is broad
```

**Known pre-existing results — report these as pre-existing, do not fix them in an unrelated task:** none. The full suite passes on `main` and `flutter analyze` reports no issues, so any failure is new. Decide whose it is ([AGENT_WORKFLOW.md](AGENT_WORKFLOW.md) §3.10), and add it here only once it is confirmed pre-existing and left for a task of its own.

A documentation-only task still runs `flutter analyze` to prove nothing in `lib/` moved.

### Formatting

**Format only the files you edited** — `dart format <file> …`. Do **not** run `dart format lib/`: this repository is written to roughly 90 columns while the formatter defaults to 80, so a blanket run reflows ~30 untouched files and buries the real diff.

### UI work

Widget tests are the primary evidence. When a change is visual, verify it rather than asserting it: a golden/screenshot capture or a run on the simulator. If the UI could not be verified, **say so explicitly** instead of claiming success.

## 6. Code conventions

- **Follow the existing architecture** (see [ARCHITECTURE.md](ARCHITECTURE.md)): `data`/`domain`/`presentation`, `ChangeNotifier` controllers, injected repositories.
- **Doc comments carry the reasoning.** This codebase explains *why* — why a widget is not reused, why a field is nullable, why a value was chosen — in doc comments rather than inline noise. Match that. A non-obvious decision should be explained where it lives.
- **No `TODO`/`FIXME` markers exist anywhere in `lib/` or `test/`.** Do not introduce them; either do the work or document the gap in the right doc.
- User-facing copy goes in that feature's `*_strings.dart`, verbatim from the design (mixed Mongolian/English is intentional). A class migrated to ARB (Issue #503) takes its copy from `lib/l10n/app_mn.arb` / `app_en.arb` instead: edit the ARB files, run `flutter gen-l10n`, commit the regenerated `lib/l10n/` files — never edit the generated Dart. Do not write English copy that has not been approved: leave it out of `app_en.arb`, where it falls back to Mongolian. See [ARCHITECTURE.md](ARCHITECTURE.md) §6.
- Icon codepoints must be **confirmed against the bundled font**, never guessed; fall back to a Material icon with a comment when no confirmed glyph exists.
- Dart 3 features are available and used: records, patterns, `switch` expressions, `if (x case final y?)`.
- Prefer `const` constructors; use private widget classes (`_Foo`) for screen-internal pieces.
- Use `withValues(alpha: …)`, not the deprecated `withOpacity`.
- `avoid_print` is active via `flutter_lints` — no debug prints.

## 7. Reporting

Keep final reports concise ([AGENTS.md](../../AGENTS.md) §5): **changed files, validation results, remaining issues.** Also:

- List the protected paths (three iOS files, two `swiftpm/` folders) separately as untouched, and confirm `stash@{0}` and the worktrees are unchanged.
- Separate *pre-existing* failures/warnings from ones the task caused.
- State unknowns as `UNKNOWN` / `BACKEND GAP` / `PRODUCT DECISION` rather than guessing.
- In agentic mode, add the Issue number, branch, commit hash and PR number ([AGENT_WORKFLOW.md](AGENT_WORKFLOW.md) §8).
