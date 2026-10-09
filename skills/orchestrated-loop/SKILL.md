---
name: orchestrated-loop
description: Role-routed brainstorm-to-build loop for any non-trivial code task. Planner = the brain (analyze, architect, plan, go/no-go; thinks only), heavy worker = complex code reading and tier-2 coding, light worker = gathering, mechanical ops, communication and tier-1 coding, reviewer = independent final review. The standard orchestrator loop from AGENTS.md with a fixed role (and model) per phase.
---

# orchestrated-loop - the planner thinks, the workers do, the reviewer judges

The standard brainstorm -> build loop, but **every phase runs in a fixed role**: the strongest model is the **planner, an advisor that only thinks** (analysis, architecture, plan, go/no-go); a **heavy worker** does hands-on work that needs deep code understanding (complex code reading, tier-2 coding); a **light worker** does light hands-on work (gathering, mechanical ops, communication, tier-1 coding); an independent **reviewer** judges the result. The global AGENTS.md (Orchestrator workflow) and the project AGENTS.md stay the base - this file only binds roles to that loop.

## Roles -> agents

| Role | Does | Claude Code (Agent tool) | Codex (custom agents) |
|---|---|---|---|
| **planner** | analyze, architect, plan, decide go/no-go | main thread running Fable 5, else Agent `model: fable` | `planner` (gpt-6-astra, high, read-only) |
| **heavy worker** | complex code reading, tier-2 coding | Agent `model: opus` (Opus 5.5) | `worker-heavy` (gpt-6.1-sol, high) |
| **light worker** | gathering, mechanical ops, comms, tier-1 coding | Agent `model: sonnet` | `worker-light` (gpt-6-luna, medium) |
| **reviewer** | final review; a different agent from the author | Agent `model: opus` (fresh agent) | `reviewer` (gpt-6-astra, high, read-only); built-in `/review` as fallback |

Model names are the maintainer's set - swap in what your account has. The principle does not change: **four roles - an expensive brain that only thinks, a heavy hand, a light hand, and a judge at least as strong as the author.**

## Routing (never swap duties)

| Work | Role |
|---|---|
| Complex code reading (trace call graphs / RLS / triggers) | heavy worker |
| **General fact-finding** · extracting data from PDFs/images/sheets · read-only DB probes by recipe · assembling reports | light worker |
| Analysis · architecture · planning · decisions (incl. go/no-go from review results) | planner |
| **Coding tier 1 (simple / gate-covered):** FE-only · UI copy · plain CRUD · tests · formula migrations (add column/index, comment, enum value) · work a deterministic gate covers end to end (type-check / test suite / SQL gates / rolled-back test battery) | light worker |
| **Coding tier 2 (hard):** DB functions · RLS · triggers · money/payroll logic · migrations touching cross-branch contracts · multi-file refactors · **anything not clearly tier 1 -> always tier 2** | heavy worker |
| Final review - **same full scope for both tiers** (correctness · security · RLS · types · plan match · conventions), not just "matches the plan"; the reviewer must be at least as strong as the author (judge >= answerer) | reviewer - **a different agent** from the one that wrote the code |
| **Light work / communication:** summarizing results for the user · drafting reports/status · asking the user back (clarify) · turning findings into tables/text | light worker |
| **Mechanical work by recipe:** running decided scripts/commands · git ops · updating board/memory/plan files from a delta the planner defined · opening PRs · deploying per runbook · post-deploy verification | light worker |

- **The planner = the main session if it runs the planner model** (recommended - the orchestrator should be the decider). Otherwise spawn the planner role for Phase 2 and pass the findings in its brief.
- **Heavy work always goes to a spawned heavy worker**, whatever the session runs.
- **Pin the role on every spawn** - Claude: set `model:` on every Agent call; Codex: spawn the named custom agent (per-spawn model overrides are unreliable). Never spawn unpinned: you get the session's model, usually the most expensive. Bulk reading of memory/docs is light-worker work too.
- **Classification: domain beats layer** - logic touching money / identity / authorization / attribution is tier 2 whether it lives in the FE, a script, a seed or a formula migration. A gate "covers" work only if it **already exists** and **exercises the risky path** (citable as file:test) - a selftest that skips the risky path is not a gate.
- *(recommended)* Cost follows tool calls x context, not tier - give briefs clear bounds (split big work into units with checkpoints), put "on mismatch: stop and report, do not investigate on your own" in the brief, and list the full blast radius (every writer / every default that must change together).
- **The planner is an advisor only - it never executes:** it does not read code, write code, or **do any execution** (edit files / run commands / git / board or memory bookkeeping / PRs / deploys) - every action is delegated per the routing table. The planner itself produces only: decisions · architecture · plan/PRD/brief · go/no-go from review results · the conversation with the user. (Reading reports and review results to decide is analysis and allowed; detailed code review is reviewer work; fixing review findings goes back to the workers.) Stay at altitude - it keeps context clean and the strongest model focused on decisions.
- **Narrow exceptions to "never executes" (read strictly):** (1) a command the permission system blocks for subagents (e.g. a COMMIT to the prod DB) - the planner may run it, but only a script the workers prepared and the reviewer passed (execute, never compose). (2) a 1-2 line edit where spawning costs more than the work - allowed as the exception, not the default; several such spots -> batch them into one light-worker task.
- **Light work never burns the planner/heavy roles:** communication-only work - summarizing for the user, drafting status/reports, asking the user back, formatting tables - **goes to the light worker**, or the main session answers **briefly and directly** without raising the full loop. Reserve the planner for Phase 2 and the heavy worker for real code reading, writing and review.

## Phase 1 - GATHER (light worker; heavy worker only for complex code tracing)

- The planner writes a clear brief -> spawn **light worker(s)** to gather facts / extract data / probe the DB by recipe; use the heavy worker only when gathering needs code tracing (call graph / RLS / trigger semantics).
- Workers return **structured findings** (files + line numbers, current behaviour, data shapes, real table/column names) - raw data, not opinions.
- Broad or multi-spot work -> fan out several workers in parallel.
- The planner **does not open code itself** - it thinks from the findings.

## Phase 2 - ANALYZE + ARCHITECT + PLAN (planner)

- **Read the design-lessons registry before designing** - `{{MEMORY_DIR}}/feedback-design-lessons.md` (shape: `examples/memory/feedback-design-lessons.md` in the framework repo; principle: `{{AGENT_HOME}}/docs/06-lessons-learned.md` §E2). Every plan that touches UI / document lifecycle / notifications / client writes / schema / money / auth is checked against it, and the file goes into the brief of a spawned planner too. No file yet -> start from the example and add entries after real incidents.
- Output humans read (bot messages / documents / UI copy / report layouts) -> show a fully rendered sample with realistic data and get the user's OK before delegating the build (`{{AGENT_HOME}}/docs/06-lessons-learned.md` A4).
- Digest findings -> find tensions/risks/edge cases -> design the architecture -> write the plan as clearly scoped phases.
- **Confirm the plan with the user before building** (orchestrator step 3 - wait for the go word, e.g. "go" / "ไปเลย").
- Touching a shared resource -> READ `SESSION-BOARD.md` and lock first (migration timestamp / branch / shared table or RLS / DB function).

## Phase 3 - CODE (tier 1 = light worker · tier 2 = heavy worker)

- The planner splits the plan -> **assigns a tier to every unit in the brief** (tier 1 -> light worker, tier 2 -> heavy worker; unsure -> tier 2) -> spawns workers on the locked plan.
- **A tier-1 brief must include:** (a) the gates the worker runs itself before handing back (type-check · test suite · relevant SQL gates), (b) the relevant design lessons, attached, (c) the files it must not touch. The planner does **not** plan in finer detail to compensate (a line-level plan moves the thinking to the more expensive model).
- Multi-agent work -> waves of <= 3 with a checkpoint after each wave; another session live on the same repo -> create your worktree (`git worktree add` / Claude: `EnterWorktree`) **before** spawning agents or starting a build.
- The planner **never codes** - it holds scope, answers worker questions, reconciles results.
- Surrounding work (push · open PR · board/memory updates · deploy per runbook · post-deploy verify) -> a **light worker** with step-by-step instructions the planner wrote.

## Phase 4 - FINAL REVIEW (reviewer · the planner decides from the findings)

- Spawn the **reviewer - a different agent from the one that wrote the code** (fresh context; never self-review) - **before reporting to the user**: correctness · security · RLS scope · types · plan match · project conventions. Codex: the built-in `/review` is an acceptable fallback or second pass.
- The planner judges the findings as advisor: bug / out of scope -> back to Phase 3 (the same tier fixes it; if a finding shows the work was really tier 2 -> move it to the heavy worker and note "misclassified"), then review again; pass -> report to the user.
- *(recommended when starting tier 1)* keep a trial log of the first N tier-1 tasks (finding count · fix rounds · misclassified?) - an average of >= 1 extra fix round, or a defect reaching live -> move tier 1 back to the heavy worker.
- Verify the real thing (browser / preview / live) as the work requires - **never say "done" without looking at the real result.**

## Inherited guardrails (still fully binding)

- Confirm the plan before coding · review before reporting · open a PR before merging (never push to the default branch) · verify live before saying done · save memory at milestones · respect `SESSION-BOARD.md` and the size budgets.
- "Do less" shrinks the solution, never the rigor - every quality gate stays as strict as before.
