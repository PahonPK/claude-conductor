---
name: memory-recall
description: Read the project memory and verify it against the real code state before trusting it - checks Last verified age and commit, runs the project verify recipe when stale, and reports pending HANDOFF deltas without folding them (pure read). Use at session start or when the user asks "where were we".
---

# memory-recall - read project memory, verify before trusting

> **Recall is a pure READ** - never mutate the canonical files and never fold the HANDOFF QUEUE (folding belongs to `memory-save`, a write op). Recall only *reports* pending deltas.

Paths: the memory dir and the project mapping table are defined in the global AGENTS.md (Memory protocol).

1. **Detect the project** - compare the current cwd with the project mapping table in AGENTS.md. No match -> tell the user the cwd is outside the mapped projects.

2. **Read the project memory file** - `{{MEMORY_DIR}}/project-*.md` (per the mapping).

3. **Check the `**Last verified:**` header** at the top of the file:
   - **Commit staleness:** header `**Last verified:** <date> @ <commit>` - if `<commit>` != the real HEAD of the default branch (`git rev-parse HEAD`), or != the commit the body cites -> **flag stale; do not trust the body until verified**.
   - Older than 5 days, or missing -> **run the verify recipe** from the project's own AGENTS.md (section "Memory persistence -> Verify recipe"). Recipes differ per project (e.g. `git log -10`, `git status`, read a key file, list the migrations dir).
   - 5 days or newer and the commit matches -> verification may be skipped (the user can still ask for it).

4. **Check pending HANDOFF lines** (read only) - read the HANDOFF QUEUE section of `{{MEMORY_DIR}}/SESSION-BOARD.md`: any line whose `<target-file>` is this file (shape `-> <target-file> :: <fact>  [from <session> <date>]`) means the canonical file **is still stale** -> report "N deltas pending, not folded yet (they fold on the next save)" and verify as usual. **Never fold here.**

5. **Report a structured recall** to the user (in the user's language):
   - **Project:** name
   - **Last verified:** date + commit + a warning if stale (commit != HEAD/body, or > 5 days)
   - **Memory summary:** curated highlights (current status, key decisions, completed milestones) - not a full dump
   - **Pending work:** open items
   - **Pending HANDOFF deltas:** (if any) - N lines targeting this file, not folded yet
   - **Stale claims found:** (if any) - what the memory says but the verify recipe contradicts

6. **Ask the user:** "Where should we continue from?"

**Quality bar:** never report "memory matches the code" without actually verifying - if you did not verify, say so plainly.
