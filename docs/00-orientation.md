# 00 — Orientation: claude-conductor คืออะไร และเริ่มอ่านตรงไหน

> เอกสารตั้งต้นสำหรับคนที่เพิ่งมาใช้ framework นี้ (หรือ AI session ใหม่)
> อ่านไฟล์นี้ก่อน แล้วค่อยไล่ตาม `docs/01` → `docs/07` · *Last updated: 2026-10-09*
>
> ℹ️ นี่คือ **public framework** (sanitized) — workspace/project ที่ยกตัวอย่างทั้งหมด
> เป็นของสมมติ (AcmeCorp). เวลานำไปใช้จริง ให้แทนด้วยธุรกิจของคุณเอง

---

## claude-conductor คืออะไร

`claude-conductor` คือ **portable "operating system" สำหรับการทำงานกับ AI coding agent** —
ใช้ได้ทั้ง **Claude Code** และ **OpenAI Codex** — ชุด rules, working protocol, และ file-based memory
ที่ทำให้ agent:

- จำสถานะ project ข้าม session ได้ (file-based memory + verify-before-trust)
- ทำงานเป็นระบบ (orchestrator workflow: คุย → brainstorm → confirm → delegate → review)
- route context ถูก business unit อัตโนมัติ (multi-workspace registry)

แกนกลางคือ **`AGENTS.md`** (กฎที่ไม่ผูกกับ agent ตัวไหน, ภาษาอังกฤษ) + **skills** ชุดเดียวกัน.
ส่วนที่ผูกกับ agent แยกออกมาเป็น adapter: Claude Code = `CLAUDE.md` (import `AGENTS.md`) +
`settings.json`; Codex = `codex/` (custom agents + `hooks.json`). เนื้อหาจริงทำงานอยู่ที่ home dir
ของ agent (Claude: `~/.claude/` · Codex: `~/.codex/` + `~/.agents/skills/`) — repo นี้คือ
**template + docs + ตัวอย่าง** ที่คุณ clone แล้ว fill ด้วยข้อมูลธุรกิจของตัวเอง (ดู README §Adopt)

---

## โมเดล 3 ชั้น (3-Layer Model)

ระบบแบ่งเนื้อหาเป็น 3 ชั้น แยกตามว่า portable แค่ไหน + sensitive แค่ไหน:

| Layer | คืออะไร | ตัวอย่างไฟล์ | อยู่ใน repo นี้? |
|---|---|---|---|
| **1. System** | กลไก / กฎการทำงานที่ใช้ได้กับใครก็ได้ ไม่ผูกธุรกิจ | `AGENTS.md` (rules+routing), `CLAUDE.md` + `settings.json` (Claude adapter), `codex/` (Codex adapter), `MEMORY_SCHEME.md`, `skills/`, `hooks/` | ✅ ใช่ (นี่คือหัวใจของ framework) |
| **2. Knowledge** | business context + project memory เฉพาะของคุณ | `workspaces/*/AGENTS.md`, memory dir (`MEMORY.md`, `project-*.md`, `feedback-*.md`) | ⛔ ไม่ (เป็นข้อมูลส่วนตัว) — ดู `examples/` เป็นตัวอย่าง |
| **3. Machine-secret** | credentials + runtime state เฉพาะเครื่อง | credential/auth file ของ agent, `settings.local.json`, sessions, cache ฯลฯ | ❌ ไม่ (gitignored, อยู่แค่ใน home dir ของ agent) |

- **ชั้น 1** = สิ่งที่ public framework นี้ให้ — ติดตั้งด้วย `setup.ps1` (Claude) / `setup-codex.ps1` (Codex)
- **ชั้น 2** = คุณสร้างเองจาก `templates/` + `examples/` (ห้าม commit ขึ้น public repo)
- **ชั้น 3** = ไม่เคยเข้า repo — ดู `.env.example` ว่าเครื่องใหม่ต้องเติมค่าอะไรบ้าง

> framework นี้ถูก fork มาแบบ sanitized จาก private instance ของ maintainer —
> ชั้น 2/3 ทั้งหมดถูกถอดออกแล้ว เหลือแต่ตัวอย่างสมมติใน `examples/`

---

## Workspaces (business units) — ตัวอย่าง

แต่ละ business unit = หนึ่ง workspace แต่ละอันมี `workspaces/<name>/AGENTS.md` ของตัวเอง
(ใต้ home dir ของ agent). แบรนด์/ธุรกิจย่อย**ไม่ inherit** tone/context กันอัตโนมัติ — แต่ละอันมี voice ของตัวเอง.
ตารางนี้เป็น **ตัวอย่างสมมติ (AcmeCorp)** — โครงสร้างทั่วไปคือ 1 corporate + N brand:

| Workspace | Scope | Trigger keywords |
|---|---|---|
| 🏢 **acme-corp** | Corporate / HQ — โรงงาน, ERP, operations, B2B export/OEM, automation | factory, production, certifications, B2B email, OEM, bulk export |
| 🎨 **acme-snacks** | แบรนด์ขนม retail D2C (under acme-corp) | acme-snacks, snack-web, retail D2C |

`acme-snacks` อยู่ใต้ `acme-corp` แต่ถ้าต้องการ corporate context (เช่น ข้อมูล
production/certs) ต้อง **explicit Read** ตาม link ใน workspace file ของแบรนด์ (ไม่ auto-inherit)

> ดู `examples/workspaces/acme-corp/AGENTS.md` เป็นตัวอย่าง workspace ที่กรอกครบ

---

## Projects (ตัวอย่าง)

แต่ละ project ผูกกับ memory file หนึ่งไฟล์ และ (ถ้ามี local repo) ผูกกับ cwd segment.
ตารางนี้เป็นตัวอย่างสมมติ:

| Project | Workspace | สถานะย่อ | Memory file |
|---|---|---|---|
| **Acme ERP** | acme-corp | Next.js + self-hosted Supabase, internal ops | `project-acme-erp.md` |
| **Acme Automation** | acme-corp | workflow automation (n8n-style) | `project-acme-automation.md` |
| **Acme Snacks Website** | acme-snacks | brand site (Next.js + headless CMS) | `project-acme-web.md` |

(รายการเต็ม + สถานะล่าสุดอยู่ใน `MEMORY.md` ของ memory dir — index ที่ group ตาม workspace.
ดู `examples/memory/` เป็นตัวอย่างที่กรอกครบ)

---

## เริ่มอ่านตรงไหน (reading order)

1. **`docs/00-orientation.md`** ← คุณอยู่ที่นี่ (big picture)
2. **`docs/01-orchestrator-workflow.md`** — วิธีทำงานบังคับ 5 ขั้น (คุย → brainstorm → confirm → delegate → review) + skill `orchestrated-loop` / `ship`
3. **`docs/02-memory-protocol.md`** — ระบบ memory ทำงานยังไง (path, index, mapping, save triggers, size budgets)
4. **`docs/03-inter-session.md`** — coordinate หลาย session พร้อมกันด้วย SESSION-BOARD.md (+ DEPLOY LOCK, HANDOFF QUEUE, merge hygiene)
5. **`docs/04-onboarding-new-project.md`** — เพิ่ม project / workspace ใหม่ยังไง
6. **`docs/05-public-fork-plan.md`** — วิธี sanitize private instance → public fork (meta-doc)
7. **`docs/06-lessons-learned.md`** — ปัญหาที่เจอจริง → กฎที่ได้ (verification, git/publishing, memory/files, platform gotchas, working style)
8. **`docs/07-codex.md`** — ใช้กับ OpenAI Codex: mapping Claude ↔ Codex, ติดตั้ง, smoke test

แล้วค่อยลงรายละเอียด: `AGENTS.md` (rules + routing), `MEMORY_SCHEME.md` (templates +
verify recipes), `templates/` (ไฟล์ตั้งต้น), `examples/` (instance สมมติที่กรอกครบ)

---

## Repo map

```
claude-conductor/
├── README.md                      ← entry point: what / 3-layer model / how to adopt
├── LICENSE                        ← MIT license
├── .gitignore                     ← กัน secret หลุด
├── .env.example                   ← รายการค่า machine-specific ที่เครื่องใหม่ต้องเติม
├── setup.ps1                      ← installer (Claude Code): System layer → ~/.claude + แทน path token
├── setup-codex.ps1                ← installer (Codex): System layer → ~/.codex + ~/.agents/skills + แทน path token
├── AGENTS.md                      ← [System] กฎกลางที่ไม่ผูก agent + workspace registry + cwd mapping (template)
├── CLAUDE.md                      ← [System] Claude Code adapter: `@AGENTS.md` + เรื่องเฉพาะ Claude
├── MEMORY_SCHEME.md               ← [System] memory system reference + templates + verify recipes
├── settings.json                  ← [System] Claude Code hooks config (PreCompact/SessionEnd/SessionStart/PostToolUse)
├── codex/                         ← [System] Codex adapter
│   ├── hooks.json                 ← SessionStart (checkpoint + guard) + PostToolUse (guard)
│   └── agents/                    ← custom agents: planner, reviewer, worker-heavy, worker-light
├── hooks/                         ← [System] memory hooks (Node.js)
│   ├── memory-checkpoint.js       ← audit log + inject memory ตอน SessionStart (`--agent claude|codex`)
│   ├── memory-extract.js          ← (Claude เท่านั้น) worker เขียน daily log ตอน PreCompact/SessionEnd
│   └── memory-guard.js            ← shadow copy + restore memory file ที่โดน truncate เหลือ 0 byte
├── skills/                        ← [System] skills ใช้ร่วมกันทั้งสอง agent (ภาษาอังกฤษ)
│   ├── memory-save/SKILL.md       ← บันทึก state ลง project memory
│   ├── memory-recall/SKILL.md     ← อ่าน memory + verify กับ code จริง (pure read)
│   ├── memory-consolidate/SKILL.md ← hygiene รายไตรมาส
│   ├── orchestrated-loop/SKILL.md ← ลูปเดิม + route งานตาม role (planner / heavy / light / reviewer)
│   └── ship/SKILL.md              ← reconcile → build → review → PR → deploy → verify live → housekeep
├── docs/                          ← documentation (ไฟล์นี้อยู่ที่นี่) 00 → 07
├── templates/                     ← project/workspace AGENTS.md, memory file, MEMORY.md + SESSION-BOARD.md seed, verify recipes
└── examples/                      ← fictional filled-in instance (AcmeCorp) — copy as a starting point
    ├── workspaces/acme-corp/AGENTS.md
    └── memory/{MEMORY.md, project-acme-web.md, feedback-testing-standard.md, feedback-design-lessons.md}
```

> หมายเหตุ: ใน private instance จริง จะมีโฟลเดอร์ `workspaces/` + memory dir (Layer 2)
> เพิ่มเข้ามาด้วย — แต่ใน public framework นี้ถูกถอดออก เหลือเป็นตัวอย่างใน `examples/`
