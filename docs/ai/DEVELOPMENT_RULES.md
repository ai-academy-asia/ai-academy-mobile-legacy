# Development Rules

> Non-negotiable process rules. These extend — and never contradict — the short rule list in the repository root `CLAUDE.md`, which remains authoritative for its own items.

## 1. Git workflow (non-negotiable)

Exactly this order, every time:

1. **Create the GitHub Issue first.**
2. **Update local `main` from `origin/main`.**
3. **Create the feature branch from the updated `main`.**
4. **Work only inside the feature branch.**
5. **Inspect before modifying.**
6. Implement the task.
7. Run formatting / `flutter analyze` / tests / any relevant validation.
8. Review the diff.
9. Commit.
10. Push.
11. Open the PR.
12. **A human developer reviews and merges.**

Hard prohibitions:

- **NEVER create a branch before the Issue exists.**
- **NEVER work directly on `main`.**
- **NEVER auto-merge a PR.** Merging is the human developer's decision.
- **NEVER force push, and never push to `main`.**
- **Manual task:** never commit or push unless the task explicitly asks for it (`CLAUDE.md`). When a task ends without that instruction, leave the work uncommitted and report the changed files.
- **Agentic Issue task** (the request names a GitHub Issue as the task, e.g. "Implement Issue #129"): steps 9–11 are part of the task — the agent commits, pushes the feature branch and opens the PR, then stops. Step 12 stays human. The stage-by-stage lifecycle is in [AGENT_WORKFLOW.md](AGENT_WORKFLOW.md).

Branch naming follows the existing history: `feat/…`, `fix/…`, `chore/…`, `docs/…`, or `feature/<issue-number>-<slug>`. Commit subjects are lowercase, type-prefixed and imperative — e.g. `feat: implement exercise detail quiz flow`, `docs: re-audit course learning backend APIs`.

## 2. Destructive-command policy

Before anything that can discard work (`git checkout --`, `restore`, `reset`, `clean`, `stash`, `rm -rf` inside the repo), run `git status` and understand every modified file first.

**`git stash` is not used in this repository.** `git checkout --` is acceptable only on a file proven disposable. Prefer a reversible step (move aside, rename) over deletion.

## 3. Protected files — persistent local Xcode changes

These three files carry **intentional, persistent local modifications** and appear as modified in `git status` more or less permanently:

```
ios/Runner.xcodeproj/project.pbxproj
ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
ios/Runner/AppDelegate.swift
```

**NEVER restore, reset, stash, overwrite, check out or clean these files as part of an unrelated task. Never recommend a command that would.**

What they actually contain (inspected, for context on why reverting them breaks local builds): a local Apple `DEVELOPMENT_TEAM` signing identifier, an `IPHONEOS_DEPLOYMENT_TARGET` raised from 13.0 to 15.0, Xcode project-format upgrades (`objectVersion` 54 → 60, `LastUpgradeCheck`/`LastUpgradeVersion` bumps) and newer build-setting defaults. They are the local toolchain's and the local signing setup's, not a feature's.

**Always distinguish them from task-specific changes.** In every report, list them separately as *pre-existing, protected, untouched*. A clean run of any task should show these three still modified and nothing about them changed.

## 4. Scope discipline

From `CLAUDE.md`, restated because it is violated easily:

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

**Known pre-existing results — report these as pre-existing, do not fix them in an unrelated task:**

| Kind | Where |
|---|---|
| Analyzer warning | `lib/features/courses/presentation/course_catalog_screen.dart:13` — `unused_import` of `course_detail_screen.dart` |
| Test failure | `test/features/courses/course_catalog_screen_test.dart` — *"loaded falls back to a computed duration when duration_label is null"* |

A documentation-only task still runs `flutter analyze` to prove nothing in `lib/` moved.

### Formatting

**Format only the files you edited** — `dart format <file> …`. Do **not** run `dart format lib/`: this repository is written to roughly 90 columns while the formatter defaults to 80, so a blanket run reflows ~30 untouched files and buries the real diff.

### UI work

Widget tests are the primary evidence. When a change is visual, verify it rather than asserting it: a golden/screenshot capture or a run on the simulator. If the UI could not be verified, **say so explicitly** instead of claiming success.

## 6. Code conventions

- **Follow the existing architecture** (see [ARCHITECTURE.md](ARCHITECTURE.md)): `data`/`domain`/`presentation`, `ChangeNotifier` controllers, injected repositories.
- **Doc comments carry the reasoning.** This codebase explains *why* — why a widget is not reused, why a field is nullable, why a value was chosen — in doc comments rather than inline noise. Match that. A non-obvious decision should be explained where it lives.
- **No `TODO`/`FIXME` markers exist anywhere in `lib/` or `test/`.** Do not introduce them; either do the work or document the gap in the right doc.
- User-facing copy goes in that feature's `*_strings.dart`, verbatim from the design.
- Icon codepoints must be **confirmed against the bundled font**, never guessed; fall back to a Material icon with a comment when no confirmed glyph exists.

## 7. Reporting

Keep final reports concise (`CLAUDE.md`): **changed files, validation results, remaining issues.** Also:

- List the three protected iOS files separately as untouched.
- Separate *pre-existing* failures/warnings from ones the task caused.
- State unknowns as `UNKNOWN` / `BACKEND GAP` rather than guessing.
