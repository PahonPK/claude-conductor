---
name: memory-consolidate
description: Quarterly reflective pass over the memory dir - merge duplicates, fix stale facts, move history to archives, and prune the MEMORY.md index back under its size budget. Use at the quarterly cadence or when the user asks to consolidate / clean up memory.
---

# memory-consolidate - quarterly memory hygiene

The memory dir, size budgets and memory language are defined in the global AGENTS.md (Memory protocol).

1. List the memory dir with file sizes; note every file over its budget (`MEMORY.md` <= 20 KB and <= 3 lines per entry; project file <= 40 KB, mega-project <= 120 KB).
2. Read `MEMORY.md` and every `project-*.md` / `feedback-*.md` it indexes; note files it does not index and links that point nowhere.
3. Draft a plan: duplicates to merge, stale facts to fix (run the project's verify recipe before changing a fact - never "fix" from memory alone), history to move into `project-<name>-archive.md`, index entries to trim, dead links to repair.
4. Show the plan as one block and wait for the user's yes.
5. Apply it with targeted edits - never a truncating write. Never delete a feedback lesson as YAGNI (each one is evidence of a real incident; retire it only when the mechanism it guards no longer exists). Leave `SESSION-BOARD.md` HANDOFF lines alone - they fold on `memory-save`.
6. Report: files changed, bytes before -> after, anything left for the user to decide.
