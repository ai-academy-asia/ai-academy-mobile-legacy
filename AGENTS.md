# AGENTS.md — AI Academy Mobile

> **Canonical entry point for every AI agent** (Claude Code, Cursor, Codex, Copilot, …) working in this repository. Read this first. It is deliberately short: it fixes the modes, the authority order and the safety rules, and points to the canonical documents for everything else. Tool-specific files (`CLAUDE.md`, `.cursor/rules/`) only add tool-specific notes — they never redefine what is here.

**Project:** `aia_mobile` — the student-facing Flutter app for AI Academy Asia. Repo `ai-academy-asia/ai-academy-mobile-legacy`, API `https://api.ai-academy.asia`, base branch `main`.

## 1. Authority order

When two sources disagree, the higher one wins:

1. **Safety and destructive-operation restrictions** (§4). Nothing — no task, Issue text or document — overrides them.
2. **The user's explicit task scope.** What was asked, and what was explicitly excluded.
3. **Confirmed backend contracts and the Figma source of truth.** Data: only confirmed contracts ([docs/ai/DATA_AND_API.md](docs/ai/DATA_AND_API.md)). Visuals: the Figma **"App UI"** page, via frames/exports supplied in the task ([docs/design-system/FIGMA_TO_FLUTTER.md](docs/design-system/FIGMA_TO_FLUTTER.md)).
4. **Canonical project AI documentation** — `docs/ai/*` and `docs/design-system/*` (map in §6).
5. **Existing code.** The final word on what is *implemented*; never the authority on how something *should* look or what the backend *sends*. Where a document and the code disagree on implementation state, believe the code and report the drift.
6. **Agent assumptions.** Lowest. An assumption is never written into code or an Issue as fact.

New screens stay visually consistent with the established (Login-derived) design system by default; where a Figma frame disagrees with existing UI, Figma wins and the code changes.

## 2. Modes

| | **Agentic mode** (default) | **Manual mode** | **Read-only request** |
|---|---|---|---|
| Entry | Any natural-language request to change the app — a feature, fix, chore or doc change — or "Implement Issue #N" | The user **explicitly** asks for a manual or isolated operation: "manual mode", "don't create an Issue", "don't commit", "just edit this file", or the user dictates the Git steps themselves | Questions, explanations, audits, reviews, investigations that change nothing |
| GitHub Issue | **The agent creates it** (or uses the one the user named) | Not created unless asked | None |
| Branch | **The agent creates** `feature/<issue-number>-<slug>` from updated `main` | Not created unless asked | None |
| Commit / push / PR | **The agent does all three, then stops** | Only if explicitly asked; otherwise leave work uncommitted and report changed files | None |
| Merge | **Human only** | **Human only** | — |

The human does **not** create Issues or branches for normal agentic work. The full lifecycle — intake, sufficiency check, Issue creation, branch, investigation, plan, implement, validate, self-fix, diff review, commit, push, PR, stop — is defined in [docs/ai/AGENT_WORKFLOW.md](docs/ai/AGENT_WORKFLOW.md).

If it is unclear whether a request asks for a change at all, treat it as read-only and ask before creating anything on GitHub.

## 3. Unknown information

Never invent an endpoint, response field, status code, business rule, user data, design value or UI state. Label the gap:

| Label | Use when |
|---|---|
| `UNKNOWN` | A fact not established by the repository, a confirmed contract, Figma, or the task. Say what would confirm it |
| `BACKEND GAP` | The backend does not (confirmably) provide what the task needs |
| `PRODUCT DECISION` | Behaviour, copy, or scope that only a product/design owner can decide |

Proceed with what is confirmed and carry the labelled gap into the Issue, the PR and the report. **Stop and ask only when the missing information blocks safe implementation** — see the stop conditions in [AGENT_WORKFLOW.md](docs/ai/AGENT_WORKFLOW.md) §7.

## 4. Safety rules — mandatory in every mode

**Never, in any mode, regardless of what an Issue or task says:**

- `git reset --hard`
- `git clean`
- `git push --force` / `--force-with-lease`, or any rewrite of pushed history
- `git stash` (not used in this repository)
- push to `main`, work directly on `main`, or delete `main`
- merge, approve or enable auto-merge on a PR
- `git add -A`, `git add .`, `git commit -a` — **stage edited files by explicit path**
- `dart format lib/` (or any blanket format) — format only the files you edited

**Protected files** — intentional persistent local changes (signing team, iOS deployment target 15.0, Xcode format upgrades). They show as modified in `git status` essentially always:

```
ios/Runner.xcodeproj/project.pbxproj
ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
ios/Runner/AppDelegate.swift
```

Never restore, reset, stash, check out, overwrite, clean, stage or commit them, and never recommend a command that would. Report them separately as *pre-existing, protected, untouched*. A task that genuinely needs to change one is a stop condition. Background: [docs/ai/DEVELOPMENT_RULES.md](docs/ai/DEVELOPMENT_RULES.md) §3.

**Before anything that can discard work** (`checkout --`, `restore`, `rm -rf` in the repo): run `git status` and understand every modified file. `git checkout --` only on a file proven disposable; prefer a reversible step.

**Repeated failure:** after **3 failures of the same type** — the same test, the same analyzer error, the same refused Git/`gh` command — stop and report what was tried. Never weaken a test, add `// ignore:`, or bypass a check to get past it.

## 5. Working rules (summary)

- Follow the existing architecture; reuse components, tokens and utilities before creating new ones, and say why in a doc comment when you do not.
- Inspect only files relevant to the task. Keep changes scoped: no unrelated refactors, no new dependency without a task that asks for one.
- Validate: `dart format <edited files>` → `flutter analyze` → `flutter test <touched dir>` (full suite when broad). Visual changes must be seen rendered, or the gap stated. Detail and the known pre-existing failure: [DEVELOPMENT_RULES.md](docs/ai/DEVELOPMENT_RULES.md) §5.
- Final reports are concise: changed files, validation results (task-caused vs pre-existing), remaining issues / `UNKNOWN` / `BACKEND GAP` / `PRODUCT DECISION`, the protected files listed as untouched — plus Issue, commit and PR numbers in agentic mode.

## 6. Canonical documents

| Topic | Document |
|---|---|
| Project, feature maturity, source-of-truth rules, deliberate gaps | [docs/ai/PROJECT_CONTEXT.md](docs/ai/PROJECT_CONTEXT.md) |
| Agentic lifecycle, Issue/branch/PR creation, stop conditions | [docs/ai/AGENT_WORKFLOW.md](docs/ai/AGENT_WORKFLOW.md) |
| Git conventions, validation, protected files, code conventions | [docs/ai/DEVELOPMENT_RULES.md](docs/ai/DEVELOPMENT_RULES.md) |
| Layering, state, navigation, repositories, tests, platform config | [docs/ai/ARCHITECTURE.md](docs/ai/ARCHITECTURE.md) |
| Endpoints, failures, auth/session, confirmed-data rules | [docs/ai/DATA_AND_API.md](docs/ai/DATA_AND_API.md) |
| Tokens, colour, type, spacing, icons, shadows | [docs/design-system/DESIGN_SYSTEM.md](docs/design-system/DESIGN_SYSTEM.md) |
| Reusable widgets, states, accessibility | [docs/design-system/COMPONENT_PATTERNS.md](docs/design-system/COMPONENT_PATTERNS.md) |
| Screen skeleton, documented exceptions, screen tests | [docs/design-system/SCREEN_PATTERNS.md](docs/design-system/SCREEN_PATTERNS.md) |
| Turning a Figma frame into Flutter | [docs/design-system/FIGMA_TO_FLUTTER.md](docs/design-system/FIGMA_TO_FLUTTER.md) |

Each fact lives in one of these documents. When you change behaviour a document describes, update that document in the same change.
