# templates/

Reusable templates extracted from `../MEMORY_SCHEME.md`. Use these when onboarding
a new project or workspace (see `../docs/04-onboarding-new-project.md`).

The setup scripts install this folder into the agent home (`~/.claude/templates/` or
`$CODEX_HOME/templates/`) with the path tokens replaced by your real paths - copy from
the installed folder. `<memory dir>` below = the memory dir defined in AGENTS.md
(Claude Code: `~/.claude/projects/<slug>/memory/`; Codex: `$CODEX_HOME/conductor-memory/`).

| File | Use for | Source section in MEMORY_SCHEME.md |
|---|---|---|
| `project-memory.md.template` | New project memory file (`<memory dir>/project-<name>.md`) | §Templates -> Memory file frontmatter |
| `project-AGENTS.md.template` | New `<project-root>/AGENTS.md` (+ a one-line `CLAUDE.md` with `@AGENTS.md` for Claude Code) | §Templates -> Project AGENTS.md skeleton |
| `workspace-AGENTS.md.template` | New `<agent home>/workspaces/<name>/AGENTS.md` | §Onboarding new workspace (required parts) |
| `MEMORY.md.template` | Memory index seed - setup copies it to `<memory dir>/MEMORY.md` only if absent | §Architecture overview |
| `SESSION-BOARD.md.template` | Inter-session board seed - setup copies it to `<memory dir>/SESSION-BOARD.md` only if absent | `../docs/03-inter-session.md` |
| `verify-recipe.snippets.md` | Per-stack verify recipes to paste into a project AGENTS.md | §Verify recipe examples per stack |

For the full reference (audit tables, onboarding steps, hygiene cadence), read
`../MEMORY_SCHEME.md` directly.
