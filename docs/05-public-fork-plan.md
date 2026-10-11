# 05 — Public Fork / Sanitization Approach (meta-doc)

> เอกสารนี้อธิบาย **วิธี** แปลง private instance ของ claude-conductor ให้เป็น public fork
> ที่แชร์ได้ปลอดภัย (sanitized). **repo ที่คุณกำลังอ่านอยู่นี้ = ผลลัพธ์ของกระบวนการนี้**
> — Layer 1 (System) + docs + templates เท่านั้น โดยถอด business data ออกหมดแล้ว

---

## เป้าหมาย

แยก **System layer (กลไก)** ออกจาก **Knowledge layer (business data)** เพื่อให้:
- คนอื่นเอา *framework* ไปใช้กับธุรกิจตัวเองได้ โดยไม่เห็นข้อมูลส่วนตัวของ maintainer
- maintainer ยังเก็บ private instance (พร้อม memory dir + `workspaces/` จริง) ไว้ใช้งานต่อ

> หลักการ: **public fork ไม่มี Layer 2/3 เลย** — มีแค่ Layer 1 + docs + templates +
> `examples/` ที่เป็นข้อมูลสมมติล้วน

---

## (a) เลือกอะไรเข้า / ตัดอะไรออก

**เก็บ (include) — Layer 1 + docs + templates:**
- `AGENTS.md` (genericized, ภาษาอังกฤษ, path เป็น token), `CLAUDE.md` (Claude adapter), `codex/` (Codex adapter),
  `MEMORY_SCHEME.md`, `skills/`, `hooks/`, `settings.json`, `setup.ps1`, `setup-codex.ps1`
  (skill ที่ผูกกับ domain ธุรกิจ → genericize ด้วย placeholder `<LIKE_THIS>` ได้ค่อยเข้า ไม่งั้นตัดทิ้ง)
- `docs/` ทั้งหมด (genericize ตัวอย่างที่อ้างธุรกิจจริง)
- `templates/` ทั้งหมด
- `examples/` (สร้างใหม่ — instance สมมติที่กรอกครบ)

**ตัดทิ้ง (drop) — Layer 2/3:**
- memory dir ทั้งโฟลเดอร์ (business state ล้วน)
- `workspaces/` ทั้งโฟลเดอร์ (business context ล้วน)
- `.env` / credentials / `.git` ของ private repo
- README เดิม (เขียนใหม่สำหรับ public audience)

> **Placeholder 2 แบบ ห้ามปนกัน:** path token ของ setup = ชื่อ AGENT_HOME / MEMORY_DIR / SKILLS_DIR ครอบด้วยวงเล็บปีกกาคู่
> สงวนไว้ให้ setup script แทนตอนติดตั้งเท่านั้น · ค่าที่ user ต้องกรอกเอง ใช้ `<LIKE_THIS>`
> (ตรวจหลังติดตั้งได้ว่าแทนครบ: grep หาวงเล็บปีกกาคู่ในไฟล์ที่ติดตั้งต้องได้ 0) — เอกสารที่ถูกติดตั้ง (`docs/`, `MEMORY_SCHEME.md`)
> ใช้ token ได้เฉพาะตรงที่หมายถึง path จริง ห้ามใช้ตอน *อธิบาย* token

---

## (b) Sanitize replacement table (รูปแบบทั่วไป)

ก่อน publish ต้อง replace ทุก reference ที่ระบุตัวธุรกิจได้ — ตารางนี้เป็น **รูปแบบ**
(กรอก "ของจริง" จาก private instance ฝั่งซ้ายตอนทำจริง อย่า commit ค่าจริงลง public):

| ประเภทข้อมูลจริง | แทนด้วย |
|---|---|
| VPS / server IP (`\d+.\d+.\d+.\d+`) | `<VPS_IP>` |
| domains จริง | `<DOMAIN>` หรือ `app.example.com` |
| brand / company names (ทุกการสะกด ทั้งไทย/อังกฤษ) | `<WORKSPACE>` / `AcmeCorp` / `Acme` |
| person names | generic role เช่น `Owner` |
| OS username / home path / path ใน agent home | path token ของ setup (AGENT_HOME / MEMORY_DIR / SKILLS_DIR) หรือ `C--Users-you` ในคำอธิบาย |
| commit hashes / email / API tokens / keys | ลบ หรือ `<placeholder>` |

> ⚠️ regex อย่างเดียวไม่พอ — ชื่อแบรนด์สะกดได้หลายแบบ (ไทย/อังกฤษ/ตัวพิมพ์เล็กใหญ่)
> ต้อง **manual review ทุกไฟล์** ที่ copy + เขียนส่วนที่อ้าง business จริงใหม่ให้ generic

---

## (c) โฟลเดอร์ `examples/`

แทนที่ workspace/memory จริงด้วย **instance สมมติที่กรอกครบ** เพื่อให้คนอ่านเห็นว่า
เวลาใช้จริงหน้าตาเป็นยังไง — ใช้ค่า fictional ล้วน (AcmeCorp, example.com, `<...>`):
- `examples/workspaces/acme-corp/AGENTS.md` — workspace ตัวอย่าง
- `examples/memory/MEMORY.md` — index ตัวอย่าง
- `examples/memory/project-acme-web.md` — memory file ตัวอย่างที่กรอกครบ
- `examples/memory/feedback-*.md` — feedback lesson ตัวอย่าง

---

## (d) Final allowlist scan (gate ก่อน publish)

ก่อน push สาธารณะ ต้อง grep ทั้ง repo (case-insensitive) หา **ค่าจริงทุกตัว** จาก
ตาราง (b): brand/company names, domains, IP จริง (regex `\d+.\d+.\d+.\d+` ที่ไม่ใช่
placeholder), email/token/commit-hash, OS username / home-path segment. **ต้องได้ 0 hit**
— เจอแม้แต่ตัวเดียว = หยุด แล้วแก้ก่อน. แนะนำทำเป็น CI check / pre-push hook

---

## (e) Sync mapping: private instance (live) → public repo

private instance ของ maintainer รันบน Claude Code และ**ยังใช้โครงเดิม**; public repo ถูกจัดใหม่ให้ใช้ได้ทั้ง
Claude Code และ Codex. ตอน sync บทเรียน/กฎใหม่จาก live เข้ามา ให้ map ตามนี้:

| ใน private instance (live) | ใน public repo | หมายเหตุ |
|---|---|---|
| `~/.claude/CLAUDE.md` — ส่วน rules ที่ไม่ผูก agent (Role, Quality, Orchestrator, Registry, Memory, Inter-session, Per-project, Onboarding) | `AGENTS.md` | แปลเป็นภาษาอังกฤษ, path → token, ตัวอย่าง → AcmeCorp |
| `~/.claude/CLAUDE.md` — ส่วนที่ผูก Claude (auto-memory slug, hooks, EnterWorktree, Agent `model:`, `/name`) | `CLAUDE.md` §Claude Code specifics | ส่วนนี้เท่านั้นที่พูดถึงกลไก Claude |
| skill `fable-5` (route ตามชื่อ model) | `skills/orchestrated-loop/` | เขียนเป็น **role** (planner / heavy worker / light worker / reviewer) + ตาราง map role → Claude model / Codex agent |
| `commands/memory-save.md`, `commands/memory-recall.md` (slash command) | `skills/memory-save/`, `skills/memory-recall/` | Codex ถอด custom prompts แล้ว → skill ใช้ได้ทั้งสองฝั่ง; ขั้น daily log = "ถ้ามี (Claude hook เท่านั้น)" |
| plugin skill `/consolidate-memory`, `/product-brainstorming`, `/code-review` (ไม่อยู่ใน repo) | `skills/memory-consolidate/` · brainstorm = ขั้น inline ในลูป · review = role reviewer (Codex: + `/review`) | public repo ห้ามพึ่ง plugin ที่ไม่ได้แจก |
| `~/.claude/workspaces/<name>/CLAUDE.md` | `<agent home>/workspaces/<name>/AGENTS.md` (`templates/workspace-AGENTS.md.template`) | agent อ่านเองตาม registry ทั้งสองฝั่ง |
| `<project>/CLAUDE.md` | `<project>/AGENTS.md` + `CLAUDE.md` 1 บรรทัด `@AGENTS.md` (`templates/project-AGENTS.md.template`) | |
| memory path ใน hooks (hardcode segment) | path ที่ setup เขียนให้ตอนติดตั้ง (ค่าเดียวกับใน `AGENTS.md`/skills) + flag `--agent claude\|codex` | agent home = dir แม่ของ `hooks/` |
| คำสั่ง operative ภาษาไทยใน rules/skills | ภาษาอังกฤษ | docs (คนอ่าน) คงภาษาไทยได้ |

---

## สรุป checklist

- [x] สร้าง repo แยกสำหรับ public fork
- [x] copy เฉพาะ System + docs + templates
- [x] genericize ทุกไฟล์ (ตาราง b) + manual review
- [x] สร้าง `examples/` (fictional AcmeCorp)
- [x] เขียน README ใหม่สำหรับ public audience
- [x] แยก agent-neutral core (`AGENTS.md` + skills) ออกจาก adapter (Claude: `CLAUDE.md` + `settings.json` · Codex: `codex/`) — ตาราง (e)
- [x] รัน final allowlist scan (d) — 0 hit
