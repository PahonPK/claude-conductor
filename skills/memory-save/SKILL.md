---
name: memory-save
description: Save the current project state into its memory file - curate from this conversation (plus the daily log when one exists), show a compact diff for confirmation, drain the HANDOFF lines that target the file, and machine-bump Last verified. Use at milestones, before compaction, or when the user says "remember" / "save memory".
---

# memory-save - write the current state into project memory

Follow these steps in order. Paths: the memory dir and the project mapping table are defined in the global AGENTS.md (Memory protocol).

1. **Detect the project** - compare the current cwd with the project mapping table in AGENTS.md (Memory protocol -> Project mapping). No match -> tell the user the cwd is not a mapped project and ask where to save.

2. **Read three sources:**
   - the current project memory file in the memory dir (e.g. `{{MEMORY_DIR}}/project-acme-erp.md`)
   - if a daily log exists (Claude Code hook only - Codex has none): `{{AGENT_HOME}}/memory-checkpoints/daily/YYYY-MM-DD.md` for today, else yesterday
   - this conversation (what this session did)

3. **Compute a compact diff** against the current memory file, as bullets:
   - `+ added: <what will be added>`
   - `- removed: <what will be removed or replaced>`
   - `~ changed: <old value> -> <new value>`

4. **Show the diff** to the user as one short block and ask `(y/n)`.

5. **Pre-curate: drain HANDOFF + cross-domain canary** (before curating the body)
   - **Fold-on-save (drain HANDOFF):** read the HANDOFF QUEUE section of `SESSION-BOARD.md` (same memory dir) and find the lines whose `<target-file>` is the file being saved (shape `-> <target-file> :: <fact>  [from <session> <date>]`). Fold every match into the body with a **targeted edit** - do not re-curate the whole file.
     - **Delete-iff-folded (idempotent):** delete a HANDOFF line **only in the same edit** that writes its fact into the canonical body - never before the fold (prevents partial folds and double drains). Folding happens only on save; recall never folds.
   - **Cross-domain canary (flag only):** run `git log --name-only <Last-verified-commit>..HEAD`. If files fall in another project's path domain (per the cwd mapping in AGENTS.md) -> ask the user: "this work touched <files> in <project>'s domain - write a HANDOFF?" Flag only: never auto-fold, never block the save.

6. **On y:**
   - Update the memory file with **targeted edits to the changed/stale parts only - not a full rewrite** (a mega-file near its budget especially needs surgical edits). Write the content **in English** (faithful; keep an original-language term only where translation distorts its meaning or intent) per AGENTS.md (Memory protocol).
   - Never write it with a truncating write: use your file-edit tool, or a temp file + atomic rename.
   - **Machine-bump (required):** overwrite `**Last verified:** <date> @ <commit>` at the top with real values - `<commit>` = `git rev-parse HEAD`, `<date>` = today. Never hand-maintain it; every save writes both.
   - If the one-liner changed (frontmatter `name:` / `description:` or the `MEMORY.md` entry) -> update `{{MEMORY_DIR}}/MEMORY.md` too, within its size budget.
   - Confirm with a one-line summary: file path + key changes + number of HANDOFF lines drained.

7. **On n:** ask the user what to keep or drop, then redo.

**Sandbox:** a write to the memory dir is refused -> stop and tell the user (Codex: add the dir to `writable_roots` in `config.toml`, or start `codex --add-dir <memory dir>`). Never save the memory somewhere else.

**Quality bar:** never overwrite with stale state - if you are not sure the new information is right, verify it first (read the code / `git log`), then write.
