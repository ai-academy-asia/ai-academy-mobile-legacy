# AI Academy Mobile

## Rules
- Flutter app. Follow the existing project architecture and patterns.
- Reuse existing components, theme tokens, and utilities before creating new ones.
- App UI follows the established Login design system; keep new screens visually consistent.
- Inspect only files relevant to the current task.
- Do not invent API contracts.
- Keep changes scoped; avoid unrelated refactors or dependencies.
- Manual tasks: do not commit or push unless explicitly asked.
- Agentic Issue tasks ("Implement Issue #N"): commit, push the feature branch, and open a PR as part of the workflow — then stop.
- Never merge a PR; merging is a human decision in both modes.
- Never run destructive git (`reset --hard`, `clean`, `stash`, force push), and never touch the three protected iOS files (`docs/ai/DEVELOPMENT_RULES.md` §3).

## Workflow
- Implement the requested task, then run relevant tests and `flutter analyze`.
- Keep final reports concise: changed files, validation results, remaining issues.
- When the task is a GitHub Issue, follow the lifecycle in `docs/ai/AGENT_WORKFLOW.md`: discover → context → gap analysis → plan → implement → validate → self-fix → review diff → commit → push → PR → human review.