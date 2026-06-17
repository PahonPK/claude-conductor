# MEMORY_SCHEME.md — Workspace + Memory System Reference

> Reference document สำหรับ scheme ของ Claude memory + workspace.
> Auto-load rules + audit + templates + examples
>
> Top-level rules อยู่ที่ `~/.claude/CLAUDE.md`
> Workspace context อยู่ที่ `~/.claude/workspaces/<name>/CLAUDE.md`
> Project memory อยู่ที่ `~/.claude/projects/C--Users-you/memory/`
>
> ไฟล์นี้ load on-demand (ไม่ auto-load ทุก session)
>
> ℹ️ workspace/project ทั้งหมดในเอกสารนี้เป็น **ตัวอย่างสมมติ (AcmeCorp)** — แทนด้วยของจริงของคุณ

---

## 📐 Architecture overview

```
~/.claude/
├── CLAUDE.md                          ← thin router: rules + workspace registry + cwd mapping
├── MEMORY_SCHEME.md                   ← ไฟล์นี้ (reference / audit / templates)
├── backups/                           ← backup ของ CLAUDE.md ก่อน refactor
├── workspaces/                        ← business workspace context (ตัวอย่างสมมติด้านล่าง)
│   ├── acme-corp/CLAUDE.md            ← Corporate HQ / ERP / Operations / B2B
│   └── acme-snacks/CLAUDE.md          ← Brand: consumer snack, retail D2C
├── projects/C--Users-you/memory/      ← project memory (FLAT — don't move into workspaces)
│   ├── MEMORY.md                      ← index (grouped by workspace)
│   ├── SESSION-BOARD.md               ← on-demand inter-session board — NOT auto-loaded
│   ├── project-*.md                   ← per-project memory files (frontmatter has `workspace:`)
│   ├── feedback-*.md                  ← global lessons
│   └── user-system-info.md
└── hooks/memory-checkpoint.js         ← audit-only hook
```

---

## 🗂️ Workspace = business unit

ตัวอย่าง (AcmeCorp group — corporate HQ + brand):

| Workspace | Scope | Inherits from |
|---|---|---|
| `acme-corp` | Corporate / HQ — factory, group strategy, B2B export/OEM, ERP, automation | — (top of hierarchy) |
| `acme-snacks` | Brand under acme-corp — consumer retail snack, D2C voice | acme-corp (production/certs) — explicit Read |

**Inheritance rule:** workspaces ไม่ auto-inherit context กัน — ต้อง **explicit Read** ตาม link
ที่ระบุใน workspace CLAUDE.md (lower friction, less context tax, intentional reference)

---

## 📋 Project audit table (ตัวอย่าง — ใช้เป็น checklist ตอน onboard)

Legend: ✅ done / ⚠️ partial / ❌ missing / 🔵 N/A

### acme-corp workspace

| Project | Memory file | `workspace:` tag | cwd map | Project CLAUDE.md | Verify recipe |
|---|---|---|---|---|---|
| Acme ERP | ✅ project-acme-erp.md | ✅ acme-corp | ✅ `acme-erp` | ✅ | ✅ |
| Acme Automation | ✅ project-acme-automation.md | ✅ acme-corp | ✅ `acme-automation` | ✅ | ✅ |

### acme-snacks workspace

| Project | Memory file | `workspace:` tag | cwd map | Project CLAUDE.md | Verify recipe |
|---|---|---|---|---|---|
| Acme Snacks Website | ✅ project-acme-web.md | ✅ acme-snacks | ✅ `acme-web` | ✅ | ✅ |

> ใช้ตารางแบบนี้ track ว่าแต่ละ project มีครบทุกชิ้นไหม (memory file / workspace tag /
> cwd mapping row / project CLAUDE.md / verify recipe) — ช่องที่ ❌ คือ gap ที่ต้องปิด

---

## 🚀 Onboarding new project (4 steps)

```
1. CREATE memory file:
   ~/.claude/projects/C--Users-you/memory/project-<name>.md
   ↳ frontmatter (see template below)
   ↳ + Last verified date + Verify rule pointer
   ↳ + sections: Current Status / Tech Stack / Key Decisions / Done / Pending

2. ADD to MEMORY.md (under correct workspace group)

3. ADD cwd mapping row in ~/.claude/CLAUDE.md §Project mapping (if project has cwd)

4. CREATE <project-root>/CLAUDE.md
   ↳ Stack section
   ↳ Output/Code/Review rules
   ↳ Stack-specific rules
   ↳ Memory Persistence section (path + triggers + verify recipe)
   ↳ Cross-ref to workspace CLAUDE.md
```

## 🚀 Onboarding new workspace

```
1. mkdir ~/.claude/workspaces/<name>/
2. CREATE ~/.claude/workspaces/<name>/CLAUDE.md
   ↳ Identity / scope
   ↳ Project list (link to memory files)
   ↳ Cross-ref rules (if inherits from another workspace)
3. ADD row (รวม trigger keywords) in ~/.claude/CLAUDE.md §Workspace Registry + Auto-load
4. ADD section in ~/.claude/projects/C--Users-you/memory/MEMORY.md
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
**Last verified:** YYYY-MM-DD
**Verify rule:** Re-verify if older than 5 days. Recipe in project CLAUDE.md.

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

### Project CLAUDE.md skeleton

```markdown
# CLAUDE.md — <Project Name>

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
**Memory file:** `~/.claude/projects/C--Users-you/memory/project-<name>.md`
**Workspace context:** `~/.claude/workspaces/<workspace>/CLAUDE.md`

**Save memory IMMEDIATELY on:**
- (milestone 1)
- (milestone 2)
...

**Verify recipe** (run if `Last verified` > 5 days):
```bash
# (3-7 read-only commands specific to this project)
```

Manual triggers: `/memory-save` / `/memory-recall`.
```

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
| Every session start | Auto-load workspace CLAUDE.md (per cwd / topic mention) |
| Every milestone | Update project memory + MEMORY.md one-liner |
| Every 5-7 days | If `Last verified` stale → run project's verify recipe before trusting |
| Every quarter | Run `/consolidate-memory` — merge duplicates, fix stale facts, prune index |
| Multi-session work | Update `SESSION-BOARD.md` on claim/finish; prune stale IN-FLIGHT rows (>3 วัน) — see CLAUDE.md §Inter-session Coordination |
| Before major refactor | Backup `~/.claude/CLAUDE.md` to `~/.claude/backups/CLAUDE-pre-<change>-YYYY-MM-DD.md` |

---

## 🚧 Gap closure priorities (how to use the audit table)

หลัง onboard project ใหม่ ๆ ให้ไล่ปิด gap จากตาราง audit (ช่องที่ ❌) เรียงตาม impact:

1. **Add cwd map + project CLAUDE.md + verify recipe** ให้ project ที่ active แต่ยังขาด
2. **Populate workspace** ที่ยังว่างเมื่อมีข้อมูลจริง
3. **Audit project เก่า** — ยืนยันว่ายัง active หรือควร archive

---

*Template for the public claude-conductor. Replace the AcmeCorp examples with your own.*
