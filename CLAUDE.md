@AGENTS.md

# Claude Code specifics

Every agent-neutral rule lives in `AGENTS.md` (imported above; `setup.ps1` installs both files into `~/.claude/`). This section covers only what is specific to Claude Code.

- **Memory dir = Claude's auto-memory dir of your home folder:** `~/.claude/projects/<slug>/memory/`, where `<slug>` is your home path with the drive colon and each separator replaced by `-` (`C:\Users\you` -> `C--Users-you`). Claude Code auto-loads `MEMORY.md` from the auto-memory dir of the session's cwd, so this global `MEMORY.md` auto-loads only in sessions started at HOME. Every other session gets its Feedback lines from the SessionStart hook.
- **Hooks** (`settings.json` -> `~/.claude/hooks/`, all run with `--agent claude`):
  - `memory-checkpoint.js` - SessionStart injects the project memory header, the daily-log tail and the Feedback lines (Feedback skipped when cwd == HOME, because `MEMORY.md` already auto-loads there). PreCompact / SessionEnd append `events.jsonl` and spawn `memory-extract.js`.
  - `memory-extract.js` (Claude only) - parses the transcript and appends the last exchanges to the daily log `~/.claude/memory-checkpoints/daily/YYYY-MM-DD.md`, which `memory-save` reads as an extra source.
  - `memory-guard.js` - SessionStart + PostToolUse on `Write|Edit|Bash`. PostToolUse stdout is not reliably shown to the session; check `~/.claude/backups/memory-shadow/_restores.log` when a memory file looks wrong.
- **Worktrees:** `git fetch` first, then `EnterWorktree` - it creates `.claude/worktrees/<name>` on a new branch cut from origin/<default> (`worktree.baseRef` default `fresh`) and moves the session's cwd there. If `.claude/` is tracked in the repo, add `/.claude/worktrees/` to its `.gitignore`. A named-branch sibling worktree (`git worktree add`) is fine too.
- **Subagents:** Agent tool. **Pin `model:` on every spawn** - planner = `fable`, heavy worker and reviewer = `opus`, light worker = `sonnet` (skill `orchestrated-loop`). An unpinned spawn inherits the session model, usually the most expensive one.
- **Skills:** `~/.claude/skills/<name>/SKILL.md`, invoked as `/name`: `/memory-save`, `/memory-recall`, `/memory-consolidate`, `/orchestrated-loop`, `/ship`.
- **Project files:** Claude Code loads `CLAUDE.md` - each project root keeps a one-line `CLAUDE.md` containing `@AGENTS.md` (template: `~/.claude/templates/project-AGENTS.md.template`).
