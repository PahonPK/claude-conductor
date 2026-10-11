# 01 — Orchestrator Workflow (วิธีทำงานบังคับ)

> Source: §Orchestrator workflow ใน `../AGENTS.md`
> ใช้กับ **ทุก code task** — ห้ามข้าม (ยกเว้น task ในตารางด้านล่าง)

---

## หลักการ: main agent = orchestrator ไม่ใช่ implementer

Main agent (session ที่คุยกับ user โดยตรง) ทำหน้าที่เป็น **decision maker +
reviewer** — ไม่ใช่คนลงมือเขียนโค้ดเอง ส่วนการ implement จริงให้ delegate ไปที่
**subagent** แทน (Claude Code: Agent tool · Codex: custom agents `planner` / `worker-heavy` /
`worker-light` / `reviewer` — Codex spawn subagent เฉพาะเมื่อถูกสั่ง ซึ่ง `AGENTS.md` เป็นคนสั่ง)

ทำไมต้องแยกบทบาทแบบนี้:
- **ลด context pollution** — รายละเอียดการ implement ไม่ไปบวม context ของ main agent
- **เพิ่ม quality gate** — มีชั้น review คั่นก่อนส่งงานให้ user
- **กันนิสัย "เห็นแล้วทำเลย"** — บังคับให้ confirm plan กับ user ก่อนลงมือจริง

---

## 5 ขั้นตอนบังคับ

1. **คุยกับ user** — clarify scope, constraints, success criteria ให้ชัดก่อน
   อย่าเดาเอาเองว่า user ต้องการอะไร

2. **Brainstorm** — refine approach: ไล่ทางเลือก, ความเสี่ยง, edge case แล้ว **lock plan**
   ให้ตกผลึกก่อนลงมือ (ทำ inline ใน main agent หรือให้ subagent role planner ช่วยคิด)

3. **Confirm plan กับ user** — เสนอแผนแล้ว **รอคำ go ของ owner** (เช่น "go" / "ไปเลย")
   ก่อนเริ่มทำจริง ห้ามเริ่ม implement โดยที่ user ยังไม่ยืนยัน

4. **Delegate → subagent** — main agent เขียน **brief** ที่ชัดเจน แล้วให้ subagent
   เป็นคน implement (main agent ไม่เขียนโค้ดเอง)

5. **Review ก่อนรายงาน** — reviewer subagent ที่ context ใหม่ (ไม่ใช่ตัวที่เขียนโค้ด)
   review งาน **ก่อน** รายงานผลให้ user — นี่คือ quality gate สุดท้าย
   (Claude: Agent `model: opus` ตัวใหม่ · Codex: agent `reviewer` หรือ built-in `/review`)

> ถ้าเผลอลงมือ code เองไปก่อน (ข้ามขั้นตอน) → ต้อง **admit** กับ user ตรง ๆ
> แล้วขอทำ **retroactive review** ย้อนหลัง

---

## Skip table — task ไหนข้าม workflow ได้

| Task type | ข้ามได้? | หมายเหตุ |
|---|---|---|
| Code change / feature / refactor / migration / workflow patch | ❌ **ห้ามข้าม** | ต้องครบ 5 ขั้น |
| Git ops (commit, push, status, log) | ✅ ทำเลย | งาน mechanical |
| File moves / cleanup / config tweaks เล็ก ๆ | ✅ ทำเลย | จะ delegate ก็ได้ |
| Pure Q&A / recall / planning / brainstorm | ✅ ไม่ต้องใช้ subagent | ไม่มีการแก้ของจริง |
| Emergency / hotfix | ⚠️ **ถาม user ก่อน** | ถามว่าจะข้าม workflow ไหม แล้วค่อยทำ |

หลักการอ่านตาราง: ยิ่งงานแตะ code/state จริงและ irreversible มาก → ยิ่งต้องผ่าน
workflow เต็ม; งานที่ mechanical / read-only / reversible → ข้ามได้

---

## Variant: route งานตาม role (`orchestrated-loop`) + ship loop (`ship`)

ลูป 5 ขั้นเดิม แต่แต่ละ phase รันใน **role** ที่ตายตัว — ดู `../skills/orchestrated-loop/SKILL.md`:

| Phase | Role | Claude Code | Codex |
|---|---|---|---|
| Gather (เก็บ fact / probe ตามสูตร) | light worker — ใช้ heavy เฉพาะต้อง trace code ซับซ้อน | Sonnet | `worker-light` (gpt-6-luna) |
| Analyze / architect / plan / go-no-go | planner — **คิดอย่างเดียว ไม่ลงมือ** | Fable 5 | `planner` (gpt-6-astra) |
| Code tier 1 (มี deterministic gate ครอบ) | light worker | Sonnet | `worker-light` |
| Code tier 2 (DB function / RLS / money logic / cross-file refactor / ไม่แน่ใจ) | heavy worker | Opus 5.5 | `worker-heavy` (gpt-6.1-sol) |
| Final review (คนละตัวกับคนเขียน, judge ≥ answerer) | reviewer | Opus 5.5 (agent ใหม่) | `reviewer` (gpt-6-astra) หรือ `/review` |
| สื่อสาร / git / PR / deploy ตาม runbook | light worker | Sonnet | `worker-light` |

Claude pin model ด้วย `model:` ทุกครั้งที่ spawn; Codex เลือก custom agent ตามชื่อ (override model ราย spawn ไม่ reliable)

`ship` (`../skills/ship/SKILL.md`) = ลูปตอนงาน "coded" → "live & verified": reconcile
requirement จริง → verify schema กับ live DB → build → review → PR → deploy → verify บน live
ด้วย browser → housekeep (ปล่อย lock / fold HANDOFF / update memory)

> ทั้งสองเป็น **optional** — ลูป 5 ขั้นข้างบนคือแกน; skill แค่ทำให้เรียกครบในคำสั่งเดียว
> และกัน step หลุดตอน context ใกล้เต็ม. เรียก skill: Claude `/orchestrated-loop` · Codex `$orchestrated-loop`
