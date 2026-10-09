# MEMORY_SCHEME.md — Workspace + Memory System Reference

> Reference document สำหรับ scheme ของ agent memory + workspace (ใช้ได้ทั้ง Claude Code และ Codex).
> Auto-load rules + audit + templates + examples
>
> Top-level rules อยู่ที่ `{{AGENT_HOME}}/AGENTS.md`
> Workspace context อยู่ที่ `{{AGENT_HOME}}/workspaces/<name>/AGENTS.md`
> Project memory อยู่ที่ `{{MEMORY_DIR}}/`
>
> ไฟล์นี้ load on-demand (ไม่ auto-load ทุก session)
>
> ℹ️ workspace/project ทั้งหมดในเอกสารนี้เป็น **ตัวอย่างสมมติ (AcmeCorp)** — แทนด้วยของจริงของคุณ

---

## 📐 Architecture overview

**Claude Code** (`setup.ps1`):

```
~/.claude/
├── CLAUDE.md                          ← `@AGENTS.md` + Claude-only specifics
├── AGENTS.md                          ← thin router: rules + workspace registry + cwd mapping
├── MEMORY_SCHEME.md                   ← ไฟล์นี้ (reference / audit / templates)
├── settings.json                      ← hooks (SessionStart / PreCompact / SessionEnd / PostToolUse)
├── docs/ · templates/                 ← คู่มือ + template (path ถูกแทนแล้ว)
├── backups/                           ← backup ก่อน refactor + memory-shadow/ (จาก memory-guard)
├── workspaces/                        ← business workspace context (ตัวอย่างสมมติด้านล่าง)
│   ├── acme-corp/AGENTS.md            ← Corporate HQ / ERP / Operations / B2B
│   └── acme-snacks/AGENTS.md          ← Brand: consumer snack, retail D2C
├── projects/C--Users-you/memory/      ← memory dir (FLAT — don't move into workspaces)
│   ├── MEMORY.md                      ← index (grouped by workspace) + Feedback section
│   ├── SESSION-BOARD.md               ← on-demand inter-session board — NOT auto-loaded
│   ├── project-*.md                   ← per-project memory files (frontmatter has `workspace:`)
│   ├── feedback-*.md                  ← global lessons
│   └── user-system-info.md
├── skills/                            ← memory-save, memory-recall, memory-consolidate, orchestrated-loop, ship
└── hooks/
    ├── memory-checkpoint.js           ← audit log + SessionStart memory header (`--agent claude`)
    ├── memory-extract.js              ← daily log จาก transcript (Claude เท่านั้น)
    └── memory-guard.js                ← restore memory file ที่โดน truncate เหลือ 0 byte
```

**Codex** (`setup-codex.ps1`):

```
~/.codex/                              ← $CODEX_HOME
├── AGENTS.md                          ← global instructions (ไฟล์เดียวกับข้างบน, path เป็นของ Codex)
├── MEMORY_SCHEME.md · docs/ · templates/
├── hooks.json                         ← SessionStart (checkpoint + guard) + PostToolUse (guard) — ต้อง trust ใน /hooks
├── hooks/{memory-checkpoint.js, memory-guard.js}   ← `--agent codex`
├── agents/{planner, reviewer, worker-heavy, worker-light}.toml
├── workspaces/<name>/AGENTS.md
├── backups/memory-shadow/
└── conductor-memory/                  ← memory dir (โครงเดียวกับข้างบน) — ต้องอยู่ใน writable_roots
~/.agents/skills/                      ← skills ชุดเดียวกัน (home จริง ไม่ใช่ CODEX_HOME)
```

---

## 🗂️ Workspace = business unit

ตัวอย่าง (AcmeCorp group — corporate HQ + brand):

| Workspace | Scope | Inherits from |
|---|---|---|
| `acme-corp` | Corporate / HQ — factory, group strategy, B2B export/OEM, ERP, automation | — (top of hierarchy) |
| `acme-snacks` | Brand under acme-corp — consumer retail snack, D2C voice | acme-corp (production/certs) — explicit Read |

**Inheritance rule:** workspaces ไม่ auto-inherit context กัน — ต้อง **explicit Read** ตาม link
ที่ระบุใน workspace `AGENTS.md` (lower friction, less context tax, intentional reference)

---

## 📋 Project audit table (ตัวอย่าง — ใช้เป็น checklist ตอน onboard)

Legend: ✅ done / ⚠️ partial / ❌ missing / 🔵 N/A

### acme-corp workspace

| Project | Memory file | `workspace:` tag | cwd map | Project AGENTS.md | Verify recipe |
|---|---|---|---|---|---|
| Acme ERP | ✅ project-acme-erp.md | ✅ acme-corp | ✅ `acme-erp` | ✅ | ✅ |
| Acme Automation | ✅ project-acme-automation.md | ✅ acme-corp | ✅ `acme-automation` | ✅ | ✅ |

### acme-snacks workspace

| Project | Memory file | `workspace:` tag | cwd map | Project AGENTS.md | Verify recipe |
|---|---|---|---|---|---|
| Acme Snacks Website | ✅ project-acme-web.md | ✅ acme-snacks | ✅ `acme-web` | ✅ | ✅ |

> ใช้ตารางแบบนี้ track ว่าแต่ละ project มีครบทุกชิ้นไหม (memory file / workspace tag /
> cwd mapping row / project AGENTS.md / verify recipe) — ช่องที่ ❌ คือ gap ที่ต้องปิด

---

## 🚀 Onboarding new project (4 steps)

```
1. CREATE memory file:
   {{MEMORY_DIR}}/project-<name>.md
   ↳ frontmatter (see template below)
   ↳ + Last verified: <date> @ <commit> + Verify rule pointer
   ↳ + sections: Current Status / Tech Stack / Key Decisions / Done / Pending

2. ADD to MEMORY.md (under correct workspace group)

3. ADD cwd mapping row in {{AGENT_HOME}}/AGENTS.md §Project mapping (if project has cwd)
   + PROJECT_MEMORY_MAP in {{AGENT_HOME}}/hooks/memory-checkpoint.js

4. CREATE <project-root>/AGENTS.md (+ one-line CLAUDE.md `@AGENTS.md` for Claude Code)
   ↳ Stack section
   ↳ Output/Code/Review rules
   ↳ Stack-specific rules
   ↳ Memory Persistence section (path + triggers + verify recipe)
   ↳ Cross-ref to workspace AGENTS.md
```

## 🚀 Onboarding new workspace

```
1. mkdir {{AGENT_HOME}}/workspaces/<name>/
2. CREATE {{AGENT_HOME}}/workspaces/<name>/AGENTS.md
   ↳ Identity / scope
   ↳ Project list (link to memory files)
   ↳ Cross-ref rules (if inherits from another workspace)
3. ADD row (รวม trigger keywords) in {{AGENT_HOME}}/AGENTS.md §Workspace registry
4. ADD section in {{MEMORY_DIR}}/MEMORY.md
5. CREATE first project (follow Onboarding new project steps)
```

---

## 📑 Templates

### Memory file frontmatter

```yaml
---
workspace: <acme-corp|acme-snacks|shared>
name: <Project Display Name>
description: <one-line summary>
type: project
originSessionId: <uuid — first session that created this memory>
---
**Last verified:** YYYY-MM-DD @ <commit>
**Verify rule:** Re-verify if older than 5 days or the commit != HEAD. Recipe in the project AGENTS.md.

## Project: <Project Name>

**Started:** YYYY-MM-DD
**Local repo:** <path> — <state>
**Goal:** <one paragraph>

### Current Status (as of YYYY-MM-DD)
...

### Tech Stack
...

### Key Architectural Decisions
...

### Done
- ✅ <milestone> (date)

### Pending Work
1. ...
```

### Project AGENTS.md skeleton

```markdown
# AGENTS.md — <Project Name>

> One-line summary of what this project is

---

## Project Overview
- **Workspace:** <name>
- **Repo:** <url>
- **Local path:** <path>

## Tech Stack
| Layer | Tech |
|---|---|
...

## Quality / Code rules
- (project-specific style + conventions)

## Memory Persistence
**Memory file:** `{{MEMORY_DIR}}/project-<name>.md`
**Workspace context:** `{{AGENT_HOME}}/workspaces/<workspace>/AGENTS.md`

**Save memory IMMEDIATELY on:**
- (milestone 1)
- (milestone 2)
...

**Verify recipe** (run if `Last verified` > 5 days):
```bash
# (3-7 read-only commands specific to this project)
```

Skills: `memory-save` / `memory-recall`.
```

(ไฟล์เต็มอยู่ที่ `templates/project-AGENTS.md.template`; Claude Code เพิ่ม `CLAUDE.md` 1 บรรทัด `@AGENTS.md`)

---

## 🔧 Verify recipe examples per stack

### Next.js + Supabase
```bash
git status --short
git log --oneline -10
ls supabase/migrations/ | tail -5
node -e "const m=require('./src/lib/modules.ts').modules; console.log(m.length, 'modules')"  # or read file
find src/app -name "page.tsx" | wc -l
npx tsc --noEmit 2>&1 | tail -3
```

### Vite + React + Supabase
```bash
git status --short
git log --oneline -10
ls src/pages/
cat src/App.tsx | grep -i "<Route" | head -10
ls supabase/migrations/ 2>/dev/null | tail -5
```

### Workflow-automation project (e.g. n8n / Make)
```bash
API_KEY=$(cat ~/.automation-api-key)
curl -sS -H "X-API-KEY: $API_KEY" "<AUTOMATION_BASE_URL>/api/v1/workflows/<ID>" \
  | node -e "const w=JSON.parse(require('fs').readFileSync(0)); console.log('v'+w.versionCounter, w.active, w.nodes.length+'nodes')"
curl -sS -H "X-API-KEY: $API_KEY" "<AUTOMATION_BASE_URL>/api/v1/executions?workflowId=<ID>&limit=5"
```

### WordPress / hosted site
```bash
curl -sI https://<domain> | head -5  # status + headers
# check cert expiry
echo | openssl s_client -servername <domain> -connect <domain>:443 2>/dev/null | openssl x509 -noout -enddate
# (if WP) check version
curl -s https://<domain>/wp-json | jq -r '.namespaces[]' 2>/dev/null | head -3
```

### Static / IIS site
```bash
curl -sI https://<domain> | head -5
# robots / sitemap presence
curl -sI https://<domain>/robots.txt | head -3
curl -sI https://<domain>/sitemap.xml | head -3
```

---

## 🧹 Memory hygiene cadence

| Frequency | Action |
|---|---|
| Every session start | Read project memory + `MEMORY.md` Feedback + workspace `AGENTS.md` (per cwd / topic mention) — the SessionStart hook only injects the header |
| Every milestone | Update project memory + MEMORY.md one-liner (skill `memory-save`) |
| Every 5-7 days | If `Last verified` stale (date > 5 days, or its commit ≠ HEAD) → run project's verify recipe before trusting |
| Every quarter | Run skill `memory-consolidate` — merge duplicates, fix stale facts, prune index |
| Multi-session work | Update `SESSION-BOARD.md` on claim/finish; prune stale IN-FLIGHT rows (>3 วัน; §HANDOFF QUEUE exempt — fold on `memory-save`) — see AGENTS.md §Inter-session coordination |
| Before major refactor | Backup `{{AGENT_HOME}}/AGENTS.md` to `{{AGENT_HOME}}/backups/AGENTS-pre-<change>-YYYY-MM-DD.md` |

---

## 🚧 Gap closure priorities (how to use the audit table)

หลัง onboard project ใหม่ ๆ ให้ไล่ปิด gap จากตาราง audit (ช่องที่ ❌) เรียงตาม impact:

1. **Add cwd map + project AGENTS.md + verify recipe** ให้ project ที่ active แต่ยังขาด
2. **Populate workspace** ที่ยังว่างเมื่อมีข้อมูลจริง
3. **Audit project เก่า** — ยืนยันว่ายัง active หรือควร archive

---

*Template for the public claude-conductor. Replace the AcmeCorp examples with your own. · Last updated: 2026-10-09*
