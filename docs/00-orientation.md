# 00 — Orientation: claude-conductor คืออะไร และเริ่มอ่านตรงไหน

> เอกสารตั้งต้นสำหรับคนที่เพิ่งมาใช้ framework นี้ (หรือ AI session ใหม่)
> อ่านไฟล์นี้ก่อน แล้วค่อยไล่ตาม `docs/01` → `docs/05`
>
> ℹ️ นี่คือ **public framework** (sanitized) — workspace/project ที่ยกตัวอย่างทั้งหมด
> เป็นของสมมติ (AcmeCorp). เวลานำไปใช้จริง ให้แทนด้วยธุรกิจของคุณเอง

---

## claude-conductor คืออะไร

`claude-conductor` คือ **portable "operating system" สำหรับการทำงานกับ Claude Code** —
ชุด rules, working protocol, และ file-based memory ที่ทำให้ Claude:

- จำสถานะ project ข้าม session ได้ (file-based memory + verify-before-trust)
- ทำงานเป็นระบบ (orchestrator workflow: คุย → brainstorm → confirm → delegate → review)
- route context ถูก business unit อัตโนมัติ (multi-workspace registry)

เนื้อหาจริงทำงานอยู่ที่ `~/.claude/` (ที่ Claude CLI โหลด) — repo นี้คือ **template +
docs + ตัวอย่าง** ที่คุณ clone แล้ว fill ด้วยข้อมูลธุรกิจของตัวเอง (ดู README §Adopt)

---

## โมเดล 3 ชั้น (3-Layer Model)

ระบบแบ่งเนื้อหาเป็น 3 ชั้น แยกตามว่า portable แค่ไหน + sensitive แค่ไหน:

| Layer | คืออะไร | ตัวอย่างไฟล์ | อยู่ใน repo นี้? |
|---|---|---|---|
| **1. System** | กลไก / กฎการทำงานที่ใช้ได้กับใครก็ได้ ไม่ผูกธุรกิจ | `CLAUDE.md` (rules+routing), `MEMORY_SCHEME.md`, `commands/`, `hooks/`, `settings.json` | ✅ ใช่ (นี่คือหัวใจของ framework) |
| **2. Knowledge** | business context + project memory เฉพาะของคุณ | `workspaces/*/CLAUDE.md`, `memory/*.md` | ⛔ ไม่ (เป็นข้อมูลส่วนตัว) — ดู `examples/` เป็นตัวอย่าง |
| **3. Machine-secret** | credentials + runtime state เฉพาะเครื่อง | `.credentials.json`, `settings.local.json`, `sessions/`, `cache/` ฯลฯ | ❌ ไม่ (gitignored, อยู่แค่ `~/.claude`) |

- **ชั้น 1** = สิ่งที่ public framework นี้ให้ — copy ไปใช้ได้เลย
- **ชั้น 2** = คุณสร้างเองจาก `templates/` + `examples/` (ห้าม commit ขึ้น public repo)
- **ชั้น 3** = ไม่เคยเข้า repo — ดู `.env.example` ว่าเครื่องใหม่ต้องเติมค่าอะไรบ้าง

> framework นี้ถูก fork มาแบบ sanitized จาก private instance ของ maintainer —
> ชั้น 2/3 ทั้งหมดถูกถอดออกแล้ว เหลือแต่ตัวอย่างสมมติใน `examples/`

---

## Workspaces (business units) — ตัวอย่าง

แต่ละ business unit = หนึ่ง workspace แต่ละอันมี `workspaces/<name>/CLAUDE.md` ของตัวเอง
แบรนด์/ธุรกิจย่อย**ไม่ inherit** tone/context กันอัตโนมัติ — แต่ละอันมี voice ของตัวเอง.
ตารางนี้เป็น **ตัวอย่างสมมติ (AcmeCorp)** — โครงสร้างทั่วไปคือ 1 corporate + N brand:

| Workspace | Scope | Trigger keywords |
|---|---|---|
| 🏢 **acme-corp** | Corporate / HQ — โรงงาน, ERP, operations, B2B export/OEM, automation | factory, production, certifications, B2B email, OEM, bulk export |
| 🎨 **acme-snacks** | แบรนด์ขนม retail D2C (under acme-corp) | acme-snacks, snack-web, retail D2C |

`acme-snacks` อยู่ใต้ `acme-corp` แต่ถ้าต้องการ corporate context (เช่น ข้อมูล
production/certs) ต้อง **explicit Read** ตาม link ใน brand CLAUDE.md (ไม่ auto-inherit)

> ดู `examples/workspaces/acme-corp/CLAUDE.md` เป็นตัวอย่าง workspace ที่กรอกครบ

---

## Projects (ตัวอย่าง)

แต่ละ project ผูกกับ memory file หนึ่งไฟล์ และ (ถ้ามี local repo) ผูกกับ cwd segment.
ตารางนี้เป็นตัวอย่างสมมติ:

| Project | Workspace | สถานะย่อ | Memory file |
|---|---|---|---|
| **Acme ERP** | acme-corp | Next.js + self-hosted Supabase, internal ops | `memory/project-acme-erp.md` |
| **Acme Automation** | acme-corp | workflow automation (n8n-style) | `memory/project-acme-automation.md` |
| **Acme Snacks Website** | acme-snacks | brand site (Next.js + headless CMS) | `memory/project-acme-web.md` |

(รายการเต็ม + สถานะล่าสุดอยู่ใน `memory/MEMORY.md` — index ที่ group ตาม workspace.
ดู `examples/memory/` เป็นตัวอย่างที่กรอกครบ)

---

## เริ่มอ่านตรงไหน (reading order)

1. **`docs/00-orientation.md`** ← คุณอยู่ที่นี่ (big picture)
2. **`docs/01-orchestrator-workflow.md`** — วิธีทำงานบังคับ 5 ขั้น (คุย → brainstorm → confirm → delegate → review)
3. **`docs/02-memory-protocol.md`** — ระบบ memory ทำงานยังไง (path, index, mapping, save triggers, size budgets)
4. **`docs/03-inter-session.md`** — coordinate หลาย session พร้อมกันด้วย SESSION-BOARD.md
5. **`docs/04-onboarding-new-project.md`** — เพิ่ม project / workspace ใหม่ยังไง
6. **`docs/05-public-fork-plan.md`** — วิธี sanitize private instance → public fork (meta-doc)

แล้วค่อยลงรายละเอียด: `CLAUDE.md` (rules + routing), `MEMORY_SCHEME.md` (templates +
verify recipes), `templates/` (ไฟล์ตั้งต้น), `examples/` (instance สมมติที่กรอกครบ)

---

## Repo map

```
claude-conductor/
├── README.md                      ← entry point: what / 3-layer model / how to adopt
├── LICENSE                        ← MIT license
├── .gitignore                     ← กัน secret หลุด
├── .env.example                   ← รายการค่า machine-specific ที่เครื่องใหม่ต้องเติม
├── setup.ps1                      ← installer: copy System layer → ~/.claude + แก้ placeholder
├── CLAUDE.md                      ← [System] global rules + workspace registry + cwd mapping (template)
├── MEMORY_SCHEME.md               ← [System] memory system reference + templates + verify recipes
├── settings.json                  ← [System] Claude CLI hooks config (PreCompact/SessionEnd/SessionStart)
├── commands/                      ← [System] slash-command definitions
│   ├── memory-recall.md
│   └── memory-save.md
├── hooks/                         ← [System] memory checkpoint hooks (Node.js)
│   ├── memory-checkpoint.js
│   └── memory-extract.js
├── docs/                          ← documentation (ไฟล์นี้อยู่ที่นี่)
│   ├── 00-orientation.md
│   ├── 01-orchestrator-workflow.md
│   ├── 02-memory-protocol.md
│   ├── 03-inter-session.md
│   ├── 04-onboarding-new-project.md
│   └── 05-public-fork-plan.md
├── templates/                     ← reusable templates (project/workspace CLAUDE.md, memory file, verify recipes)
└── examples/                      ← fictional filled-in instance (AcmeCorp) — copy as a starting point
    ├── workspaces/acme-corp/CLAUDE.md
    └── memory/{MEMORY.md, project-acme-web.md}
```

> หมายเหตุ: ใน private instance จริง จะมีโฟลเดอร์ `workspaces/` + `memory/` (Layer 2)
> เพิ่มเข้ามาด้วย — แต่ใน public framework นี้ถูกถอดออก เหลือเป็นตัวอย่างใน `examples/`
