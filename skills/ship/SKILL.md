---
name: ship
description: Ship a web feature end-to-end with full verification - reconcile the REAL requirement, verify schema against the live DB, delegate the build, review it, open a PR, deploy, browser-verify on live prod, then clean up the worktree and update memory. Use when a change is ready to go from "coded" to "live and verified". Bakes in the anti-friction guardrails (stale memory, wrong feature, non-existent column, placeholder data, unverified deploy).
---

# ship - reconcile -> build -> review -> deploy -> prove -> housekeep

The standard ship-and-verify loop. Every step is mandatory unless the user says to skip it.
The global AGENTS.md (orchestrator workflow) and the project AGENTS.md (verify recipe + deploy specifics) stay the base - this file makes the loop callable in one step and keeps steps from being dropped when the context is nearly full.

> **Placeholders** - the real values live in the project AGENTS.md, not here:
> `<DOMAIN>` = the prod URL (e.g. `app.example.com`) · `<DEPLOY_CMD>` = the project's deploy recipe/runbook ·
> `<DB_INTROSPECT>` = a read-only way to read the real schema (e.g. a read-only Postgres tool / `psql \d`)

## 0. Reconcile the REAL requirement (do not ship the wrong thing)

- Restate to the user in one sentence what will ship -> **wait for confirmation before touching code**.
- READ the project memory + `git status` / `git log` of the real tree - **do not trust stale memory**; report any discrepancy first.
- Touching a shared resource (migration timestamp / branch / shared table or RLS / DB function) -> READ `SESSION-BOARD.md` and lock first.

## 1. Verify the schema against the LIVE DB before writing migrations/SQL

- Use `<DB_INTROSPECT>` (read-only) to see the real table/column names **before** writing DDL / triggers / RPCs - never guess a field.
- Known failure shapes: a column that does not exist, a near-miss column name, the wrong table name, a trigger that references `OLD` on INSERT.
- `CREATE OR REPLACE` of a shared function/trigger -> read its real definition on live first (so a DB-only guard is not silently lost).

## 2. Build (orchestrator - do not code yourself)

- Write a brief -> delegate to subagents (or run skill `orchestrated-loop` for role routing). The main agent = reviewer / decision maker.
- Multi-agent: waves of <= 3 to stay under rate limits + a checkpoint after each wave.
- Another session live on the same repo -> create your worktree (`git worktree add` / Claude: `EnterWorktree`) **before** spawning agents or starting a build.

## 3. Review before reporting to the user (every code change)

- The reviewer role (Codex: the `reviewer` agent or built-in `/review`) - check bugs + schema + RLS scope + types before calling it passed.

## 4. PR (never push to the default branch)

- Always open a PR, even for a self-merge of reviewed work.
- Merge the base branch into your branch before opening the PR (see the project AGENTS.md §Merge hygiene if present).

## 5. Deploy -> prod

- Run `<DEPLOY_CMD>` per the deploy recipe in the project AGENTS.md.
- A container/host shared by several sessions -> check and acquire `SESSION-BOARD.md` §DEPLOY LOCK first (see `{{AGENT_HOME}}/docs/03-inter-session.md`).

## 6. Browser-verify on LIVE (not verified = not done)

- Open the changed page on `https://<DOMAIN>` with your browser tool and capture proof; UI/hydration bugs -> diagnose in the browser, **do not guess**.
- Check real semantics: labels/columns/data mean the right thing (not just "the page loads"), **with real or seeded data, not placeholders**.

## 7. Housekeep

- Release the worktree/lock, delete your IN-FLIGHT row (+ DEPLOY LOCK if held), fold HANDOFF lines (delete-iff-folded) into the canonical file.
- Update the project memory + the `MEMORY.md` one-liner (only on a meaningful state change; respect the size budgets).

## Report to the user (straight)

What was built · deployed or not · browser proof · what is still pending. **If verification was incomplete or a step was skipped, say so plainly** - never say "done" without looking at the real thing.
