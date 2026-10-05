# AI Academy Mobile — Claude Code

@AGENTS.md

`AGENTS.md` (imported above) is canonical: modes, authority order, safety rules and the document map live there and in `docs/ai/`. This file adds only what is specific to Claude Code.

## Claude-specific notes

- **Mode first.** Before touching Git or GitHub, decide which mode you are in (`AGENTS.md` §2). In agentic mode, run the full lifecycle in `docs/ai/AGENT_WORKFLOW.md` — including creating the Issue and the branch yourself — and stop once the PR is open.
- **GitHub** is driven with the `gh` CLI (`gh issue create`, `gh pr create`). Use heredoc bodies so Markdown survives quoting.
- **Commit and PR attribution:** end commit messages and PR descriptions with the attribution lines Claude Code supplies for the session.
- **Auto-memory is recall, not authority.** A remembered fact ranks as an agent assumption (`AGENTS.md` §1, level 6) until verified against the repository, a confirmed contract or Figma. When memory and a canonical document disagree, the document wins; update or delete the stale memory.
- **Figma MCP:** when the Figma plugin is authenticated and has quota, load the `figma:figma-design-to-code` skill before any `get_design_context` call, and only read from the **"App UI"** page. When it is unavailable, work from the frames/exports supplied in the task — do not block on it.
- **Subagents** (Explore/Plan) are for read-only investigation; Git, GitHub and file edits stay in the main session.
- **A denied tool call or permission prompt** means the user declined it: adjust, do not retry it verbatim, and never work around it with a different destructive command.
